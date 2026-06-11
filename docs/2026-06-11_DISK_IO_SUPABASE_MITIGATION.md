# Mitigazione Disk IO Budget Supabase

**Data**: 11 Giugno 2026
**Progetto Supabase**: `wjotvfawhnibnjgoaqud` (AZReader)
**Stato**: ✅ Implementato (richiede applicazione manuale migrazioni SQL)

---

## 1. Sommario esecutivo

Il team Supabase ha notificato via email che il progetto sta esaurendo il **Disk IO Budget** del compute add-on. Il 10 giugno 2026, tra le **21:11 e le 21:25 UTC**, il database è diventato irresponsivo e si è auto-riavviato. Il giorno successivo l'app era nuovamente operativa ma la causa root è rimasta presente.

L'analisi della Query Performance e dei Postgres Logs ha identificato la causa principale: **una UPDATE non filtrata sulla tabella `rss_articles`** (write amplification) combinata con **query di aggregazione client-side** che leggevano grandi quantità di righe per contarle. Sono stati applicati 5 fix mirati (codice + SQL) che eliminano la fonte del consumo IO e prevengono la ricomparsa del problema.

---

## 2. Diagnosi

### 2.1 Stato delle tabelle al momento dell'incidente

| Tabella           | Righe   | Dimensione | % del DB |
|-------------------|---------|------------|----------|
| `rss_articles`    | 76.743  | 194 MB     | 53,3%    |
| `articles`        | —       | 118 MB     | 32,5%    |
| `idx_articles_content_trigram` | — | 19,3 MB | 5,3% |
| Totale DB         | —       | 0,36 GB / 8 GB allocati | — |

Lo spazio disco non era saturo. Il problema era **IOPS + lock contention**.

### 2.2 Top query per tempo consumato (Query Performance)

| % tempo | Query                                                       | Calls | Mean | Max     |
|---------|-------------------------------------------------------------|-------|------|---------|
| **47,6%** | `UPDATE rss_articles SET is_read=?, read_at=? WHERE ...` | 18    | 1977ms | **7504ms** ⚠️ |
| 29,1%   | `SELECT rss_articles.* WHERE user_id=?`                     | 34    | 639ms  | 3256ms  |
| 8,7%    | `SELECT articles.* WHERE user_id=?`                         | 2     | 3268ms | 4353ms  |
| 3,0%    | `SELECT name FROM pg_timezone_names` (sistema)              | 4     | 561ms  | 1143ms  |

### 2.3 Postgres Logs durante il crash

```
21:11:24  process 638790 still waiting for ShareLock on transaction 116699 after 1000ms
21:11:24  process 638791 still waiting for ExclusiveLock on tuple (3,6) of relation 563852 after 1000ms
21:11:26  process 638790 acquired ShareLock after 2669ms
21:11:26  process 638791 acquired ExclusiveLock after 2591ms
21:13:22  ERROR: canceling statement due to statement timeout
21:13:25  ERROR: canceling statement due to statement timeout
21:25:37  FATAL: the database system is not accepting connections (×17)
21:25:39  LOG: database system is ready to accept connections   ← restart automatico
```

Il pattern è chiaro: lock esclusivi sulla relation `rss_articles` mantenuti per ~7 secondi, accumulo di richieste in coda, statement timeout, saturazione IO, riavvio.

---

## 3. Causa root

### Bug primario: `markFeedAsRead` iOS senza filtro `is_read = false`

[`ios/SuperReader/SuperReader/Services/RSSService.swift`](../ios/SuperReader/SuperReader/Services/RSSService.swift) `markFeedAsRead(feedId:userId:)` aggiornava **tutte** le righe del feed appartenenti all'utente, incluse quelle già lette. La versione web ([`web/src/lib/api.ts`](../web/src/lib/api.ts) `markAllFeedArticlesAsRead`) filtrava correttamente con `.eq('is_read', false)`. L'iOS no.

Conseguenza: ogni "mark feed as read" su un feed grande riscriveva migliaia di righe già lette → write amplification 3-5x → lock esclusivo prolungato sulla tabella.

### Causa secondaria: aggregazione client-side delle unread counts

Sia il web (`getAllFeedsUnreadCounts`) sia l'iOS (`getUnreadCounts`) leggevano **tutti gli articoli unread** in memoria solo per contarli `GROUP BY feed_id` lato client. Per un utente con 76k righe, anche con indice, ogni richiesta della lista feed (chiamata frequente) trasferiva molti dati e occupava il planner.

