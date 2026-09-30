import { cache } from 'react';
import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { createClient } from '@supabase/supabase-js';
import { ExternalLink } from 'lucide-react';
import type { PublicArticle } from '@/lib/supabase';
import { sanitizeArticleHtml } from '@/lib/sanitizeArticleHtml';
import PublicFontSizeControl, { DEFAULT_PUBLIC_FONT_SIZE } from '@/components/PublicFontSizeControl';

// Revoking a link must take effect immediately: never cache this page.
export const dynamic = 'force-dynamic';

const TOKEN_PATTERN = /^[a-f0-9]{32,128}$/;

type PageProps = {
	params: Promise<{ token: string }>;
};

// Anonymous client: no cookies, no session. It can only call the
// get_public_article RPC (anon has no table grants on public.*).
const getPublicArticle = cache(async (token: string): Promise<PublicArticle | null> => {
	if (!TOKEN_PATTERN.test(token)) return null;

	const supabase = createClient(
		process.env.NEXT_PUBLIC_SUPABASE_URL!,
		process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
		{ auth: { persistSession: false, autoRefreshToken: false } }
	);

	const { data, error } = await supabase.rpc('get_public_article', { p_token: token });

	if (error) {
		console.error('Error loading public article:', error.message);
		return null;
	}

	const rows = (data ?? []) as PublicArticle[];
	return rows[0] ?? null;
});

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
	const { token } = await params;
	const article = await getPublicArticle(token);

	if (!article) {
		return { title: 'Article not available · SuperReader', robots: { index: false, follow: false } };
	}

	const description = article.excerpt ?? undefined;

	return {
		title: `${article.title} · SuperReader`,
		description,
		// Shared by link, not meant to be indexed by search engines
		robots: { index: false, follow: false },
		referrer: 'no-referrer',
		openGraph: {
			type: 'article',
			title: article.title,
			description,
			siteName: 'SuperReader',
			images: article.image_url ? [{ url: article.image_url }] : undefined,
		},
		twitter: {
			card: article.image_url ? 'summary_large_image' : 'summary',
			title: article.title,
			description,
			images: article.image_url ? [article.image_url] : undefined,
		},
	};
}

