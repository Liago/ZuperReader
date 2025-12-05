# Documentazione Tecnica - Architettura SuperReader (NextJS App)

## Panoramica

SuperReader è un'applicazione web sviluppata con Next.js 16 che permette agli utenti di salvare, organizzare e leggere articoli dal web. L'applicazione utilizza l'App Router di Next.js, Supabase per autenticazione e database, e Postlight Parser per l'estrazione dei contenuti.

## Stack Tecnologico

### Frontend
- **Next.js 16.0.7** - Framework React con App Router
- **React 19.2.0** - Libreria UI
- **TypeScript 5** - Type safety
- **Tailwind CSS 4** - Styling utility-first
- **@tailwindcss/typography** - Plugin per contenuti rich-text

### Backend & Servizi
- **Supabase** - BaaS (Backend as a Service)
  - Autenticazione passwordless (Magic Link OTP)
  - Database PostgreSQL
  - API REST auto-generate
- **@postlight/parser** - Parsing e estrazione contenuti da URL

### Tools di Sviluppo
- **ESLint 9** - Linting
- **eslint-config-next** - Configurazione ESLint per Next.js

## Architettura dell'Applicazione

### Struttura delle Directory

```
web/src/
├── app/                      # App Router (Next.js 13+)
│   ├── layout.tsx           # Root layout con AuthProvider
│   ├── page.tsx             # Homepage/Dashboard (protetta)
│   ├── globals.css          # Stili globali
│   ├── articles/
│   │   └── [id]/
│   │       └── page.tsx     # Pagina di lettura articolo (dynamic route)
│   ├── login/
│   │   └── page.tsx         # Pagina di login (Magic Link)
│   └── auth/
│       └── confirm/
│           └── page.tsx     # Conferma email OTP
├── components/              # Componenti React riutilizzabili
│   ├── ArticleForm.tsx     # Form per aggiungere nuovi articoli
│   └── ArticleList.tsx     # Lista articoli con view grid/list
├── contexts/               # React Context API
│   └── AuthContext.tsx     # Gestione stato autenticazione
└── lib/                    # Utilities e configurazioni
    ├── supabase.ts         # Client Supabase e type definitions
    └── api.ts              # Funzioni API per operazioni su articoli
```

## Componenti Principali

### 1. Root Layout (`app/layout.tsx`)

**Responsabilità:**
- Definizione del layout globale dell'applicazione
- Configurazione font (Geist Sans e Geist Mono)
- Wrapping dell'app con `AuthProvider` per gestione autenticazione globale
- Metadata dell'applicazione

**Caratteristiche:**
- Server Component di default
- Font optimization con `next/font/google`
- Context provider pattern per authentication state

### 2. Home/Dashboard (`app/page.tsx`)

**Tipo:** Client Component (`'use client'`)

**Responsabilità:**
- Dashboard principale protetta (richiede autenticazione)
- Visualizzazione form per aggiungere articoli
- Lista articoli dell'utente autenticato
- Gestione logout

**Flusso:**
1. Verifica stato autenticazione tramite `useAuth()`
2. Redirect a `/login` se utente non autenticato
3. Rendering form e lista articoli se autenticato
4. Refresh della lista articoli tramite trigger state

**Pattern Utilizzati:**
- Protected route pattern
- Lift state up (refreshTrigger)
- Composition pattern (ArticleForm + ArticleList)

### 3. Pagina di Login (`app/login/page.tsx`)

**Tipo:** Client Component

**Responsabilità:**
- Autenticazione passwordless via Magic Link
- Invio OTP email tramite Supabase
- Gestione stati di loading, errore e successo

**Flusso di Autenticazione:**
1. Utente inserisce email
2. Sistema invia magic link via Supabase
3. Visualizzazione messaggio di conferma
4. Utente clicca link nella email
5. Redirect a `/auth/confirm` per verifica

**UX:**
- Form semplice con validazione email
- Feedback visivo per ogni stato (loading, success, error)
- Possibilità di retry con email diversa

### 4. Conferma Autenticazione (`app/auth/confirm/page.tsx`)

**Tipo:** Client Component con Suspense

**Responsabilità:**
- Verifica del token OTP dalla query string
- Validazione della sessione con Supabase
- Redirect a dashboard dopo successo

