# 🚀 Come Attivare il Tracking RSS

Per vedere **badge conteggi**, **indicatori di lettura**, e **articoli grigi**, devi fare **1 cosa fondamentale**.

## ⚠️ STEP OBBLIGATORIO: Applica la Migrazione Database

**Senza questo step, NIENTE funziona.** La tabella `rss_articles` non esiste ancora.

### 1. Vai su Supabase Dashboard

https://supabase.com/dashboard/project/YOUR_PROJECT_ID

### 2. Apri SQL Editor

Dashboard → **SQL Editor** (nella sidebar sinistra)

### 3. Copia e Incolla Questo SQL

Apri il file `web/supabase-migration-rss-articles.sql` e copia **TUTTO il contenuto**.

Oppure copia da qui:

```sql
-- ============================================
-- MIGRATION: RSS Articles Read Tracking
-- ============================================

-- Create rss_articles table to track individual feed items and their read status
CREATE TABLE IF NOT EXISTS rss_articles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    feed_id UUID NOT NULL REFERENCES rss_feeds(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    -- Article identification (guid from RSS feed is the unique identifier)
    guid TEXT NOT NULL,

    -- Article metadata
    title TEXT NOT NULL,
    link TEXT NOT NULL,
    pub_date TIMESTAMPTZ,
    author TEXT,
    content TEXT,
    content_snippet TEXT,

    -- Read tracking
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMPTZ,

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Prevent duplicate articles for same user/feed
    UNIQUE(user_id, feed_id, guid)
);

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_rss_articles_user_id ON rss_articles(user_id);
CREATE INDEX IF NOT EXISTS idx_rss_articles_feed_id ON rss_articles(feed_id);
CREATE INDEX IF NOT EXISTS idx_rss_articles_is_read ON rss_articles(is_read);
CREATE INDEX IF NOT EXISTS idx_rss_articles_pub_date ON rss_articles(pub_date DESC);

-- Composite index for efficient unread count queries
CREATE INDEX IF NOT EXISTS idx_rss_articles_user_feed_read
    ON rss_articles(user_id, feed_id, is_read);

-- ============================================
-- ROW LEVEL SECURITY POLICIES
-- ============================================

-- Enable RLS
ALTER TABLE rss_articles ENABLE ROW LEVEL SECURITY;

-- Users can only see their own RSS articles
CREATE POLICY "rss_articles_select_own" ON rss_articles
    FOR SELECT USING (auth.uid() = user_id);

-- Users can only insert their own RSS articles
CREATE POLICY "rss_articles_insert_own" ON rss_articles
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can only update their own RSS articles
CREATE POLICY "rss_articles_update_own" ON rss_articles
    FOR UPDATE USING (auth.uid() = user_id);

-- Users can only delete their own RSS articles
CREATE POLICY "rss_articles_delete_own" ON rss_articles
    FOR DELETE USING (auth.uid() = user_id);

-- ============================================
-- TRIGGERS
-- ============================================

-- Trigger to update updated_at timestamp
DROP TRIGGER IF EXISTS update_rss_articles_updated_at ON rss_articles;
CREATE TRIGGER update_rss_articles_updated_at
    BEFORE UPDATE ON rss_articles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- FUNCTIONS
-- ============================================

-- Function to get unread count for a specific feed
CREATE OR REPLACE FUNCTION get_feed_unread_count(p_user_id UUID, p_feed_id UUID)
RETURNS INTEGER AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)::INTEGER
        FROM rss_articles
        WHERE user_id = p_user_id
        AND feed_id = p_feed_id
        AND is_read = FALSE
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get unread counts for all feeds of a user
CREATE OR REPLACE FUNCTION get_all_feeds_unread_counts(p_user_id UUID)
RETURNS TABLE(feed_id UUID, unread_count BIGINT) AS $$
BEGIN
    RETURN QUERY
    SELECT
        rss_articles.feed_id,
        COUNT(*) as unread_count
    FROM rss_articles
    WHERE rss_articles.user_id = p_user_id
    AND rss_articles.is_read = FALSE
    GROUP BY rss_articles.feed_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### 4. Esegui (Run)

Click sul bottone **RUN** in alto a destra.

Dovresti vedere: ✅ **Success. No rows returned**

---

## ✅ Verifica che Funzioni

### 1. Deploy il Branch

Mergia il branch su main e fai deploy:

```bash
git checkout main
git merge claude/feed-read-tracking-G03Xq
git push
```

### 2. Apri l'App RSS

Vai su https://tua-app.vercel.app/rss

### 3. Seleziona un Feed

Click su un feed nella sidebar.

### 4. Cosa Dovresti Vedere

**✨ Prima Volta** (appena aperto il feed):
- Tutti gli articoli hanno il **dot arancione** 🟠 (non letti)
- Sfondo **bianco**
- Testo **nero**

**📜 Dopo lo Scrolling**:
- Man mano che scorri, gli articoli passano sopra la riga cambiano:
  - Dot diventa **grigio** ⚫
  - Sfondo diventa **grigio chiaro**
  - Testo diventa **grigio**
  - Badge **"Read"** appare

**🔢 Nella Sidebar**:
- Accanto ad ogni feed dovresti vedere il **badge arancione** con il numero
- Esempio: `The Verge [15]` ← 15 articoli non letti
- Il numero **diminuisce** mentre scrolli e leggi

---

## 🐛 Troubleshooting

### "Non vedo i badge nella sidebar"

**Causa**: La migrazione non è stata applicata O non hai ancora aperto nessun feed.

**Soluzione**:
1. Verifica che la tabella esista su Supabase:
   - SQL Editor → `SELECT * FROM rss_articles LIMIT 1;`
   - Se errore "table does not exist" → rifai lo step 3
2. Apri un feed → Gli articoli vengono sincronizzati al primo caricamento
3. Ricarica la pagina → I badge dovrebbero apparire

### "Gli articoli non diventano grigi"

**Causa**: Gli articoli non vengono marcati come letti durante lo scrolling.

**Soluzione**:
1. Apri la Console del browser (F12)
2. Guarda se ci sono errori rossi
3. Scrolla lentamente e aspetta 1-2 secondi per articolo
4. L'Intersection Observer ha un offset di 80px

### "Vedo errori nella console"

**Possibili errori**:
```
Failed to mark article as read
```

**Causa**: Row Level Security policy non configurata correttamente.

**Soluzione**: Verifica che hai eseguito **TUTTA** la migrazione SQL (incluse le policy RLS).

### "La tabella rss_articles è vuota"

**È normale!** La tabella si riempie:
1. **Primo caricamento del feed**: Gli articoli vengono sincronizzati automaticamente
2. **Solo per feed aperti**: Non sincronizza feed mai visitati

Per popolare subito:
- Apri ogni feed uno alla volta
- Gli articoli verranno aggiunti automaticamente

---

## 📊 Come Verificare il Database

### Controlla Tabella

```sql
-- Vedi se esiste
SELECT COUNT(*) FROM rss_articles;

