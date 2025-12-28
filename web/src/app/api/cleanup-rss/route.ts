import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { runFullCleanup } from '@/lib/rssCleanup';

/**
 * RSS Cleanup Cron Job Endpoint
 *
 * This endpoint is called by Vercel Cron to clean up old RSS articles daily.
 * Protected by a secret token to prevent unauthorized access.
 *
 * Schedule: Daily at 2:00 AM UTC (configured in vercel.json)
 */
export async function GET(request: NextRequest) {
    try {
        // Verify cron secret for security
        const authHeader = request.headers.get('authorization');
        const cronSecret = process.env.CRON_SECRET;

        if (!cronSecret) {
            console.error('CRON_SECRET not configured');
            return NextResponse.json(
                { error: 'Cron job not configured' },
                { status: 500 }
            );
        }

        if (authHeader !== `Bearer ${cronSecret}`) {
            console.error('Unauthorized cron job attempt');
            return NextResponse.json(
                { error: 'Unauthorized' },
                { status: 401 }
            );
        }

        const supabase = await createClient();

        // Get all users (or you can filter to active users only)
        const { data: profiles, error: profilesError } = await supabase
            .from('user_profiles')
            .select('id');

        if (profilesError) {
            console.error('Error fetching user profiles:', profilesError);
            return NextResponse.json(
                { error: 'Failed to fetch users' },
                { status: 500 }
            );
        }

        if (!profiles || profiles.length === 0) {
            return NextResponse.json({
                success: true,
                message: 'No users to process',
                processedUsers: 0,
                results: []
            });
        }

        // Run cleanup for each user
        const results = [];
        let totalDeleted = 0;
        let totalErrors = 0;

        for (const profile of profiles) {
            try {
                const result = await runFullCleanup(profile.id);
                results.push({
                    userId: profile.id,
                    deleted: result.totalDeleted,
                    details: result.details,
                    errors: result.errors
                });
                totalDeleted += result.totalDeleted;
                if (result.errors.length > 0) totalErrors++;
            } catch (err) {
                console.error(`Error cleaning up user ${profile.id}:`, err);
                results.push({
                    userId: profile.id,
                    error: (err as Error).message
                });
                totalErrors++;
            }
        }

        // Log summary
        console.log(`RSS Cleanup completed: ${profiles.length} users processed, ${totalDeleted} articles deleted, ${totalErrors} errors`);

        return NextResponse.json({
            success: true,
            timestamp: new Date().toISOString(),
            processedUsers: profiles.length,
            totalDeleted,
            totalErrors,
            results
        });

    } catch (err) {
        console.error('Fatal error in cleanup cron:', err);
        return NextResponse.json(
            {
                error: 'Internal server error',
                message: (err as Error).message
            },
            { status: 500 }
        );
    }
}