**Implementazione:**
- Utilizza `useSearchParams()` per leggere token
- Componente wrapper con Suspense boundary
- Gestione stati: verifying, error, success
- Auto-redirect dopo verifica riuscita

### 5. Lettore Articolo (`app/articles/[id]/page.tsx`)

**Tipo:** Dynamic Route + Client Component

**Responsabilità:**
- Visualizzazione completa articolo
- Layout ottimizzato per lettura
- Protezione accesso (autenticazione richiesta)

**Caratteristiche:**
- Dynamic routing con `[id]`
- Rendering HTML sanitizzato con `dangerouslySetInnerHTML`
- Metadata articolo (autore, data, dominio)
- Link back to dashboard
- Responsive design con Tailwind typography

**Sicurezza:**
- Verifica autenticazione
- Controllo ownership articolo (user_id)

## Componenti Riutilizzabili

### ArticleForm (`components/ArticleForm.tsx`)

**Props:**
- `userId: string` - ID utente corrente
- `onArticleAdded: () => void` - Callback dopo aggiunta articolo

**Flusso:**
1. Input URL da utente
2. Chiamata a `parseArticle()` - parsing contenuto via Netlify Function
3. Chiamata a `saveArticle()` - salvataggio su Supabase
4. Trigger callback per refresh lista
5. Reset form

**Gestione Errori:**
- Try-catch per handling errori
- Visualizzazione messaggi di errore
- Disabling del form durante loading

### ArticleList (`components/ArticleList.tsx`)

**Props:**
- `userId: string` - ID utente per filtrare articoli
- `refreshTrigger: number` - Trigger per re-fetch articoli

**Caratteristiche:**
- Due modalità di visualizzazione: Grid e List
- Toggle view mode con icons SVG
- Card articolo con:
  - Immagine di copertina
  - Titolo (link a reader)
  - Excerpt
  - Metadata (dominio, tempo di lettura)
  - Link originale

**Pattern:**
- Controlled component pattern
- Effect dependency su refreshTrigger
- Responsive grid layout (1/2/3 colonne)

## Context API

### AuthContext (`contexts/AuthContext.tsx`)

**Scopo:** Gestione centralizzata dello stato di autenticazione

**State Gestito:**
- `user: User | null` - Oggetto utente Supabase
- `session: Session | null` - Sessione corrente
- `loading: boolean` - Stato caricamento iniziale

**Metodi Esposti:**
- `signInWithOtp(email: string)` - Invio magic link
- `signOut()` - Logout utente

**Implementazione:**
```typescript
- Inizializzazione: getSession() all'avvio
- Listener: onAuthStateChange() per aggiornamenti real-time
- Cleanup: unsubscribe su unmount
- Custom hook: useAuth() per accesso al context
```

**Pattern:**
- Provider pattern
- Custom hook pattern
- Subscription pattern per auth state changes

## Layer API (`lib/api.ts`)

### Funzioni Esportate

#### `parseArticle(url: string, userId: string)`
**Scopo:** Parsing contenuto articolo da URL

**Implementazione:**
- POST a Netlify Function `/parse`
- Utilizza @postlight/parser backend
- Estrae: content, title, excerpt, immagini, metadata

**Response:**
```typescript
{
  content: string;
  title: string;
  excerpt: string;
  lead_image_url: string;
  author: string;
  date_published: string;
  domain: string;
  word_count: number;
}
```

#### `saveArticle(parsedData: any, userId: string)`
**Scopo:** Salvataggio articolo su database

**Operazioni:**
- Estrazione dominio da URL
- Calcolo tempo di lettura stimato (word_count / 200 wpm)
- Insert su tabella Supabase `articles`
- Return dell'articolo creato

#### `getArticles(userId: string)`
**Scopo:** Recupero lista articoli utente

**Query:**
- Filtro per `user_id`
- Ordinamento per `created_at DESC`
- Return array di Article

#### `getArticleById(id: string)`
**Scopo:** Recupero singolo articolo

**Note:**
- Return `null` se non trovato (no throw)
- Utilizzato nel reader

#### `deleteArticle(articleId: string)`
**Scopo:** Eliminazione articolo

#### `toggleFavorite(articleId: string, isFavorite: boolean)`
**Scopo:** Toggle stato preferito

#### `updateReadingStatus(articleId: string, status: 'unread' | 'reading' | 'completed')`
**Scopo:** Aggiornamento stato lettura

