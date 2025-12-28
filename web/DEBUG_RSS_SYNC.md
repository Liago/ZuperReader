# 🔍 Debug: Perché i Badge Non Compaiono

## Passi di Debug

### 1️⃣ Fai il Merge e Deploy

```bash
git checkout main
git merge claude/feed-read-tracking-G03Xq
git push
```

Aspetta 2-3 minuti per il deploy.

---

### 2️⃣ Apri la Console del Browser

1. Vai su https://tua-app.vercel.app/rss
2. Premi **F12** (o click destro → Ispeziona)
3. Vai sul tab **Console**

---

### 3️⃣ Apri un Feed

Click su qualsiasi feed nella sidebar.

**Guarda i log nella console**. Dovresti vedere:

```
🔄 Loading feed: { feedUrl: "https://...", feedId: "uuid-123..." }
📦 Feed data received: { hasError: false, itemsCount: 20, syncStats: { added: 20, existing: 0 } }
✅ Synced to database: { added: 20, existing: 0 }
📊 Tracked articles loaded: 20
```

---

## 🚨 Scenari Possibili

### ✅ CASO 1: Tutto OK
```
✅ Synced to database: { added: 15, existing: 0 }
📊 Tracked articles loaded: 15
```

**Cosa significa**: Gli articoli sono stati sincronizzati!

**Problema**: I badge potrebbero non aggiornarsi subito.

**Soluzione**: Ricarica la pagina (F5). Dovresti vedere i badge.

---

### ❌ CASO 2: feedId è null
```
🔄 Loading feed: { feedUrl: "https://...", feedId: null }
```

**Cosa significa**: Il feedId non viene passato dal componente padre.

**Problema**: RSSLayout o RSSPage non passa il feedId correttamente.

**Verifica sul Database**:
```sql
SELECT id, title, url FROM rss_feeds LIMIT 5;
```

Se i feed **NON hanno ID**, c'è un problema con la migrazione `rss_feeds`.

**Soluzione**: Ri-esegui la migrazione RSS base (`supabase-migration-rss.sql`).

---

### ❌ CASO 3: syncStats è undefined
```
📦 Feed data received: { hasError: false, itemsCount: 20, syncStats: undefined }
```

**Cosa significa**: Il feedId non arriva a `getFeedContent` o c'è un errore nella sync.

**Problema**: La funzione `syncRSSArticles` non viene chiamata.

**Verifica il codice**: Controlla `/app/actions/rss.ts` alla riga ~227.

**Debug manuale**:
1. Apri Supabase SQL Editor
2. Esegui:
```sql
-- Controlla se ci sono articoli
SELECT COUNT(*) FROM rss_articles;

-- Controlla user_id (dovrebbe essere il tuo UUID)
SELECT user_id, COUNT(*) FROM rss_articles GROUP BY user_id;
```

---

### ❌ CASO 4: Error durante sync
```
❌ Error loading feed: Error: ...
```

**Guarda l'errore completo nella console**.

Possibili cause:
- **Permission denied**: RLS policy non configurata
- **Column does not exist**: Migrazione non applicata correttamente
- **Foreign key violation**: `feed_id` non esiste nella tabella `rss_feeds`

**Soluzione**:

1. **Permission denied**:
```sql
-- Verifica RLS
SELECT tablename, policyname FROM pg_policies WHERE tablename = 'rss_articles';

-- Dovrebbe mostrare 4 policy: select_own, insert_own, update_own, delete_own
```

2. **Column error**:
```sql
-- Verifica colonne
SELECT column_name FROM information_schema.columns WHERE table_name = 'rss_articles';

-- Dovrebbe mostrare: id, feed_id, user_id, guid, title, link, pub_date, author, content, content_snippet, is_read, read_at, created_at, updated_at
```

3. **Foreign key**:
```sql
-- Controlla feed_id validi
SELECT id, title FROM rss_feeds WHERE user_id = 'TUO_UUID';
```

