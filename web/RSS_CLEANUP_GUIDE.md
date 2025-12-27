# RSS Articles Cleanup Strategy

## Problema

La tabella `rss_articles` può crescere rapidamente:
- Un utente con 50 feed che pubblicano 10 articoli/giorno = 500 nuovi articoli/giorno
- In un mese: ~15.000 articoli
- In un anno: ~180.000 articoli per utente

## Come gestiscono i Feed Reader commerciali

### Feedly
- **Read articles**: 30 giorni di retention
- **Unread articles**: Illimitato (ma con soft limit di 1000 articoli per board)
- **Pulizia**: Automatica, quotidiana

### Inoreader
- **Read articles**: 90 giorni (piano free), 180+ giorni (pro)
- **Unread articles**: Illimitato con limite di storage totale
- **Pulizia**: Automatica + manuale

### NewsBlur
- **Read articles**: 30 giorni
- **Starred articles**: Illimitato
- **Pulizia**: Quotidiana automatica

## Strategia implementata in SuperReader

### 1. Retention Policy

```typescript
// web/src/lib/rssCleanup.ts
CLEANUP_CONFIG = {
    READ_RETENTION_DAYS: 30,        // Articoli letti: 30 giorni
    UNREAD_RETENTION_DAYS: 90,      // Articoli non letti: 90 giorni
    MAX_ARTICLES_PER_FEED: 200      // Max 200 articoli per feed
}
```

### 2. Operazioni di pulizia

**a) Cleanup articoli letti vecchi (30 giorni)**
- Elimina automaticamente articoli già letti dopo 30 giorni
- Mantiene il database leggero

**b) Cleanup articoli non letti molto vecchi (90 giorni)**
- Elimina articoli non letti più vecchi di 90 giorni
- Previene accumulo infinito di articoli "da leggere"

**c) Trim articoli per feed (200 max)**
- Mantiene solo i 200 articoli più recenti per feed
- Previene che singoli feed ad alto volume dominino il database

## Implementazione

### Opzione 1: Cron Job (Consigliato)

Crea un endpoint API per la pulizia:

```typescript
// web/src/app/api/cleanup-rss/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { runFullCleanup } from '@/lib/rssCleanup';

export async function POST(request: NextRequest) {
    // Verifica auth token per sicurezza
    const authHeader = request.headers.get('authorization');
    if (authHeader !== `Bearer ${process.env.CLEANUP_CRON_SECRET}`) {
        return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const supabase = await createClient();

    // Get all users
    const { data: users } = await supabase
        .from('user_profiles')
        .select('id');

    if (!users) {
        return NextResponse.json({ error: 'No users found' }, { status: 404 });
    }

    const results = [];
    for (const user of users) {
        const result = await runFullCleanup(user.id);
        results.push({ userId: user.id, ...result });
    }

    return NextResponse.json({
        success: true,
        processedUsers: users.length,
        results
    });
}
```

**Configura su Vercel (o altro hosting):**

```bash
# Vercel Cron Job (vercel.json)
{
  "crons": [{
    "path": "/api/cleanup-rss",
    "schedule": "0 2 * * *"  # Ogni giorno alle 2 AM
  }]
}
```

Oppure usa **GitHub Actions** o **Supabase Edge Functions** con cron.

### Opzione 2: Client-side on Login

```typescript
// Esegui cleanup quando l'utente fa login (max 1 volta/giorno)
import { runFullCleanup } from '@/lib/rssCleanup';

// In AuthContext o dopo login
useEffect(() => {
    if (!user) return;

    const lastCleanup = localStorage.getItem('lastRSSCleanup');
    const now = Date.now();
    const oneDayMs = 24 * 60 * 60 * 1000;

    if (!lastCleanup || now - parseInt(lastCleanup) > oneDayMs) {
        runFullCleanup(user.id).then(() => {
            localStorage.setItem('lastRSSCleanup', now.toString());
        });
    }
}, [user]);
```