## Configurazione Supabase (`lib/supabase.ts`)

### Client Configuration
```typescript
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;
export const supabase = createClient(supabaseUrl, supabaseAnonKey);
```

### Type Definition: Article

```typescript
type Article = {
  // Identificatori
  id: string;
  user_id: string;

  // Contenuto
  url: string;
  title: string;
  content: string | null;
  excerpt: string | null;

  // Media
  image_url: string | null;
  favicon_url: string | null;

  // Metadata
  author: string | null;
  published_date: string | null;
  domain: string | null;

  // Organizzazione
  tags: string[];
  is_favorite: boolean;
  reading_status: 'unread' | 'reading' | 'completed';

  // Engagement
  like_count: number;
  comment_count: number;

  // Calcoli
  estimated_read_time: number | null;

  // Visibility
  is_public: boolean;

  // Timestamps
  scraped_at: string;
  created_at: string;
  updated_at: string;
}
```

## Pattern Architetturali

### 1. App Router Pattern (Next.js 13+)

**Vantaggi:**
- File-based routing
- Layouts annidati
- Server Components di default
- Streaming e Suspense nativi

**Struttura:**
```
app/
├── layout.tsx          → Root layout (sempre attivo)
├── page.tsx           → Route: /
├── login/
│   └── page.tsx       → Route: /login
└── articles/
    └── [id]/
        └── page.tsx   → Route: /articles/:id
```

### 2. Client vs Server Components

**Server Components (default):**
- `layout.tsx` - Non necessita interattività

**Client Components (`'use client'`):**
- Tutti i page components (usano hooks)
- Tutti i componenti (usano state/effects)
- AuthContext (usa React Context)

**Rationale:**
- Hooks (useState, useEffect, useRouter, useContext) richiedono client
- Autenticazione richiede client-side state

### 3. Protected Routes Pattern

**Implementazione:**
```typescript
const { user, loading } = useAuth();

useEffect(() => {
  if (!loading && !user) {
    router.push('/login');
  }
}, [user, loading, router]);

if (loading) return <Loading />;
if (!user) return null; // Prevent flash before redirect
```

**Pagine Protette:**
- `/` (dashboard)
- `/articles/[id]` (reader)

**Pagine Pubbliche:**
- `/login`
- `/auth/confirm`

### 4. Composition Pattern

**Esempio: Home Page**
```typescript
<main>
  <header>...</header>
  <ArticleForm userId={user.id} onArticleAdded={handleArticleAdded} />
  <ArticleList userId={user.id} refreshTrigger={refreshTrigger} />
</main>
```

**Vantaggi:**
- Separazione delle responsabilità
- Riutilizzabilità componenti
- Testing isolato
- Manutenibilità

### 5. Lift State Up Pattern

**Problema:** ArticleForm deve notificare ArticleList del nuovo articolo

**Soluzione:**
```typescript
// Parent (page.tsx)
const [refreshTrigger, setRefreshTrigger] = useState(0);

const handleArticleAdded = () => {
  setRefreshTrigger(prev => prev + 1);
};

// ArticleForm riceve callback
<ArticleForm onArticleAdded={handleArticleAdded} />

// ArticleList si aggiorna su trigger change
<ArticleList refreshTrigger={refreshTrigger} />
```

### 6. Custom Hook Pattern

**AuthContext + useAuth Hook:**
```typescript
// Definizione
export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
}

// Utilizzo
const { user, loading, signOut } = useAuth();
```

**Vantaggi:**
- Incapsulamento logica
- Type safety
- Errori informativi
- Riutilizzabilità

## Flussi Applicativi

### Flusso di Autenticazione

```
1. User visita app (non autenticato)
   └→ AuthContext: loading=true, user=null

2. AuthContext inizializza
   └→ supabase.auth.getSession()
   └→ Se no session: loading=false, user=null

3. Protected route (/) rileva !user
   └→ router.push('/login')

4. User inserisce email su /login
   └→ signInWithOtp(email)
   └→ Supabase invia magic link
   └→ UI mostra "Check your email"

5. User clicca magic link in email
   └→ Redirect a /auth/confirm?token_hash=...&type=...

6. /auth/confirm page
   └→ supabase.auth.verifyOtp({token_hash, type})
   └→ Se successo: sessione creata
   └→ AuthContext onAuthStateChange triggered
   └→ user e session aggiornati
   └→ router.push('/') - redirect a dashboard

7. Dashboard ora accessibile
   └→ user !== null
   └→ Rendering ArticleForm e ArticleList
```

