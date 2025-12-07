# Ricerca Fulltext e Filtri Articoli

## Funzionalità Implementate

Questa implementazione aggiunge un sistema completo di ricerca e filtri per gli articoli nell'applicazione web.

### ✨ Caratteristiche

#### 🔍 Ricerca Fulltext
- Ricerca nei campi: titolo, contenuto, excerpt, autore, dominio
- Ricerca ottimizzata con indice GIN su PostgreSQL
- Debouncing automatico (300ms) per ridurre le query
- Supporto per ricerche multi-parola con operatore AND

#### 🎯 Filtri Disponibili
- **Tag**: Filtra per uno o più tag
- **Stato Lettura**: Tutti, Da leggere, In lettura, Completati
- **Preferiti**: Tutti, Solo preferiti, Non preferiti
- **Dominio**: Filtra per dominio di origine
- **Date Range**: Filtra per intervallo di date (implementazione base)

#### 📊 Ordinamento
- **Data creazione** (default, decrescente)
- **Data pubblicazione**
- **Più apprezzati** (per like_count)
- **Titolo** (alfabetico)
- Opzione crescente/decrescente per ogni campo

### 📁 File Modificati/Creati

#### Nuovi File
1. **`supabase-migration-article-search.sql`** - Migrazione database
   - Aggiunge colonna `search_vector` (tsvector generato)
   - Crea indice GIN per fulltext search
   - Aggiunge indici per ottimizzare filtri e ordinamento

2. **`src/components/SearchAndFilters.tsx`** - Componente UI
   - Barra di ricerca con icona e clear button
   - Panel filtri espandibile
   - Indicatore visivo di filtri attivi
   - Design responsive e moderno

#### File Modificati
1. **`src/lib/api.ts`**
   - Aggiunge interfacce: `ArticleFilters`, `ArticleSortOptions`, `ArticleSortField`, `ArticleSortOrder`
   - Estende funzione `getArticles()` con parametri opzionali per filtri e sort
   - Implementa query builder dinamico con Supabase

2. **`src/components/ArticleList.tsx`**
   - Integra componente `SearchAndFilters`
   - Aggiunge stati per filtri e ordinamento correnti
   - Calcola tag e domini disponibili dagli articoli
   - Gestisce il reset della paginazione quando cambiano filtri/sort

### 🗄️ Schema Database

#### Nuova Colonna
```sql
search_vector tsvector GENERATED ALWAYS AS (...)
```
Combina title, content, excerpt, author, domain con pesi diversi:
- Title: peso 'A' (massimo)
- Content e Excerpt: peso 'B'
- Author: peso 'C'
- Domain: peso 'D' (minimo)

#### Nuovi Indici
```sql
-- Fulltext search
CREATE INDEX idx_articles_search_vector ON articles USING GIN (search_vector);

-- Filtri ottimizzati
CREATE INDEX idx_articles_tags ON articles USING GIN (tags);
CREATE INDEX idx_articles_is_favorite ON articles(is_favorite) WHERE is_favorite = true;
CREATE INDEX idx_articles_published_date ON articles(published_date DESC NULLS LAST);
CREATE INDEX idx_articles_like_count ON articles(like_count DESC);

-- Indice composito per query comuni
CREATE INDEX idx_articles_user_status_created
ON articles(user_id, reading_status, created_at DESC);
```

## 🚀 Come Applicare la Migrazione

### Opzione 1: Via Supabase Dashboard (Consigliato)

1. Accedi al tuo progetto Supabase
2. Vai alla sezione **SQL Editor**
3. Copia il contenuto del file `supabase-migration-article-search.sql`
4. Incolla ed esegui la query
5. Verifica che non ci siano errori

### Opzione 2: Via Supabase CLI

```bash
# Assicurati di avere Supabase CLI installato e configurato
supabase db push --file supabase-migration-article-search.sql
```

### Verifica Migrazione

Dopo aver applicato la migrazione, verifica che gli indici siano stati creati:

```sql
-- Verifica indici
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'articles'
ORDER BY indexname;

-- Verifica colonna search_vector
SELECT column_name, data_type, generation_expression
FROM information_schema.columns
WHERE table_name = 'articles'
AND column_name = 'search_vector';
```

## 🎨 UI/UX