### Opzione 3: Supabase Database Function (Scheduled)

```sql
-- Crea una funzione PostgreSQL
CREATE OR REPLACE FUNCTION cleanup_old_rss_articles()
RETURNS void AS $$
BEGIN
    -- Delete read articles older than 30 days
    DELETE FROM rss_articles
    WHERE is_read = true
    AND pub_date < NOW() - INTERVAL '30 days';

    -- Delete very old unread articles (90 days)
    DELETE FROM rss_articles
    WHERE is_read = false
    AND pub_date < NOW() - INTERVAL '90 days';

    -- Keep only last 200 articles per feed
    DELETE FROM rss_articles a
    WHERE id IN (
        SELECT id
        FROM (
            SELECT id,
                   ROW_NUMBER() OVER (PARTITION BY feed_id ORDER BY pub_date DESC) as rn
            FROM rss_articles
        ) ranked
        WHERE rn > 200
    );
END;
$$ LANGUAGE plpgsql;

-- Schedula con pg_cron (se disponibile)
SELECT cron.schedule('cleanup-rss-articles', '0 2 * * *', 'SELECT cleanup_old_rss_articles()');
```

## UI per Utenti

### Statistiche Cleanup

Mostra agli utenti quanto spazio stanno usando:

```typescript
import { getCleanupStats } from '@/lib/rssCleanup';

const stats = await getCleanupStats(userId);

console.log(`
Total articles: ${stats.totalArticles}
Can cleanup: ${stats.oldReadCount + stats.oldUnreadCount}
  - Old read: ${stats.oldReadCount}
  - Very old unread: ${stats.oldUnreadCount}
`);
```

### Cleanup Manuale

Permetti agli utenti di eseguire cleanup manualmente:

```tsx
// Settings page component
const handleManualCleanup = async () => {
    const result = await runFullCleanup(userId);
    alert(`Deleted ${result.totalDeleted} old articles`);
};

<button onClick={handleManualCleanup}>
    Clean Up Old Articles
</button>
```

## Metriche di Success

Con questa strategia:
- **User con 50 feed**: ~15.000 articoli/mese → max ~10.000 in database
- **Storage per utente**: ~5-10 MB (dipende da lunghezza contenuti)
- **1000 utenti**: ~10 GB totali (molto gestibile)

## Alternative Future

Se il database cresce comunque troppo:

1. **Archive a cold storage**: Sposta articoli vecchi su S3/object storage
2. **Aggregate data**: Tieni solo metadata per articoli vecchi, non contenuto completo
3. **Per-user limits**: Limita numero totale articoli per utente (es. 5000 max)
4. **Premium tier**: Utenti free = 30 giorni, utenti pro = 365 giorni

## Monitoring

Query per monitorare crescita:

```sql
-- Articles per user
SELECT user_id, COUNT(*) as article_count
FROM rss_articles
GROUP BY user_id
ORDER BY article_count DESC;

-- Database size
SELECT pg_size_pretty(pg_total_relation_size('rss_articles'));

-- Articles by age
SELECT
    CASE
        WHEN pub_date > NOW() - INTERVAL '7 days' THEN '< 1 week'
        WHEN pub_date > NOW() - INTERVAL '30 days' THEN '1-4 weeks'
        WHEN pub_date > NOW() - INTERVAL '90 days' THEN '1-3 months'
        ELSE '> 3 months'
    END as age_bracket,
    COUNT(*) as count
FROM rss_articles
GROUP BY age_bracket;
```

## Best Practices

1. ✅ **Esegui cleanup quotidianamente** (non ogni ora, è sufficiente 1x/giorno)
2. ✅ **Monitora le metriche** per aggiustare retention se necessario
3. ✅ **Notifica utenti** prima di eliminare articoli non letti molto vecchi
4. ✅ **Backup prima del cleanup** in produzione
5. ✅ **Log delle operazioni** per debugging
