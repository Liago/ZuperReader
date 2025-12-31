# AI Summary Feature - Setup Guide

This guide will help you set up the AI-powered article summarization feature using Cohere API.

## Overview

The AI Summary feature automatically generates intelligent summaries of your saved articles using Cohere's summarization API. Users can:
- Generate summaries for articles with a single click
- Choose between short, medium, and long summaries
- Regenerate summaries at any time
- View summaries in a beautiful UI box on the article page

## Setup Steps

### 1. Database Migration

Run the SQL migration in your Supabase SQL Editor:

```bash
# Open the file: add_ai_summary_migration.sql
# Copy and paste the contents into your Supabase SQL Editor
# Execute the query
```

This will add two new columns to the `articles` table:
- `ai_summary` (TEXT) - Stores the generated summary
- `ai_summary_generated_at` (TIMESTAMP) - Tracks when the summary was created

### 2. Environment Variables

Add the following environment variables to your project:

#### For Local Development (parser-api/.env)
```bash
COHERE_API_KEY=O2pO7lIlFe6nfZqyX4WhxTFE3Zgr79TCHtlVA6Vq
```

#### For Netlify Deployment
Go to your Netlify dashboard:
1. Navigate to **Site configuration > Environment variables**
2. Add the following variable:
   - Key: `COHERE_API_KEY`
   - Value: `O2pO7lIlFe6nfZqyX4WhxTFE3Zgr79TCHtlVA6Vq`

#### For Web App

**IMPORTANT**: If your web app is deployed on Vercel (or any platform other than Netlify), you MUST configure the full Netlify function URL:

```bash
# In Vercel dashboard > Project Settings > Environment Variables
NEXT_PUBLIC_PARSE_FUNCTION_URL=https://your-site.netlify.app/.netlify/functions/parse
```

The summary function URL will be automatically derived from `NEXT_PUBLIC_PARSE_FUNCTION_URL`. However, if you want to customize it:

```bash
NEXT_PUBLIC_SUMMARY_FUNCTION_URL=https://your-site.netlify.app/.netlify/functions/generate-summary
```

**Note**: For local development with `netlify dev`, you can use relative URLs like `/.netlify/functions/parse`.

### 3. Deploy Netlify Functions

The new function is located at:
```
parser-api/netlify/functions/generate-summary.js
```

Deploy to Netlify:
```bash
cd parser-api
netlify deploy --prod
```

Or if you have automatic deployments enabled, just push to your main branch:
```bash
git add .
git commit -m "feat: add AI summary functionality with Cohere"
git push origin main
```

### 4. Test the Feature

1. Open any article in your app
2. Look for the "AI Summary Box" below the article metadata
3. Click the "Genera" (Generate) button
4. Wait for the summary to be generated (usually takes 2-5 seconds)
5. The summary will appear in the box and be saved to the database

## How It Works

### Architecture

```
User clicks "Generate"
    ↓
Frontend calls: /.netlify/functions/generate-summary
    ↓
Netlify Function strips HTML from article content
    ↓
Calls Cohere API with plain text
    ↓
Cohere returns summary
    ↓
Frontend saves summary to Supabase
    ↓
Summary displayed in AISummaryBox component
```

### Files Modified/Created

**New Files:**
- `parser-api/netlify/functions/generate-summary.js` - Netlify function for AI summarization
- `web/src/components/AISummaryBox.tsx` - React component for displaying summaries
- `add_ai_summary_migration.sql` - Database migration
- `AI_SUMMARY_SETUP.md` - This setup guide

**Modified Files:**
- `web/src/lib/supabase.ts` - Added `ai_summary` and `ai_summary_generated_at` to Article type
- `web/src/lib/api.ts` - Added AI summary functions
- `web/src/app/articles/[id]/page.tsx` - Integrated AISummaryBox component

## Features

### Summary Lengths

Users can choose from three summary lengths:
- **Short** - Brief, concise summary (2-3 sentences)
- **Medium** - Balanced summary (default, ~1 paragraph)
- **Long** - Detailed summary (multiple paragraphs)

### UI Features

- Beautiful gradient design matching your app's aesthetic
- Loading states with animations
- Error handling with user-friendly messages
- "Powered by Cohere AI" badge
- Timestamp showing when summary was generated
- One-click regeneration

### Performance Optimizations

- HTML stripping to reduce token usage
- Text truncation for very long articles (max 50k characters)
- Caching summaries in database to avoid regenerating
- Responsive design for mobile and desktop

## API Limits

### Cohere Free Tier
- 1000 API calls per month (free trial)
- Rate limit: 20 requests per minute

For production use, consider upgrading to a paid Cohere plan.

## Troubleshooting

### Summary generation fails with "Load failed" error
**Most common cause**: The frontend can't reach the Netlify function

**Solution**:
1. Check that `NEXT_PUBLIC_PARSE_FUNCTION_URL` is set with the **full URL** in your Vercel environment variables
   - Example: `https://your-site.netlify.app/.netlify/functions/parse`
   - NOT: `/.netlify/functions/parse` (this only works for local development)
2. Redeploy your Vercel app after setting the environment variable
3. Check browser console (F12) for network errors to see the actual URL being called

### Summary generation fails with API errors
- Check that COHERE_API_KEY is set correctly in Netlify
- Verify the API key is valid at https://dashboard.cohere.ai
- Check Netlify function logs for errors

### "Content is too short to summarize" error
- Articles need at least 100 characters of plain text
- Check if article.content exists in the database

### Summary looks incorrect
- Try regenerating with a different length
- Very technical or specialized content may not summarize well
- Consider the article's language (Cohere works best with English)

## Future Enhancements

Potential improvements for v2:
- Automatic summary generation when saving articles
- Multiple language support
- Custom summary prompts
- Summary quality rating
- Batch summarization for multiple articles

## Cost Estimation

At $0.40 per 1M input tokens (Cohere pricing):
- Average article: ~5,000 tokens
- Cost per summary: ~$0.002 (0.2 cents)
- 1000 summaries: ~$2.00

This is very affordable for most use cases.

## Support

If you encounter any issues:
1. Check the Netlify function logs
2. Verify database migration was successful
3. Ensure environment variables are set correctly
4. Check browser console for frontend errors

---

Happy summarizing! 🚀✨