### Barra di Ricerca
- Input con icona di ricerca
- Placeholder: "Cerca negli articoli..."
- Pulsante clear visibile solo quando c'è testo
- Debouncing automatico per evitare query eccessive

### Panel Filtri
- Pulsante toggle "Filtri e Ordinamento"
- Indicatore "!" quando ci sono filtri attivi
- Pulsante "Cancella tutto" per reset rapido
- Design a schede espandibili
- Background sfumato per distinguerlo dalla lista

### Feedback Visivo
- Badge blu per filtri attivi
- Badge viola per tag selezionati
- Transizioni smooth su hover
- Stati disabled/loading gestiti

## 🔧 API Usage

### Esempio Base
```typescript
const { articles, hasMore } = await getArticles(userId, 10, 0);
```

### Con Ricerca
```typescript
const filters: ArticleFilters = {
  searchQuery: "react hooks"
};
const { articles, hasMore } = await getArticles(userId, 10, 0, filters);
```

### Con Filtri Multipli
```typescript
const filters: ArticleFilters = {
  searchQuery: "machine learning",
  tags: ["AI", "Tutorial"],
  readingStatus: "unread",
  isFavorite: true
};

const sort: ArticleSortOptions = {
  field: "published_date",
  order: "desc"
};

const { articles, hasMore } = await getArticles(userId, 10, 0, filters, sort);
```

## ⚡ Performance

### Ottimizzazioni Implementate
1. **Indici GIN** per fulltext search (~10-100x più veloce)
2. **Indici parziali** per filtri booleani (is_favorite)
3. **Indici compositi** per query comuni
4. **Debouncing** lato client (300ms)
5. **Infinite scrolling** mantenuto
6. **Memorizzazione** tag/domini con useMemo

### Query Performance
- Ricerca fulltext: ~5-50ms (con indice)
- Filtri multipli: ~10-100ms
- Ordinamento: ~1-10ms (con indici)

## 🧪 Testing

### Test Manuali
1. **Ricerca Testuale**
   - Cerca una parola nel titolo
   - Cerca nel contenuto
   - Cerca con più parole
   - Testa il debouncing

2. **Filtri**
   - Seleziona un tag
   - Seleziona più tag
   - Cambia stato lettura
   - Filtra solo preferiti
   - Combina più filtri

3. **Ordinamento**
   - Ordina per data creazione
   - Ordina per like
   - Cambia ordine crescente/decrescente

4. **Combinazioni**
   - Ricerca + filtri
   - Ricerca + ordinamento
   - Tutti insieme

### Test di Paginazione
- Verifica che l'infinite scroll funzioni con i filtri
- Cambia filtro e verifica che la lista si resetti
- Controlla il conteggio articoli

## 📝 Note Importanti

- **Retrocompatibilità**: La migrazione è sicura e non modifica dati esistenti
- **RLS Policies**: Non sono richieste modifiche alle policy
- **Colonna Generata**: `search_vector` si aggiorna automaticamente
- **Lingua**: Attualmente impostata su 'english' per lo stemming
- **Infinite Scroll**: Funziona normalmente con filtri attivi

## 🐛 Troubleshooting

### La ricerca non funziona
- Verifica che la migrazione sia stata applicata
- Controlla gli indici con la query di verifica
- Verifica i log del browser per errori

### Filtri non applicati
- Controlla la console per errori API
- Verifica che currentFilters sia aggiornato
- Controlla il network tab per le query Supabase

### Performance lente
- Verifica che gli indici siano stati creati
- Controlla il query plan con EXPLAIN ANALYZE
- Considera l'aggiornamento delle statistiche tabella

## 🔮 Futuri Miglioramenti

- [ ] Supporto ricerca multilingua
- [ ] Salvataggio filtri preferiti
- [ ] Filtri avanzati (date range picker)
- [ ] Ricerca fuzzy/typo-tolerant
- [ ] Highlights nei risultati di ricerca
- [ ] Suggerimenti di ricerca autocomplete
- [ ] Esportazione risultati filtrati
- [ ] Analytics su ricerche più comuni

## 📚 Riferimenti

- [PostgreSQL Full Text Search](https://www.postgresql.org/docs/current/textsearch.html)
- [Supabase Text Search](https://supabase.com/docs/guides/database/full-text-search)
- [Next.js Performance](https://nextjs.org/docs/app/building-your-application/optimizing)
