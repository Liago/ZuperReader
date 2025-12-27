# Setup Vercel Cron Job per RSS Cleanup

Questa guida ti mostra come configurare il cleanup automatico degli articoli RSS su Vercel.

## 🎯 Obiettivo

Il cron job eseguirà la pulizia automatica degli articoli RSS **ogni giorno alle 2:00 AM UTC** per:
- Eliminare articoli letti più vecchi di 30 giorni
- Eliminare articoli non letti più vecchi di 90 giorni
- Mantenere max 200 articoli per feed

## 📋 Passi Setup

### 1. Genera il CRON_SECRET

Genera un token casuale sicuro:

```bash
# Su macOS/Linux
openssl rand -base64 32

# Oppure usa Node.js
node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"

# Esempio output:
# X8k2Jd9Lp3Qr5Ts7Uv8Wx9Yz0Ab1Cd2Ef3Gh4Ij5Kl6=
```

Salva questo token - ti servirà nel passo successivo.

### 2. Aggiungi Environment Variable su Vercel

#### Opzione A: Dashboard Vercel (Consigliato)

1. Vai al tuo progetto su [Vercel Dashboard](https://vercel.com/dashboard)
2. Clicca su **Settings** → **Environment Variables**
3. Aggiungi nuova variabile:
   - **Name**: `CRON_SECRET`
   - **Value**: Il token generato al passo 1
   - **Environments**: Seleziona **Production**, **Preview**, **Development**
4. Clicca **Save**

#### Opzione B: Vercel CLI

```bash
cd web
vercel env add CRON_SECRET
# Incolla il token quando richiesto
# Seleziona: Production, Preview, Development
```

### 3. Deploy su Vercel

Il cron job è già configurato nel file `vercel.json`:

```json
{
  "crons": [
    {
      "path": "/api/cleanup-rss",
      "schedule": "0 2 * * *"
    }
  ]
}
```

**Deployment:**

```bash
# Commit le modifiche
git add .
git commit -m "feat: add Vercel cron job for RSS cleanup"
git push

# Vercel farà il deploy automaticamente (se hai GitHub integration)
# Oppure usa CLI:
vercel --prod
```

### 4. Verifica Setup

#### Test manuale dell'endpoint

```bash
# Sostituisci con il tuo CRON_SECRET
curl -X GET https://your-app.vercel.app/api/cleanup-rss \
  -H "Authorization: Bearer YOUR_CRON_SECRET"

# Output atteso:
{
  "success": true,
  "timestamp": "2025-12-27T10:30:00.000Z",
  "processedUsers": 5,
  "totalDeleted": 142,
  "totalErrors": 0,
  "results": [...]
}
```

#### Verifica il Cron su Vercel

1. Vai su Vercel Dashboard → Project → **Cron Jobs** tab
2. Dovresti vedere:
   - Path: `/api/cleanup-rss`
   - Schedule: `0 2 * * *` (Daily at 2:00 AM UTC)
   - Status: Active ✓

3. Puoi **testare manualmente** cliccando "Run" accanto al cron job

#### Controlla i Logs

```bash
# Con Vercel CLI
vercel logs --follow

# Oppure su Dashboard: Deployment → Logs
```

Cerca nei logs:
```
RSS Cleanup completed: 5 users processed, 142 articles deleted, 0 errors
```

## 📅 Schedule Cron

Il formato è **standard cron syntax**:

```
┌───────────── minuto (0-59)
│ ┌─────────── ora (0-23)
│ │ ┌───────── giorno del mese (1-31)
│ │ │ ┌─────── mese (1-12)
│ │ │ │ ┌───── giorno della settimana (0-6, domenica=0)
│ │ │ │ │
* * * * *
```

**Esempi:**

```json
// Ogni giorno alle 2:00 AM UTC
"schedule": "0 2 * * *"

// Ogni 6 ore
"schedule": "0 */6 * * *"

// Ogni domenica alle 3:00 AM
"schedule": "0 3 * * 0"

// Ogni primo del mese alle 1:00 AM
"schedule": "0 1 1 * *"
```

**⚠️ Nota:** Vercel Cron usa **sempre UTC timezone**.

## 🔒 Sicurezza

Il cron job è protetto da:
1. **Authorization header**: Richiede `Bearer CRON_SECRET`
2. **Environment variable**: Il secret è salvato solo su Vercel
3. **GET method**: Vercel Cron usa solo GET requests

**Non esporre mai il CRON_SECRET pubblicamente!**

## 🧪 Testing Locale

Per testare localmente:

```bash
# 1. Crea .env.local con il secret
echo "CRON_SECRET=test-secret-123" > .env.local

# 2. Avvia il server
npm run dev

# 3. Chiama l'endpoint
curl -X GET http://localhost:3000/api/cleanup-rss \
  -H "Authorization: Bearer test-secret-123"
```

## 📊 Monitoring

### Statistiche Cleanup

Ogni esecuzione del cron ritorna:

```json
{
  "processedUsers": 10,
  "totalDeleted": 1234,
  "totalErrors": 0,
  "results": [
    {
      "userId": "uuid-1",
      "deleted": 156,
      "details": {
        "oldRead": 120,
        "oldUnread": 30,
        "trimmed": 6
      },
      "errors": []
    }
  ]
}
```

### Alert su Errori

Aggiungi monitoring (opzionale):

```typescript
// In route.ts, dopo il cleanup
if (totalErrors > 0) {
  // Invia notifica (es. via email, Slack, Sentry)
  await sendAlert({
    message: `RSS Cleanup had ${totalErrors} errors`,
    details: results.filter(r => r.errors?.length > 0)
  });
}
```

### Database Size Monitoring

Query SQL per monitorare la crescita:

```sql
-- Articoli totali per utente
SELECT user_id, COUNT(*) as count
FROM rss_articles
GROUP BY user_id
ORDER BY count DESC
LIMIT 10;

-- Dimensione tabella
SELECT pg_size_pretty(pg_total_relation_size('rss_articles'));

-- Articoli per età
SELECT
  CASE
    WHEN pub_date > NOW() - INTERVAL '7 days' THEN '< 1 week'
    WHEN pub_date > NOW() - INTERVAL '30 days' THEN '1-4 weeks'
    WHEN pub_date > NOW() - INTERVAL '90 days' THEN '1-3 months'
    ELSE '> 3 months'
  END as age_bracket,
  COUNT(*) as count,
  SUM(CASE WHEN is_read THEN 1 ELSE 0 END) as read_count
FROM rss_articles
GROUP BY age_bracket;
```

## 🚨 Troubleshooting

### Cron non si attiva

1. **Verifica su Vercel Dashboard** → Cron Jobs tab
2. Controlla che il deploy sia andato a buon fine
3. Vercel Cron è **disponibile solo su Production** (non su Preview)

### Errore 401 Unauthorized

- Verifica che `CRON_SECRET` sia configurato correttamente
- Rigenera il secret e aggiornalo su Vercel
- Redeploy dopo aver cambiato env variables

### Timeout (Function Execution)

Se hai molti utenti, il cleanup potrebbe superare il timeout di Vercel:
- **Hobby plan**: 10 secondi max
- **Pro plan**: 60 secondi max

**Soluzione**: Processa gli utenti in batch o usa Vercel Edge Functions.

### Rate Limits Supabase

Con molti utenti, potresti superare i rate limits di Supabase:
- Aggiungi `await new Promise(r => setTimeout(r, 100))` tra gli utenti
- Oppure usa Supabase batch operations

## 🎛️ Configurazione Avanzata

### Cleanup Selettivo

Modifica `route.ts` per processare solo utenti attivi:

```typescript
// Solo utenti che hanno fatto login negli ultimi 30 giorni
const { data: profiles } = await supabase
  .from('user_profiles')
  .select('id, last_sign_in_at')
  .gte('last_sign_in_at', new Date(Date.now() - 30*24*60*60*1000).toISOString());
```

### Retention Personalizzata

Modifica `web/src/lib/rssCleanup.ts`:

```typescript
export const CLEANUP_CONFIG = {
    READ_RETENTION_DAYS: 60,      // Aumenta a 60 giorni
    UNREAD_RETENTION_DAYS: 180,   // Aumenta a 6 mesi
    MAX_ARTICLES_PER_FEED: 500    // Più spazio per feed
};
```

### Multiple Schedules

Aggiungi più cron jobs per diversi task:

```json
{
  "crons": [
    {
      "path": "/api/cleanup-rss",
      "schedule": "0 2 * * *"
    },
    {
      "path": "/api/cleanup-rss-aggressive",
      "schedule": "0 3 * * 0"
    }
  ]
}
```

## ✅ Checklist Deploy

- [ ] `CRON_SECRET` generato e salvato
- [ ] Environment variable aggiunta su Vercel
- [ ] `vercel.json` committato nel repo
- [ ] Deploy fatto su production
- [ ] Cron job visibile in Vercel Dashboard
- [ ] Test manuale dell'endpoint riuscito
- [ ] Logs verificati (nessun errore)
- [ ] Prima esecuzione automatica verificata (dopo 24h)

## 📚 Risorse

- [Vercel Cron Jobs Docs](https://vercel.com/docs/cron-jobs)
- [Cron Expression Generator](https://crontab.guru/)
- [Supabase Rate Limits](https://supabase.com/docs/guides/platform/rate-limits)

---

**🎉 Setup completato!** Il tuo database RSS si pulirà automaticamente ogni giorno.
