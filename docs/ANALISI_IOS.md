# Analisi Funzionalità - Versione iOS

**Data**: 16 Dicembre 2025
**Versione**: ZuperReader iOS (Swift/SwiftUI)
**Stato Generale**: ❌ Non Implementata

---

## Sommario Esecutivo

La versione iOS di ZuperReader è **completamente da implementare**. Esiste solo un documento di pianificazione (`IMPLEMENTATION_IOS.md`) che descrive le fasi di sviluppo, ma nessun codice Swift è stato scritto. Questo rappresenta un **gap critico** considerando che gran parte degli utenti target utilizza dispositivi mobile.

---

## 1. Stato Attuale

### 1.1 Cosa Esiste
| Elemento | Stato |
|----------|-------|
| Documento di pianificazione | ✅ Presente |
| Struttura progetto Xcode | ❌ Mancante |
| Codice Swift | ❌ Mancante |
| UI SwiftUI | ❌ Mancante |
| Integrazione Supabase | ❌ Mancante |

### 1.2 File Presenti
```
/ios/
└── SuperReader/
    └── (vuoto)
```

---

## 2. Funzionalità da Implementare

### 2.1 FASE 1: Setup Progetto e Architettura Core

#### 📋 Struttura Progetto Xcode
**Descrizione**: Creare progetto Xcode con struttura MVC/MVVM.
**Priorità**: CRITICA
**Effort stimato**: 1-2 giorni
**Requisiti**:
- iOS 16.0+ come minimum deployment target
- SwiftUI come UI framework principale
- Struttura cartelle organizzata

**Struttura Suggerita**:
```
SuperReader/
├── App/
│   ├── SuperReaderApp.swift
│   └── AppDelegate.swift
├── Models/
│   ├── Article.swift
│   ├── User.swift
│   ├── Comment.swift
│   ├── Friendship.swift
│   └── ArticleShare.swift
├── Views/
│   ├── Authentication/
│   ├── Articles/
│   ├── Reader/
│   ├── Social/
│   ├── Profile/
│   └── Components/
├── ViewModels/
│   ├── AuthViewModel.swift
│   ├── ArticlesViewModel.swift
│   ├── ReaderViewModel.swift
│   ├── FriendsViewModel.swift
│   └── ProfileViewModel.swift
├── Services/
│   ├── SupabaseService.swift
│   ├── ArticleParserService.swift
│   └── NotificationService.swift
├── Utilities/
│   ├── Extensions/
│   └── Helpers/
└── Resources/
    ├── Assets.xcassets
    └── Localizable.strings
```

#### 📋 Integrazione Supabase Swift SDK
**Descrizione**: Configurare Supabase per autenticazione e database.
**Priorità**: CRITICA
**Effort stimato**: 2-3 giorni
**Requisiti**:
- Installazione via SPM: `supabase-swift`
- Configurazione client con API keys
- Type-safe queries con Codable models

**Codice Esempio**:
```swift
import Supabase

let supabase = SupabaseClient(
    supabaseURL: URL(string: "YOUR_SUPABASE_URL")!,
    supabaseKey: "YOUR_SUPABASE_ANON_KEY"
)
```

#### 📋 Design System
**Descrizione**: Creare sistema di design consistente con versione web.
**Priorità**: ALTA
**Effort stimato**: 2-3 giorni
**Requisiti**:
- Color palette (gradient purple-pink-blue)
- Typography scale
- Spacing system
- Component library base

**Colori da Implementare**:
```swift
extension Color {
    static let primaryGradient = LinearGradient(
        colors: [.purple, .pink, .blue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // 5 temi lettura
    static let lightTheme = ThemeColors(...)
    static let darkTheme = ThemeColors(...)
    static let oceanTheme = ThemeColors(...)
    static let forestTheme = ThemeColors(...)
    static let sunsetTheme = ThemeColors(...)
}
```

---

### 2.2 FASE 2: Autenticazione

#### 📋 Magic Link OTP Flow
**Descrizione**: Implementare autenticazione via email magic link.
**Priorità**: CRITICA
**Effort stimato**: 3-4 giorni
**Requisiti**:
- Input email con validazione
- Invio OTP via Supabase
- Verifica token
- Session management

**Screens Necessarie**:
1. `LoginView.swift` - Input email
2. `OTPVerificationView.swift` - Input codice (fallback manuale)
3. `AuthSuccessView.swift` - Conferma login

#### 📋 Deep Link Handling
**Descrizione**: Gestire magic links che aprono direttamente l'app.
**Priorità**: CRITICA
**Effort stimato**: 1-2 giorni
**Requisiti**:
- Custom URL scheme: `azreader://`
- Universal Links (opzionale)
- Parse token da URL
- Auto-verify e redirect

