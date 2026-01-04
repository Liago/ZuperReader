import { NextRequest, NextResponse } from 'next/server';
import { refreshAllFeedsInternal } from '@/app/actions/rss';
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

		const result = await refreshAllFeedsInternal(supabase);

		if (!result.success) {
			if (result.errors && result.errors.includes('Unauthorized')) {
				return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
			}
			return NextResponse.json(result, { status: 500 }); // Or 400 depending on error, but 500 safe for server error
		}

		return NextResponse.json(result);
	} catch (error) {
		return NextResponse.json({ error: (error as Error).message }, { status: 500 });
	}
}
