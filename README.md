# SuperReader

Multi-platform article reader with Postlight Parser.

## Architecture

```
SuperReader/
├── web/          # Next.js frontend → Deploy on Vercel
├── parser-api/   # Parser function → Deploy on Netlify
├── mobile/       # iOS SwiftUI app
└── parser/       # Postlight Parser library
```

## Deployment

### 1. Parser API (Netlify)

1. Create new site on Netlify
2. Connect to this repo
3. Set **Base directory**: `parser-api`
4. Deploy

Your parser URL will be: `https://your-site.netlify.app/.netlify/functions/parse`

### 2. Web Frontend (Vercel)

1. Create new project on Vercel
2. Connect to this repo
3. Set **Root Directory**: `web`
4. Add environment variables:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
   - `NEXT_PUBLIC_PARSE_FUNCTION_URL` → Your Netlify parser URL
5. Deploy

### 3. Mobile (Xcode)

1. Open `mobile/` in Xcode
2. Update `SupabaseService.swift` with your parser URL
3. Build and run

## Local Development

```bash
# Web
cd web && npm install && npm run dev

# Parser API (requires netlify-cli)
cd parser-api && npm install && netlify dev
```