**Info.plist Configuration**:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>azreader</string>
        </array>
    </dict>
</array>
```

#### 📋 Session Management
**Descrizione**: Gestire persistenza sessione utente.
**Priorità**: ALTA
**Effort stimato**: 1-2 giorni
**Requisiti**:
- Token storage sicuro (Keychain)
- Auto-refresh token
- Logout con cleanup
- Handle session expiry

---

### 2.3 FASE 3: Gestione Articoli

#### 📋 Lista Articoli
**Descrizione**: Visualizzare lista articoli salvati dall'utente.
**Priorità**: CRITICA
**Effort stimato**: 3-4 giorni
**Requisiti**:
- Grid view e List view switchabili
- Lazy loading con pagination
- Pull-to-refresh
- Empty state design

**Screens Necessarie**:
- `ArticlesListView.swift`
- `ArticleCardView.swift` (grid)
- `ArticleRowView.swift` (list)

#### 📋 Aggiunta Articolo via URL
**Descrizione**: Permettere salvataggio articoli incollando URL.
**Priorità**: CRITICA
**Effort stimato**: 2-3 giorni
**Requisiti**:
- Modal con input URL
- Validazione URL
- Chiamata parser API (Netlify function)
- Feedback saving/success/error
- Share extension (opzionale ma molto utile)

#### 📋 Article Reader
**Descrizione**: Schermata lettura articolo con personalizzazione.
**Priorità**: CRITICA
**Effort stimato**: 4-5 giorni
**Requisiti**:
- Rendering contenuto HTML
- Toolbar azioni (back, favorite, share, settings)
- Progress indicator
- Auto-save reading progress

**Personalizzazioni Necessarie**:
| Opzione | Range/Valori |
|---------|--------------|
| Font Family | 7 opzioni (sans, serif, mono, roboto, lato, openSans, ubuntu) |
| Font Size | 12-50px |
| Color Theme | 5 temi (light, dark, ocean, forest, sunset) |
| Line Height | 4 opzioni (compact, normal, relaxed, loose) |
| Content Width | 3 opzioni (narrow, normal, wide) |

#### 📋 Ricerca e Filtri
**Descrizione**: Permettere ricerca e filtro articoli.
**Priorità**: ALTA
**Effort stimato**: 2-3 giorni
**Requisiti**:
- Search bar con debounce
- Filtri: status lettura, preferiti, tag, dominio
- Sort: data, titolo, tempo lettura
- Persist filtri in session

#### 📋 Gestione Tag
**Descrizione**: Aggiungere/rimuovere tag da articoli.
**Priorità**: MEDIA
**Effort stimato**: 2 giorni
**Requisiti**:
- Tag editor modal
- Suggerimenti automatici (port dal web)
- Colori per categoria
- Creazione nuovi tag

---

### 2.4 FASE 4: Funzionalità Social

#### 📋 Lista Amici
**Descrizione**: Visualizzare e gestire lista amici.
**Priorità**: ALTA
**Effort stimato**: 2-3 giorni
**Requisiti**:
- Lista amici con avatar e nome
- Rimozione amico con conferma
- Badge contatore amici

**Screens Necessarie**:
- `FriendsListView.swift`
- `FriendRowView.swift`

#### 📋 Ricerca Utenti
**Descrizione**: Cercare utenti per aggiungere come amici.
**Priorità**: ALTA
**Effort stimato**: 1-2 giorni
**Requisiti**:
- Search input
- Risultati real-time
- Pulsante "Invia richiesta"
- Stato amicizia visibile

#### 📋 Gestione Richieste Amicizia
**Descrizione**: Visualizzare e rispondere a richieste amicizia.
**Priorità**: ALTA
**Effort stimato**: 2 giorni
**Requisiti**:
- Tab richieste ricevute
- Tab richieste inviate
- Accept/Reject buttons
- Notifica nuove richieste

#### 📋 Condivisione Articoli (Interna)
**Descrizione**: Condividere articoli con amici.
**Priorità**: ALTA
**Effort stimato**: 2-3 giorni
**Requisiti**:
- Pulsante share in article detail
- Selezione amico destinatario
- Messaggio personalizzato opzionale
- Conferma invio

#### 📋 Inbox Articoli Condivisi
**Descrizione**: Visualizzare articoli ricevuti da amici.
**Priorità**: ALTA
**Effort stimato**: 2-3 giorni
**Requisiti**:
- Lista condivisioni con info sender
- Timestamp e messaggio
- Mark as read
- Delete condivisione
- Badge unread count

#### 📋 Commenti
**Descrizione**: Sistema commenti su articoli.
**Priorità**: MEDIA
**Effort stimato**: 3-4 giorni
**Requisiti**:
- Lista commenti sotto articolo
- Add comment form
- Edit/Delete propri commenti
- Avatar e nome autore
- Timestamp

#### 📋 Like
**Descrizione**: Sistema like su articoli.
**Priorità**: MEDIA
**Effort stimato**: 1-2 giorni
**Requisiti**:
- Pulsante like con toggle
- Counter likes
- Stato liked/not liked
- Operazione atomica (RPC)

---

### 2.5 FASE 5: Profilo Utente e Impostazioni

#### 📋 Pagina Profilo
**Descrizione**: Visualizzare e modificare profilo utente.
**Priorità**: ALTA
**Effort stimato**: 2-3 giorni
**Requisiti**:
- Display name (editabile)
- Bio (editabile)
- Avatar (display, eventualmente upload)
- Statistiche utente

**Statistiche da Mostrare**:
1. Articoli totali
2. Articoli letti
3. Articoli preferiti
4. Like ricevuti
5. Commenti ricevuti
6. Numero amici
7. Articoli condivisi
8. Articoli ricevuti

#### 📋 Preferenze Lettura
**Descrizione**: Impostazioni di personalizzazione lettura.
**Priorità**: ALTA
**Effort stimato**: 2 giorni
**Requisiti**:
- Settings screen dedicata
- Preview live delle modifiche
- Sync con database (come web)
- Persist in UserDefaults come fallback

#### 📋 Tema Applicazione
**Descrizione**: Selettore tema light/dark/system.
**Priorità**: MEDIA
**Effort stimato**: 1 giorno
**Requisiti**:
- Respect system setting default
- Override manuale
- Persist preference

---

### 2.6 FASE 6: Polish e Refinement

#### 📋 Animazioni e Transizioni
**Descrizione**: Smooth UX con animazioni appropriate.
**Priorità**: MEDIA
**Effort stimato**: 2-3 giorni
**Requisiti**:
- Transizioni navigazione
- Loading animations
- Feedback tattile (Haptic)
- Micro-interactions

#### 📋 Pull-to-Refresh
**Descrizione**: Aggiornamento contenuti con gesture.
**Priorità**: MEDIA
**Effort stimato**: 0.5 giorni
**Requisiti**:
- Su liste articoli
- Su lista amici
- Su inbox condivisioni

#### 📋 Loading States
**Descrizione**: Feedback visivo durante caricamento.
**Priorità**: ALTA
**Effort stimato**: 1-2 giorni
**Requisiti**:
- Skeleton loaders
- Spinner appropriati
- Progress indicators

#### 📋 Empty States
**Descrizione**: Design per stati vuoti.
**Priorità**: MEDIA
**Effort stimato**: 1 giorno
**Requisiti**:
- Nessun articolo salvato
- Nessun amico
- Nessuna condivisione
- CTA appropriate

#### 📋 Error Handling
**Descrizione**: Gestione errori user-friendly.
**Priorità**: ALTA
**Effort stimato**: 2 giorni
**Requisiti**:
- Alert per errori critici
- Inline errors per form
- Retry buttons
- Offline detection

---

## 3. Funzionalità Extra (Non presenti in Web)

Queste funzionalità sarebbero un valore aggiunto per iOS:

### 3.1 Share Extension
**Descrizione**: Salvare articoli direttamente da Safari/altre app.
**Priorità**: MOLTO ALTA
**Effort stimato**: 3-4 giorni
**Valore**: Game-changer per UX mobile

### 3.2 Widget iOS
**Descrizione**: Widget home screen con articoli da leggere.
**Priorità**: MEDIA
**Effort stimato**: 2-3 giorni
**Valore**: Engagement aumentato

### 3.3 Offline Reading
**Descrizione**: Scaricare articoli per lettura offline.
**Priorità**: ALTA
**Effort stimato**: 4-5 giorni
**Valore**: Essential per mobile use case

### 3.4 Push Notifications
**Descrizione**: Notifiche per nuove condivisioni, commenti, etc.
**Priorità**: ALTA
**Effort stimato**: 3-4 giorni
**Valore**: Engagement e retention

### 3.5 Siri Shortcuts
**Descrizione**: Integrazione con Siri per azioni rapide.
**Priorità**: BASSA
**Effort stimato**: 2 giorni
**Valore**: Power user feature

### 3.6 Dark Mode Automatico
**Descrizione**: Sync con impostazioni sistema iOS.
**Priorità**: MEDIA
**Effort stimato**: 0.5 giorni
**Valore**: Expected iOS behavior

### 3.7 Biometric Auth
**Descrizione**: Face ID / Touch ID per accesso rapido.
**Priorità**: MEDIA
**Effort stimato**: 1-2 giorni
**Valore**: Security + convenience

### 3.8 iPad Support
**Descrizione**: Layout ottimizzato per iPad.
**Priorità**: MEDIA
**Effort stimato**: 3-4 giorni
**Valore**: Market expansion

---

## 4. Dipendenze Tecniche

### 4.1 Swift Packages Necessari

| Package | Uso | URL |
|---------|-----|-----|
| Supabase Swift | Backend integration | github.com/supabase/supabase-swift |
| SDWebImageSwiftUI | Image loading/caching | github.com/SDWebImage/SDWebImageSwiftUI |
| SwiftSoup | HTML parsing | github.com/scinfu/SwiftSoup |
| KeychainAccess | Secure storage | github.com/kishikawakatsumi/KeychainAccess |

### 4.2 Configurazioni Necessarie

| Configurazione | File | Descrizione |
|----------------|------|-------------|
| URL Scheme | Info.plist | `azreader://` per deep links |
| App Transport Security | Info.plist | HTTPS requirements |
| Supabase Keys | Config.xcconfig | API keys (non in source control) |
| App Groups | Entitlements | Per share extension |