---

### ❌ CASO 5: Tracked articles loaded: 0 (anche se sync dice added: 20)
```
✅ Synced to database: { added: 20, existing: 0 }
📊 Tracked articles loaded: 0  ← PROBLEMA QUI
```

**Cosa significa**: Gli articoli vengono inseriti ma non recuperati.

**Problema**: RLS policy blocca il SELECT o user_id non corrisponde.

**Debug**:
```sql
-- Verifica user_id attuale (dalla console browser, guarda auth)
SELECT auth.uid();

-- Cerca articoli con quel user_id
SELECT user_id, COUNT(*) FROM rss_articles GROUP BY user_id;
```

Se i `user_id` **non corrispondono**, il problema è nell'autenticazione o nella sincronizzazione.

**Soluzione**: Verifica che `createClient()` usi lo stesso user_id in sync e in query.

---

## 🔧 Quick Fixes

### Fix 1: Forza Re-sync

Se la tabella è vuota ma dovrebbe essere piena:

1. Vai su `/rss`
2. **Click su ogni feed uno alla volta**
3. Aspetta 2-3 secondi per feed
4. Ricarica la pagina

Gli articoli dovrebbero popolarsi.

### Fix 2: Verifica Migrazione Completa

Esegui questo SQL su Supabase per verificare che **TUTTO** sia a posto:

```sql
-- 1. Tabella esiste?
SELECT EXISTS (
  SELECT FROM information_schema.tables
  WHERE table_name = 'rss_articles'
);
-- Dovrebbe ritornare: true

-- 2. Policy RLS abilitate?
SELECT relrowsecurity FROM pg_class WHERE relname = 'rss_articles';
-- Dovrebbe ritornare: true

-- 3. Funzioni esistono?
SELECT proname FROM pg_proc WHERE proname IN ('get_feed_unread_count', 'get_all_feeds_unread_counts');
-- Dovrebbe ritornare 2 righe

-- 4. Trigger esiste?
SELECT tgname FROM pg_trigger WHERE tgname = 'update_rss_articles_updated_at';
-- Dovrebbe ritornare: update_rss_articles_updated_at
```

Se **qualcuna di queste** ritorna vuoto/false, **ri-esegui la migrazione** completa.

### Fix 3: Test Manuale Insert

Prova a inserire un articolo manualmente:

```sql
INSERT INTO rss_articles (
  user_id,
  feed_id,
  guid,
  title,
  link,
  is_read
) VALUES (
  auth.uid(),  -- Il tuo user_id
  (SELECT id FROM rss_feeds LIMIT 1),  -- Un feed esistente
  'test-guid-123',
  'Test Article',
  'https://example.com/test',
  false
);

-- Verifica che sia stato inserito
SELECT * FROM rss_articles WHERE guid = 'test-guid-123';
```

Se questo **funziona**, il problema è nella logica di sync del codice.

Se questo **dà errore**, il problema è nel database (permission, RLS, etc).

---

## 📋 Checklist Finale

Dopo i test, verifica:

- [ ] Console mostra `✅ Synced to database`
- [ ] Console mostra `📊 Tracked articles loaded: X` (X > 0)
- [ ] Query SQL `SELECT COUNT(*) FROM rss_articles` ritorna > 0
- [ ] Ricaricando la pagina vedi i badge
- [ ] Scrollando gli articoli diventano grigi
- [ ] I conteggi si aggiornano

---

## 💬 Cosa Inviarmi

Se ancora non funziona, inviami:

1. **Screenshot della console** con i log
2. **Output di questa query**:
```sql
SELECT
  COUNT(*) as total_articles,
  COUNT(CASE WHEN is_read THEN 1 END) as read_articles,
  COUNT(DISTINCT feed_id) as feeds_with_articles,
  COUNT(DISTINCT user_id) as users
FROM rss_articles;
```
3. **Se vedi errori**, copia l'errore completo

Così posso capire esattamente dove si blocca!