### Flusso di Aggiunta Articolo

```
1. User su Dashboard (/)
   └→ ArticleForm rendered

2. User inserisce URL e submit
   └→ setLoading(true)

3. parseArticle(url, userId)
   └→ POST a /.netlify/functions/parse
   └→ Postlight Parser estrae contenuto
   └→ Return: {content, title, excerpt, ...}

4. saveArticle(parsedData, userId)
   └→ Calcolo domain da URL
   └→ Calcolo estimated_read_time
   └→ supabase.from('articles').insert([...])
   └→ Return: Article object

5. Success
   └→ setUrl('') - reset form
   └→ onArticleAdded() - trigger callback

6. Parent (page.tsx)
   └→ handleArticleAdded()
   └→ setRefreshTrigger(prev => prev + 1)

7. ArticleList useEffect triggered
   └→ refreshTrigger changed
   └→ fetchArticles() re-runs
   └→ getArticles(userId)
   └→ setArticles(data) - UI updates
```

### Flusso di Lettura Articolo

```
1. User clicca articolo su Dashboard
   └→ Link: /articles/{article.id}

2. Router naviga a /articles/[id]/page.tsx
   └→ params.id = article ID

3. Page component mount
   └→ useAuth() verifica autenticazione
   └→ Se !user: redirect /login

4. Fetch articolo
   └→ getArticleById(id)
   └→ supabase.from('articles').select('*').eq('id', id)

5. Rendering
   └→ Header con immagine
   └→ Metadata (author, domain, date)
   └→ Content con dangerouslySetInnerHTML
   └→ Prose typography styles

6. User legge articolo
   └→ Click "Back to Dashboard"
   └→ Router.push('/')
```

## Styling & UI

### Tailwind CSS

**Configurazione:**
- Tailwind CSS 4
- PostCSS integration
- Typography plugin per prose content

**Design System:**
- Colors: Blue primary, Gray scale
- Spacing: Consistent padding/margin
- Typography: Geist Sans (body), Geist Mono (code)
- Shadows: Subtle elevation system

**Responsive Breakpoints:**
```css
sm: 640px  - Tablet
md: 768px  - Desktop small
lg: 1024px - Desktop large
```

**Common Patterns:**
- Card: `bg-white rounded-lg shadow-md`
- Button Primary: `bg-blue-600 text-white hover:bg-blue-700`
- Input: `border border-gray-300 rounded focus:ring-2 focus:ring-blue-500`
- Container: `max-w-7xl mx-auto`

### Layout Patterns

**Dashboard:**
- Full-height: `min-h-screen`
- Background: `bg-gray-100`
- Centered content: `max-w-7xl mx-auto`
- Responsive padding: `py-12 px-4 sm:px-6 lg:px-8`

**Article Reader:**
- Max width for readability: `max-w-3xl`
- Prose typography: `prose prose-lg prose-blue`
- Hero image: `h-64 sm:h-96`

**Grid vs List:**
- Grid: `grid gap-6 md:grid-cols-2 lg:grid-cols-3`
- List: `space-y-4` (vertical stacking)

## Sicurezza

### Row Level Security (RLS) su Supabase

**Assumption:** Configurazione RLS su tabella `articles`

```sql
-- Policy: Users can only read their own articles
CREATE POLICY "Users can view own articles"
ON articles FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Users can only insert their own articles
CREATE POLICY "Users can insert own articles"
ON articles FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can only update their own articles
CREATE POLICY "Users can update own articles"
ON articles FOR UPDATE
USING (auth.uid() = user_id);

-- Policy: Users can only delete their own articles
CREATE POLICY "Users can delete own articles"
ON articles FOR DELETE
USING (auth.uid() = user_id);
```

### XSS Protection

**Rischio:** Content HTML da articoli esterni

**Mitigazione:**
1. Content viene processato via Postlight Parser (sanitization)
2. Tailwind Typography plugin applica safe styles
3. CSP headers (configurare su produzione)

**Note:** `dangerouslySetInnerHTML` è necessario per rich content, ma richiede trust nel parser.

### Environment Variables