export default async function PublicArticlePage({ params }: PageProps) {
	const { token } = await params;
	const article = await getPublicArticle(token);

	if (!article) notFound();

	const content = article.content ? sanitizeArticleHtml(article.content, article.url) : '';

	// Kicker: domain · date · read time
	const kickerParts: string[] = [];
	if (article.domain) kickerParts.push(article.domain);
	if (article.published_date) {
		kickerParts.push(new Date(article.published_date).toLocaleDateString('en-US', { day: 'numeric', month: 'long', year: 'numeric' }));
	}
	if (article.estimated_read_time) kickerParts.push(`${article.estimated_read_time} min read`);

	const byline = article.author || article.domain;

	const proseStyle: React.CSSProperties & Record<string, string> = {
		// Set by PublicFontSizeControl (A− / A+); children of .prose scale in em
		fontSize: `var(--public-font-size, ${DEFAULT_PUBLIC_FONT_SIZE}px)`,
		fontFamily: 'var(--font-body)',
		'--tw-prose-body': 'var(--app-ink)',
		'--tw-prose-headings': 'var(--app-ink)',
		'--tw-prose-links': 'var(--app-accent)',
		'--tw-prose-bold': 'var(--app-ink)',
		'--tw-prose-quotes': 'var(--app-muted)',
		'--tw-prose-quote-borders': 'var(--app-sage)',
		'--tw-prose-bullets': 'var(--app-muted)',
		'--tw-prose-counters': 'var(--app-muted)',
		'--tw-prose-code': 'var(--app-ink)',
		'--tw-prose-hr': 'var(--app-line)',
		'--tw-prose-captions': 'var(--app-muted)',
	};

	return (
		<div className="min-h-screen bg-app-page">
			{/* Top bar */}
			<header className="sticky top-0 z-30 border-b border-app-line bg-app-page">
				<div className="mx-auto flex max-w-[760px] items-center justify-between gap-3 px-5 py-3">
					<Link href="/" className="font-heading text-[20px] text-ink">
						SuperReader
					</Link>
					<div className="flex items-center gap-2">
						<PublicFontSizeControl />
						<a
							href={article.url}
							target="_blank"
							rel="noopener noreferrer nofollow"
							title="Read the original"
							className="flex h-[34px] items-center gap-1.5 rounded-full border border-app-line px-3 text-[12.5px] font-bold text-ink transition-colors hover:bg-app-hover"
						>
							<ExternalLink size={14} strokeWidth={2.75} />
							<span className="hidden sm:inline">Original</span>
						</a>
					</div>
				</div>
			</header>

			<main className="mx-auto max-w-[760px] px-5 py-11">
				<article>
					{kickerParts.length > 0 && (
						<div className="text-[11px] font-bold uppercase tracking-[0.12em] text-app-muted">
							{kickerParts.join(' · ')}
						</div>
					)}

					<h1 className="text-pretty mt-3 font-heading text-[34px] leading-[1.08] tracking-[-0.02em] text-ink sm:text-[44px] sm:leading-[1.06]">
						{article.title}
					</h1>

					<div className="mt-5 flex flex-wrap items-center justify-between gap-3 border-b border-app-line pb-6">
						{byline && (
							<div className="flex items-center gap-2.5">
								<span className="flex h-[34px] w-[34px] flex-none items-center justify-center rounded-full bg-sage text-[13px] font-semibold text-app-page">
									{byline.charAt(0).toUpperCase()}
								</span>
								<span className="text-[14px] font-semibold text-ink">{byline}</span>
							</div>
						)}
						{article.shared_by_name && (
							<span className="text-[13px] text-app-muted">
								Shared by <span className="font-semibold text-ink">{article.shared_by_name}</span>
							</span>
						)}
					</div>

					{content ? (
						<div
							className="public-article html-chunk prose leading-relaxed mt-8 max-w-none break-words prose-headings:font-heading prose-a:no-underline hover:prose-a:underline prose-img:rounded-2xl prose-blockquote:border-l-[3px] prose-blockquote:not-italic prose-blockquote:pl-5 prose-blockquote:font-normal [&_iframe]:aspect-video [&_iframe]:h-auto [&_iframe]:w-full [&_iframe]:rounded-2xl [&_img]:h-auto [&_img]:max-w-full"
							style={proseStyle}
							dangerouslySetInnerHTML={{ __html: content }}
						/>
					) : (
						<p className="mt-8 text-[15px] text-app-muted">
							{article.excerpt || 'The content of this article is not available.'}
						</p>
					)}
				</article>

				{/* Footer CTA */}
				<footer className="mt-14 rounded-[22px] border border-app-line bg-app-card p-6 text-center">
					<p className="font-heading text-[22px] text-ink">Read without distractions</p>
					<p className="mt-1.5 text-[13.5px] text-app-muted">
						This article was shared with you via SuperReader, the clean reader for the web.
					</p>
					{article.expires_at && (
						<p className="mt-1 text-[12.5px] text-app-muted">
							This link is available until{' '}
							{new Date(article.expires_at).toLocaleString('en-US', {
								month: 'long',
								day: 'numeric',
								hour: 'numeric',
								minute: '2-digit',
								timeZone: 'Europe/Rome',
								timeZoneName: 'short',
							})}
							.
						</p>
					)}
					<div className="mt-4 flex flex-wrap justify-center gap-2.5">
						<Link
							href="/login"
							className="rounded-full bg-accent px-5 py-2.5 font-heading text-[15px] text-app-page transition-colors hover:bg-accent-600"
						>
							Try SuperReader
						</Link>
						<a
							href={article.url}
							target="_blank"
							rel="noopener noreferrer nofollow"
							className="rounded-full border border-app-line px-5 py-2.5 text-[14px] font-semibold text-ink transition-colors hover:bg-app-hover"
						>
							Read the original
						</a>
					</div>
					<p className="mt-6 border-t border-app-line pt-4 text-[12px] text-app-muted">
						© {new Date().getFullYear()} ZuperReader — made with{' '}
						<span role="img" aria-label="love" className="text-accent">
							♥
						</span>{' '}
						by Liago
					</p>
				</footer>
			</main>
		</div>
	);
}