---

## 5. Roadmap Implementazione

### Sprint 1: Foundation (2 settimane)
- [ ] Setup progetto Xcode
- [ ] Integrazione Supabase
- [ ] Design system base
- [ ] Autenticazione completa
- [ ] Deep link handling

### Sprint 2: Core Features (2 settimane)
- [ ] Lista articoli (grid/list)
- [ ] Aggiunta articolo via URL
- [ ] Article reader base
- [ ] Preferenze lettura
- [ ] Search e filtri

### Sprint 3: Social (2 settimane)
- [ ] Sistema amici completo
- [ ] Condivisione articoli
- [ ] Inbox condivisioni
- [ ] Commenti
- [ ] Like

### Sprint 4: Profile & Polish (1 settimana)
- [ ] Pagina profilo
- [ ] Statistiche utente
- [ ] Loading states
- [ ] Empty states
- [ ] Error handling

### Sprint 5: Extra Features (2 settimane)
- [ ] Share Extension
- [ ] Push Notifications
- [ ] Offline reading base
- [ ] Widget iOS

### Sprint 6: Testing & Release (1 settimana)
- [ ] QA testing
- [ ] Performance optimization
- [ ] App Store preparation
- [ ] Beta release (TestFlight)

---

## 6. Rischi e Mitigazioni