**Client-side (NEXT_PUBLIC_):**
```env
NEXT_PUBLIC_SUPABASE_URL=https://xxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJxxx...
NEXT_PUBLIC_PARSE_FUNCTION_URL=/.netlify/functions/parse
```

**Best Practices:**
- Mai esporre chiavi private
- Anon key è safe per client (RLS protegge data)
- Parse function URL configurable per multi-env

### Authentication Security

**Magic Link OTP:**
- Token hash via URL (one-time use)
- Token expiry (Supabase default: 1 ora)
- Email verification richiesta
- No password storage = ridotto rischio breach

**Session Management:**
- JWT token in httpOnly cookie (gestito da Supabase)
- Auto-refresh token
- Secure flag su HTTPS

## Performance Optimization

### Next.js Features

**Font Optimization:**
```typescript
import { Geist, Geist_Mono } from "next/font/google";
```
- Automatic font subsetting
- Preload fonts
- Zero layout shift

**Image Optimization:**
- Attualmente: `<img>` tag standard
- **Raccomandazione:** Migrate a `next/image` per:
  - Lazy loading
  - Responsive images
  - WebP conversion
  - Blur placeholder

**Code Splitting:**
- Automatic per route (App Router)
- Dynamic imports supportati
- Smaller initial bundles

### React Optimization Opportunities

**Potenziali Miglioramenti:**

1. **Memoization:**
```typescript
// ArticleList.tsx
const ArticleCard = React.memo(({ article }) => {...});
```

2. **useCallback per callbacks:**
```typescript
// page.tsx
const handleArticleAdded = useCallback(() => {
  setRefreshTrigger(prev => prev + 1);
}, []);
```

3. **Virtualization per liste lunghe:**
```typescript
// Se articoli > 100
import { FixedSizeList } from 'react-window';
```

### Data Fetching

**Attuale Implementazione:**
- Client-side fetching via Supabase SDK
- useEffect per data loading

**Possibili Migliorazioni:**
1. **SWR o React Query:**
   - Caching
   - Revalidation
   - Optimistic updates

2. **Server Components per initial data:**
   - SSR per SEO
   - Faster initial load
   - Progressive enhancement

## Testing Strategy

### Unit Testing

**Raccomandazioni:**

1. **Utility Functions (`lib/api.ts`):**
```typescript
// api.test.ts
describe('parseArticle', () => {
  it('should parse article from URL', async () => {
    // Mock fetch
    // Assert response structure
  });
});
```

2. **Components:**
```typescript
// ArticleForm.test.tsx
import { render, fireEvent, waitFor } from '@testing-library/react';

describe('ArticleForm', () => {
  it('should submit form with valid URL', async () => {
    // Test form submission
  });
});
```

### Integration Testing

**Supabase Auth Flow:**
- Test OTP email send
- Test token verification
- Test session persistence

**Article CRUD:**
- Test create article flow
- Test list articles
- Test delete article

### E2E Testing

**Recommended: Playwright**

```typescript
test('user can login and add article', async ({ page }) => {
  await page.goto('/login');
  await page.fill('input[type=email]', 'test@example.com');
  await page.click('button[type=submit]');
  // ... continue flow
});
```

## Deployment

### Environment Setup

**Required Env Vars:**
```env
# Supabase
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=

# Parse Function (optional, default: /.netlify/functions/parse)
NEXT_PUBLIC_PARSE_FUNCTION_URL=
```

### Build Process

```bash
# Install dependencies
npm install

# Development
npm run dev

# Production build
npm run build

# Start production server
npm start
```

### Hosting Options

**Vercel (Raccomandato):**
- Zero-config Next.js deployment
- Automatic HTTPS
- Edge network CDN
- Environment variables via dashboard

**Netlify:**
- Supporto Next.js
- Netlify Functions per parser
- Form handling
- Edge Functions

**Self-hosted:**
- Requires Node.js runtime
- PM2 per process management
- Nginx reverse proxy
- SSL via Let's Encrypt

## Database Schema

### Tabella: articles

