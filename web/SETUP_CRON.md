# Setup Cron Job Vercel - Guida Rapida

L'app è già su Vercel. Serve solo configurare il cron job per il cleanup automatico RSS.

## 🚀 Setup in 3 Passi

### 1️⃣ Genera il Secret

Sul tuo computer:

```bash
openssl rand -base64 32
```

**Copia l'output** (esempio: `X8k2Jd9Lp3Qr5Ts7Uv8Wx9Yz0Ab1Cd2Ef3Gh4Ij5Kl6=`)

### 2️⃣ Aggiungi su Vercel

1. Vai su https://vercel.com/dashboard
2. Seleziona progetto **ZuperReader**
3. **Settings** → **Environment Variables**
4. **Add New**:
   - **Key**: `CRON_SECRET`
   - **Value**: (incolla il token)
   - **Environments**: Solo **Production** ✓
5. **Save**

### 3️⃣ Deploy

Fai merge del branch `claude/feed-read-tracking-G03Xq` su main:

```bash
git checkout main
git merge claude/feed-read-tracking-G03Xq
git push
```

Oppure crea una Pull Request su GitHub e mergia.

Vercel farà il deploy automaticamente.

---

## ✅ Verifica (dopo 2-3 minuti dal deploy)

### Controllo Dashboard

1. Vercel Dashboard → **ZuperReader** → **Cron Jobs** (tab)
2. Dovresti vedere:
   ```
   Path: /api/cleanup-rss
   Schedule: 0 2 * * * (Daily at 2:00 AM UTC)
   Status: ✓ Active
   ```

### Test Manuale

Click **"Run"** nella dashboard per testare subito (senza aspettare le 2 AM).

Oppure via curl:

```bash
curl https://tua-app.vercel.app/api/cleanup-rss \
  -H "Authorization: Bearer IL_TUO_CRON_SECRET"
```

**Risposta attesa:**

```json
{
  "success": true,
  "processedUsers": 5,
  "totalDeleted": 142,
  "results": [...]
}
```

### Controlla i Logs

Dashboard → **Deployments** → Latest → **Functions**

Cerca nei logs:
```
RSS Cleanup completed: X users processed, Y articles deleted
```

---

## ⏰ Funzionamento

- **Quando**: Ogni giorno alle **2:00 AM UTC** (automatico)
- **Cosa fa**:
  - ❌ Cancella articoli **letti** > 30 giorni
  - ❌ Cancella articoli **non letti** > 90 giorni
  - ✂️ Mantiene max **200 articoli** per feed
- **Risultato**: Database pulito, storage stabile

---

## 🔧 Troubleshooting

### "Cron job non appare"

- Aspetta 2-3 minuti dopo il deploy
- Verifica che il deploy sia su **Production** (non Preview)
- Ricarica la pagina della dashboard

### "Errore 401 Unauthorized"

- Verifica che `CRON_SECRET` sia configurato correttamente
- Rigenera il secret e aggiornalo su Vercel
- Fai un nuovo deploy

### "Timeout"

Se hai tantissimi utenti (100+), potrebbe servire più tempo.
- **Hobby plan**: max 10 secondi
- **Pro plan**: max 60 secondi

Soluzione: contattami per ottimizzare il batch processing.

---

## 📊 Modificare la Configurazione

### Cambiare orario

Modifica `web/vercel.json`:

```json
{
  "crons": [{
    "path": "/api/cleanup-rss",
    "schedule": "0 3 * * *"  // 3 AM invece di 2 AM
  }]
}
```

Poi `git push`.

### Cambiare retention

Modifica `web/src/lib/rssCleanup.ts`:

```typescript
export const CLEANUP_CONFIG = {
    READ_RETENTION_DAYS: 60,      // 60 giorni invece di 30
    UNREAD_RETENTION_DAYS: 180,   // 6 mesi invece di 90 giorni
    MAX_ARTICLES_PER_FEED: 500    // 500 articoli invece di 200
};
```

Poi `git push`.

---

**✅ Fine!** Il cleanup girerà automaticamente ogni notte.

## 📚 Documentazione Completa

Per configurazioni avanzate, monitoring, e alternative:
- `VERCEL_CRON_SETUP.md` - Setup dettagliato
- `RSS_CLEANUP_GUIDE.md` - Strategia e best practices
