import { NextRequest, NextResponse } from 'next/server';
import { addFeedInternal, deleteFeedInternal, getFeedContentInternal } from '@/app/actions/rss';
import { createClient } from '@supabase/supabase-js';

export async function POST(request: NextRequest) {
	try {
		const authHeader = request.headers.get('Authorization');
		if (!authHeader) {
			return NextResponse.json({ error: 'Missing Authorization header' }, { status: 401 });
		}

		const supabase = createClient(
			process.env.NEXT_PUBLIC_SUPABASE_URL!,
			process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
			{
				global: {
					headers: {
						Authorization: authHeader,
					},
				},
			}
		);

		const body = await request.json();
		const { action, url, feedId } = body;

		if (action === 'add') {
			if (!url) {
				return NextResponse.json({ error: 'URL is required' }, { status: 400 });
			}
			const result = await addFeedInternal(supabase, url);
			if (result.error) {
				if (result.error === 'Unauthorized') return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
				return NextResponse.json(result, { status: 400 });
			}
			return NextResponse.json(result);

		} else if (action === 'delete') {
			if (!feedId) {
				return NextResponse.json({ error: 'Feed ID is required' }, { status: 400 });
			}
			const result = await deleteFeedInternal(supabase, feedId);
			if (result.error) {
				if (result.error === 'Unauthorized') return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
				return NextResponse.json(result, { status: 400 });
			}
			return NextResponse.json(result);

		} else if (action === 'refresh') {
			if (!url) {
				return NextResponse.json({ error: 'URL is required' }, { status: 400 });
			}
			// Use getFeedContentInternal to refresh and sync
			const result = await getFeedContentInternal(supabase, url, feedId);
			if (result.error) {
				return NextResponse.json({ error: result.error }, { status: 500 });
			}
			// Return simplified result expected by client
			return NextResponse.json({
				success: true,
				added: result.syncStats?.added || 0,
				existing: result.syncStats?.existing || 0
			});

		} else {
			return NextResponse.json({ error: 'Invalid action. Use "add", "delete", or "refresh"' }, { status: 400 });
		}

	} catch (error) {
		return NextResponse.json({ error: (error as Error).message }, { status: 500 });
	}
}
