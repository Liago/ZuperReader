# Fix per le Richieste di Amicizia

## Problema Identificato

Le richieste di amicizia non venivano visualizzate a causa di un'incompatibilità tra le foreign key del database e le query API.

### Dettagli Tecnici

- **Foreign Key Originali**: La tabella `friendships` aveva foreign key che puntavano a `auth.users(id)`
- **Query API**: Le query Supabase tentavano di fare join con `user_profiles` usando i nomi delle foreign key constraint
- **Risultato**: Le query fallivano silenziosamente e non restituivano dati

## Soluzione Applicata

Ho modificato le foreign key della tabella `friendships` per puntare a `user_profiles(id)` invece di `auth.users(id)`.

## Come Applicare la Fix

### Opzione 1: Via Supabase Dashboard (Consigliato)

1. Accedi al tuo progetto Supabase
2. Vai alla sezione **SQL Editor**
3. Copia il contenuto del file `fix-friendships-fk.sql`
4. Incolla ed esegui la query
5. Verifica che non ci siano errori

### Opzione 2: Via CLI

```bash
# Assicurati di avere Supabase CLI installato e configurato
supabase db push --file fix-friendships-fk.sql
```

## Modifiche ai File

1. **fix-friendships-fk.sql** (nuovo): Migration per correggere il database esistente
2. **supabase-migrations.sql** (modificato): Aggiornato per prevenire il problema in future installazioni

## Test della Fix

Dopo aver applicato la migration:

1. Vai alla pagina `/friends` dell'app
2. Cerca un utente nella tab "Cerca utenti"
3. Invia una richiesta di amicizia
4. L'utente destinatario dovrebbe vedere la richiesta nella tab "Richieste" > "Ricevute"
5. L'utente mittente dovrebbe vedere la richiesta nella tab "Richieste" > "Inviate"

## Funzionalità Ripristinate

✅ Invio richieste di amicizia
✅ Visualizzazione richieste ricevute
✅ Visualizzazione richieste inviate
✅ Accettazione/Rifiuto richieste
✅ Visualizzazione lista amici
✅ Condivisione articoli con amici

## Note Importanti

- La fix è **retrocompatibile** e non influisce sui dati esistenti
- Tutti i dati delle richieste di amicizia esistenti rimangono intatti
- Le policy RLS rimangono invariate
- Non è necessario riavviare l'applicazione dopo aver applicato la fix