-- Vedi articoli per utente
SELECT user_id, COUNT(*) as total_articles
FROM rss_articles
GROUP BY user_id;

-- Vedi articoli non letti
SELECT COUNT(*) as unread
FROM rss_articles
WHERE is_read = false;
```

### Controlla Conteggi

```sql
-- Unread per feed
SELECT
    rf.title as feed_title,
    COUNT(ra.*) as unread_count
FROM rss_feeds rf
LEFT JOIN rss_articles ra ON ra.feed_id = rf.id AND ra.is_read = false
GROUP BY rf.id, rf.title
ORDER BY unread_count DESC;
```

---

## 🎨 Cosa Hai Implementato

### Visual Indicators

| Stato | Dot | Background | Testo | Badge |
|-------|-----|------------|-------|-------|
| **Unread** | 🟠 Arancione | ⬜ Bianco | ⬛ Nero | - |
| **Read** | ⚫ Grigio | ◻️ Grigio chiaro | ◼️ Grigio | "Read" |

### Layout List View

- ✅ Righe compatte (no card)
- ✅ Tutta la riga clickable
- ✅ Hover: arancione
- ✅ Metadata inline
- ✅ Azioni piccole (save, open)

### Scroll-based Tracking

- ✅ Automatic: scrolli = marcato come letto
- ✅ Offset 80px (dopo header)
- ✅ No click necessario
- ✅ Real-time update

### Sidebar Badges

- ✅ Numero articoli non letti
- ✅ Badge arancione/rosa
- ✅ Auto-update quando leggi
- ✅ Max "99+" se oltre 99

---

## 🎯 Checklist Finale

Prima di usare l'app, verifica:

- [ ] Migrazione SQL eseguita su Supabase
- [ ] Tabella `rss_articles` esiste
- [ ] Branch mergiato su main
- [ ] Deploy fatto su Vercel
- [ ] App aperta su /rss
- [ ] Feed selezionato
- [ ] Articoli hanno dot arancione
- [ ] Scrolling marca come letti
- [ ] Badge appaiono nella sidebar

**✅ Fatto?** Ora l'app traccia perfettamente la lettura! 🎉