Era già presente nella migration originale ([`web/supabase-migration-rss-articles.sql:96-108`](../web/supabase-migration-rss-articles.sql#L96-L108)) una funzione RPC `get_all_feeds_unread_counts(p_user_id)` mai utilizzata dai client.

### Concause minori

- Throttle dell'auto-refresh feeds RSS (`RSSViewModel.shouldAutoRefresh`) viveva solo in memoria → ogni cold start dell'app azzerava il gate.
- Nessun indice parziale per `WHERE is_read = false`.
- Nessuna policy di retention sugli articoli RSS letti → tabella in crescita illimitata.

---

## 4. Fix applicati

### Fix 1 — Bug iOS `markFeedAsRead` ✅

**File**: [`ios/SuperReader/SuperReader/Services/RSSService.swift`](../ios/SuperReader/SuperReader/Services/RSSService.swift)

```diff
 try await SupabaseService.shared.client
     .from("rss_articles")
     .update(payload)
     .eq("feed_id", value: feedId)
     .eq("user_id", value: userId)
+    .eq("is_read", value: false)
     .execute()
```

Stop write amplification. La UPDATE ora tocca solo le righe effettivamente non lette.

### Fix 2 — Switch a RPC server-side per le unread counts ✅

**Web** ([`web/src/lib/api.ts`](../web/src/lib/api.ts) `getAllFeedsUnreadCounts`):

```diff
- const { data, error } = await db
-     .from('rss_articles')
-     .select('feed_id')
-     .eq('user_id', userId)
-     .eq('is_read', false);
+ const { data, error } = await db.rpc(
+     'get_all_feeds_unread_counts',
+     { p_user_id: userId }
+ );

  const counts = new Map<string, number>();
- (data || []).forEach((item) => {
-     counts.set(item.feed_id, (counts.get(item.feed_id) || 0) + 1);
- });
+ (data || []).forEach((item: { feed_id: string; unread_count: number }) => {
+     counts.set(item.feed_id, Number(item.unread_count));
+ });
```

**iOS** ([`ios/SuperReader/SuperReader/Services/RSSService.swift`](../ios/SuperReader/SuperReader/Services/RSSService.swift) `getUnreadCounts`):

```swift
let rows: [UnreadAggregate] = try await SupabaseService.shared.client
    .rpc("get_all_feeds_unread_counts", params: ["p_user_id": userId])
    .execute()
    .value
```

L'aggregazione `COUNT(*) GROUP BY feed_id` avviene ora lato Postgres usando gli indici esistenti, riducendo drasticamente il payload trasferito.

### Fix 3 — Indice parziale su righe unread ✅

**File**: [`web/supabase-migration-rss-articles-partial-index.sql`](../web/supabase-migration-rss-articles-partial-index.sql)

```sql
CREATE INDEX IF NOT EXISTS idx_rss_articles_user_unread
    ON rss_articles (user_id, feed_id)
    WHERE is_read = FALSE;

ANALYZE rss_articles;
```

Un indice parziale indicizza solo le righe con `is_read = FALSE`. Rimane piccolo anche con tabella in crescita, accelera SELECT (unread counts) e UPDATE mirate (`markFeedAsRead`).

### Fix 4 — Throttle persistente cross-session ✅

**File**: [`ios/SuperReader/SuperReader/ViewModels/RSSViewModel.swift`](../ios/SuperReader/SuperReader/ViewModels/RSSViewModel.swift)

```swift
private static let lastAutoRefreshKey = "rss.lastAutoRefreshDate"
private static let autoRefreshInterval: TimeInterval = 15 * 60

private var lastRefreshDate: Date? {
    get { UserDefaults.standard.object(forKey: Self.lastAutoRefreshKey) as? Date }
    set { UserDefaults.standard.set(newValue, forKey: Self.lastAutoRefreshKey) }
}
```

Il timestamp dell'ultimo auto-refresh è ora persistito in `UserDefaults`. Cold start dell'app non azzerano più il gate. Finestra portata da **5 → 15 minuti** (i feed RSS aggiornano di rado).

### Fix 5 — Cleanup automatico articoli vecchi ✅

**File**: [`web/supabase-migration-rss-articles-cleanup.sql`](../web/supabase-migration-rss-articles-cleanup.sql)

Funzione SQL `cleanup_old_rss_articles(retention_days, batch_size)`:

- Cancella articoli con `is_read = TRUE` e `read_at < NOW() - retention_days`.
- Cancellazioni in batch (default 1000 righe) per evitare lock contention.
- `SECURITY DEFINER` + GRANT a `service_role`.
- Pronta per scheduling via pg_cron (esempio commentato nel file).

---

## 5. Procedura di deploy

### 5.1 Codice (web + iOS)

Nessuna azione: i build sono già verdi (`npm run build` e `xcodebuild build`). I cambi entreranno in produzione al prossimo deploy web e alla prossima release iOS.

### 5.2 Migrazioni SQL (manuali)

Da eseguire nell'ordine indicato dal SQL Editor della dashboard Supabase:

1. **Indice parziale** — incollare ed eseguire [`web/supabase-migration-rss-articles-partial-index.sql`](../web/supabase-migration-rss-articles-partial-index.sql).
2. **Funzione cleanup** — incollare ed eseguire [`web/supabase-migration-rss-articles-cleanup.sql`](../web/supabase-migration-rss-articles-cleanup.sql).

### 5.3 Cleanup one-shot dello storico

Per ridurre subito le 76.743 righe attuali:

```sql
SELECT public.cleanup_old_rss_articles(60, 1000);
```

Cancella articoli letti più vecchi di 60 giorni in batch da 1000. Restituisce il totale eliminato.

### 5.4 Scheduling cleanup ricorrente (opzionale)

`pg_cron` è già abilitato sul progetto. Per pulizia notturna alle 03:00 UTC:

```sql
SELECT cron.schedule(
    'rss-articles-cleanup-daily',
    '0 3 * * *',
    $$SELECT public.cleanup_old_rss_articles(60, 1000);$$
);
```

Per disabilitare:

```sql
SELECT cron.unschedule('rss-articles-cleanup-daily');
```

---

## 6. Verifica

### 6.1 Build

- ✅ Web: `cd web && npm run build` — build Next.js + TypeScript completati senza errori.
- ✅ iOS: `xcodebuild -project SuperReader.xcodeproj -scheme SuperReader -configuration Debug -destination 'generic/platform=iOS Simulator' build` — `** BUILD SUCCEEDED **`.

### 6.2 Smoke test funzionale (post-deploy)

1. Aprire l'app iOS, andare nella tab RSS.
2. Selezionare un feed con molti articoli misti (letti e non).
3. Premere "Mark feed as read".
4. Nella dashboard Supabase, **Logs → Postgres**, verificare che la UPDATE rimanga sotto 1 secondo (era 1977ms media, max 7504ms).
5. Tornare alla lista feed: le unread counts devono essere corrette e la richiesta deve completare rapidamente (era una SELECT con scansione, ora è un'aggregazione indicizzata).

### 6.3 Monitoraggio (post-deploy 24-72h)

Dashboard Supabase **Reports → Database**:

- Grafico **Disk IO Budget**: pendenza di consumo deve essere significativamente inferiore.
- Grafico **Database Egress**: deve calare (meno righe trasferite al client per le unread counts).
- **Query Performance**: la UPDATE su `rss_articles` deve uscire dalla top 5 o avere `mean_time` < 200ms.

---

## 7. File modificati

### Codice

- [`ios/SuperReader/SuperReader/Services/RSSService.swift`](../ios/SuperReader/SuperReader/Services/RSSService.swift) — Fix 1, Fix 2b
- [`ios/SuperReader/SuperReader/ViewModels/RSSViewModel.swift`](../ios/SuperReader/SuperReader/ViewModels/RSSViewModel.swift) — Fix 4
- [`web/src/lib/api.ts`](../web/src/lib/api.ts) — Fix 2a

### Nuove migrazioni SQL

- [`web/supabase-migration-rss-articles-partial-index.sql`](../web/supabase-migration-rss-articles-partial-index.sql) — Fix 3
- [`web/supabase-migration-rss-articles-cleanup.sql`](../web/supabase-migration-rss-articles-cleanup.sql) — Fix 5

---

## 8. Fallback

Se anche dopo l'applicazione completa di tutti i fix il Disk IO Budget continuasse a esaurirsi:

1. **Upgrade compute add-on Supabase** (Micro → Small o superiore) — soluzione immediata, costo mensile aggiuntivo.
2. **Refactor sincronizzazione RSS server-side** — una Edge Function schedulata che fa il fetch e l'upsert una sola volta per ogni feed URL, deduplicando a livello di sorgente invece che per utente. Refactor più importante, da pianificare separatamente.