| Rischio | Impatto | Mitigazione |
|---------|---------|-------------|
| Supabase Swift SDK limitazioni | Alto | Test early, alternative REST API |
| Deep link non funzionanti | Alto | Universal Links come backup |
| Performance HTML rendering | Medio | WKWebView con CSS custom |
| App Store rejection | Alto | Follow HIG, test guidelines |
| Sync offline complesso | Medio | MVP senza offline, aggiungere dopo |

---

## 7. Metriche di Successo

### MVP (Minimum Viable Product)
- [ ] Login funzionante
- [ ] Aggiunta articoli via URL
- [ ] Lettura articoli con personalizzazione
- [ ] Lista articoli con search
- [ ] Preferiti e stati lettura

### v1.0
- [ ] Tutte le features social (amici, condivisioni, commenti)
- [ ] Share Extension
- [ ] Push notifications
- [ ] Profilo completo

### v1.x
- [ ] Offline reading
- [ ] Widget
- [ ] iPad support
- [ ] Siri shortcuts

---

## 8. Confronto con Versione Web

| Feature | Web | iOS (Target) | Gap |
|---------|-----|--------------|-----|
| Autenticazione | ✅ | 📋 | Full implementation needed |
| Gestione Articoli | ✅ | 📋 | Full implementation needed |
| Reader Customization | ✅ 6 opzioni | 📋 | Parity target |
| Social Features | ✅ | 📋 | Full implementation needed |
| Offline | ❌ | 📋 | iOS should have it first |
| Notifications | ❌ | 📋 | iOS should have it first |
| Share Extension | N/A | 📋 | iOS unique advantage |
| Widget | N/A | 📋 | iOS unique advantage |

---

## 9. Conclusioni

### Stato Critico
La versione iOS è **completamente assente**. Considerando che:
- Il 50%+ degli utenti web probabilmente usa iOS
- L'esperienza mobile è fondamentale per app di reading
- Competitors (Pocket, Instapaper) hanno app iOS mature

L'implementazione iOS dovrebbe essere la **priorità assoluta**.

### Effort Totale Stimato
- **MVP**: 4-5 settimane developer iOS senior
- **v1.0 completa**: 8-10 settimane
- **v1.x con extras**: 12-14 settimane

### Raccomandazione
Iniziare immediatamente con Sprint 1 (Foundation) per avere un'app funzionante il prima possibile, poi iterare sulle features in ordine di priorità.

---

**Documento generato automaticamente**
**Ultimo aggiornamento**: 16 Dicembre 2025
