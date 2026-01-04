import { NextRequest, NextResponse } from 'next/server';
import { discoverFeeds } from '@/app/actions/rss';

export async function GET(request: NextRequest) {
	const searchParams = request.nextUrl.searchParams;
	const query = searchParams.get('query');

	if (!query) {
		return NextResponse.json({ error: 'Query parameter is required' }, { status: 400 });
	}

	try {
		const result = await discoverFeeds(query);

		if (result.error) {
			// If unauthorized, return 401?? The server action returns "error" string usually.
			// But discoverFeeds actually doesn't check auth, it just searches public web.
			// So error is likely a search failure.
			return NextResponse.json(result, { status: 400 });
		}

		return NextResponse.json(result);
	} catch (error) {
		return NextResponse.json({ error: (error as Error).message }, { status: 500 });
	}
}
