import Link from 'next/link';

export default function PublicArticleNotFound() {
	return (
		<div className="flex min-h-screen flex-col items-center justify-center gap-4 bg-app-page px-4 text-center">
			<h1 className="font-heading text-[34px] text-ink">Link not available</h1>
			<p className="max-w-[420px] text-[14px] text-app-muted">
				This article is no longer public, or the link is incorrect. Ask the person who shared it for a new link.
			</p>
			<Link
				href="/"
				className="rounded-full bg-accent px-5 py-2.5 font-heading text-[15px] text-app-page transition-colors hover:bg-accent-600"
			>
				Go to SuperReader
			</Link>
		</div>
	);
}