```sql
CREATE TABLE articles (
  -- Primary Key
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  -- Foreign Key (riferimento a auth.users)
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Content
  url TEXT NOT NULL,
  title TEXT NOT NULL,
  content TEXT,
  excerpt TEXT,

  -- Media
  image_url TEXT,
  favicon_url TEXT,

  -- Metadata
  author TEXT,
  published_date TIMESTAMP WITH TIME ZONE,
  domain TEXT,

  -- Organization
  tags TEXT[] DEFAULT '{}',
  is_favorite BOOLEAN DEFAULT FALSE,
  reading_status TEXT DEFAULT 'unread' CHECK (reading_status IN ('unread', 'reading', 'completed')),

  -- Engagement
  like_count INTEGER DEFAULT 0,
  comment_count INTEGER DEFAULT 0,

  -- Computed
  estimated_read_time INTEGER,

  -- Visibility
  is_public BOOLEAN DEFAULT FALSE,

  -- Timestamps
  scraped_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_articles_user_id ON articles(user_id);
CREATE INDEX idx_articles_created_at ON articles(created_at DESC);
CREATE INDEX idx_articles_domain ON articles(domain);
CREATE INDEX idx_articles_reading_status ON articles(reading_status);

-- Trigger per updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_articles_updated_at
  BEFORE UPDATE ON articles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
```

## API Routes & Endpoints

### Netlify Function: Parse

**Endpoint:** `/.netlify/functions/parse`

**Method:** POST

**Request Body:**
```json
{
  "url": "https://example.com/article"
}
```

**Response:**
```json
{
  "content": "<p>Article content...</p>",
  "title": "Article Title",
  "excerpt": "Article summary...",
  "lead_image_url": "https://example.com/image.jpg",
  "author": "John Doe",
  "date_published": "2024-01-01T00:00:00.000Z",
  "domain": "example.com",
  "word_count": 1500
}
```

**Error Response:**
```json
{
  "error": "Failed to parse URL"
}
```

## Possibili Estensioni Future

### Features

1. **Search & Filtering:**
   - Full-text search su titoli e content
   - Filtri per domain, tags, reading status
   - Sort options (data, popolarità, alfabetico)

2. **Tags System:**
   - Auto-tagging via ML
   - Tag management UI
   - Tag-based navigation

3. **Reading Progress:**
   - Track scroll position
   - Resume reading
   - Progress bar

4. **Social Features:**
   - Condivisione articoli pubblici
   - Comments system
   - Like/bookmark

5. **Collections/Folders:**
   - Organizzazione gerarchica
   - Shared collections
   - Export collections

6. **Browser Extension:**
   - Quick save da qualsiasi pagina
   - Right-click "Save to SuperReader"
   - Offline reading sync

7. **Mobile App:**
   - React Native
   - Offline reading
   - Push notifications

8. **Advanced Reader:**
   - Text-to-speech
   - Adjustable typography (font size, line height)
   - Dark mode
   - Highlighting e annotations

### Technical Improvements

1. **Caching Strategy:**
   - Redis per parsed articles
   - CDN per media assets
   - Service Worker per offline

2. **Analytics:**
   - Reading time tracking
   - Popular domains
   - Usage patterns

3. **Background Jobs:**
   - Bulk import from bookmarks
   - Scheduled content refresh
   - Email digests

4. **API Rate Limiting:**
   - Throttling per user
   - Quota management

5. **Error Monitoring:**
   - Sentry integration
   - Log aggregation
   - Performance monitoring

## Conclusioni

SuperReader è un'applicazione moderna che sfrutta efficacemente l'ecosistema Next.js 13+ e Supabase. L'architettura è scalabile, sicura e mantiene una netta separazione tra concerns.

### Punti di Forza

- **Type Safety:** TypeScript end-to-end
- **Developer Experience:** Hot reload, modern tooling
- **Scalabilità:** Supabase gestisce scaling automatico
- **Sicurezza:** RLS + passwordless auth
- **Performance:** App Router + React 19

### Aree di Miglioramento

- **Testing:** Aggiungere test suite completa
- **Error Handling:** Più granulare e user-friendly
- **Image Optimization:** Migrate a next/image
- **State Management:** Considerare React Query per caching
- **Monitoring:** Aggiungere observability

### Manutenzione

**Aggiornamenti Dipendenze:**
```bash
# Check updates
npm outdated

# Update all (con cautela)
npm update

# Major versions (manuale)
npm install next@latest react@latest
```

**Code Quality:**
```bash
# Linting
npm run lint

# Type checking
npx tsc --noEmit

# Format (raccomandato: Prettier)
npx prettier --write .
```

---

**Versione Documento:** 1.0
**Data Creazione:** 2025-12-05
**Autore:** Documentazione Tecnica SuperReader
