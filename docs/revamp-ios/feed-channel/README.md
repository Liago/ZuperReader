# Handoff: schermata canale feed (06b) — ZuperReader iOS

Un solo schermo: la lista articoli di un singolo canale RSS (es. 9to5Mac), raggiunta da **Feeds → tap su un feed**. Sostituisce la vista attuale con le quattro frecce di navigazione in testa.

## File

| File | Cosa contiene |
| --- | --- |
| `Feed Channel 06b.dc.html` | Il mockup, tema light e dark affiancati. Aprire nel browser. |
| `screenshots/feed-channel-light.png`, `…-dark.png` | Render 2× dello stesso schermo |
| `_ds/organic-…/styles.css` | Token del design system Organic (colori, ramp, type, spacing) |
| `_ds/organic-…/_ds_bundle.js`, `support.js` | Runtime necessari solo per aprire l'HTML |

L'HTML è un **riferimento di design**, non codice da portare. Ricrearlo in SwiftUI nella struttura esistente (`Core/Theme/Theme.swift`, `Components/`, `Views/`). I px CSS mappano 1:1 sui punti SwiftUI.

## Token usati

Light: page `#F5EAD8`, rail `#EFE2CA`, text `#201E1D`, muted text@58%, line text@12%, sink text@4.5%, accent `#C67139`, accent-200 `#F0CBA9`, accent-2 `#7A8A5E`, accent-2-200 `#D6DDC5`, accent-2-800 per il testo sui fill chiari.

Dark: page `#23201C`, rail `#1C1A17`, text `#F3EBDF`, muted 60%, line 14%, sink 5%, accent `#E2975F`, accent-2 `#A9BD8C`.

Type: **Caprasimo** per il nome del canale e le iniziali dell'avatar; **Figtree** per tutto il resto.

## Struttura, dall'alto

**Header (padding 22/20/0, altezza ~58pt)**
- Back circolare 36pt, fill `sink`, chevron stroke 2.75.
- Avatar del canale 40pt, radius 14, fill `accent-2-200`, iniziale in Caprasimo 17pt `accent-2-800`. Se il feed ha una favicon, usarla al posto dell'iniziale, stesso radius.
- Titolo Caprasimo 21pt (una riga, troncata) + sottotitolo Figtree 12.5pt muted: `{n} non letti · aggiornato {relative}`.
- Overflow "…" circolare 36pt, fill `sink` → menu: segna tutto come letto, apri sito, notifiche, rimuovi feed.

**Filtri (gap 7, margin-bottom 16)**
- Pill "Non letti" attiva: fill `text`, label `page` 13.5pt/700, punto 6pt `accent-2` a sinistra.
- Pill "Tutti" inattiva: bordo 1px `line`, 13.5pt/600.
- A destra "Tutto letto": pill `accent`, label `page` 13pt/700, check stroke 3.2 da 15pt. Azione distruttiva soft → richiede undo in toast.

**Articolo in evidenza (il più recente non letto)**
- Copertina 168pt d'altezza, radius 26, `aspectRatio .fill`, clip. Placeholder: fill `accent-200` con icona immagine `accent-800` @50%.
- Riga meta: punto 6pt `accent-2` (non letto), data 12pt/700 uppercase letter-spacing .06em muted, tempo di lettura allineato a destra.
- Titolo 19pt/800, line-height 1.28, tracking −0.01em, max 3 righe.
- Snippet 13.5pt muted, 2 righe, clip.

**Righe lista (gap 14, padding-bottom 16, separatore 1px `line` rientrato di 92pt)**
- Miniatura 78×78pt, **radius 22** (il punto della richiesta: angoli più morbidi), stessa treatment placeholder.
- Riga meta 12pt muted: punto stato a sinistra, tempo di lettura a destra.
- Titolo 15.5pt/700, line-height 1.35, max 2 righe.
- Sotto il titolo, **una** delle due:
  - snippet 13.5pt muted su una riga troncata (articolo non iniziato), oppure
  - barra di avanzamento 2pt radius 999, track `line`, fill `accent` (articolo in corso).
- Articolo letto: niente punto ma un check 13pt muted, titolo in muted, nessuno snippet.

**Tab bar**: la stessa degli altri schermi, Feeds selezionata. Riservare 84pt + home indicator in fondo allo scroll (`contentInset`), altrimenti l'ultima riga finisce sotto la barra.

## Comportamenti

- Pull-to-refresh sul canale; lo spinner usa `accent`.
- Swipe da sinistra: segna letto/non letto. Swipe da destra: salva in Library, archivia.
- Tap riga → Reader. Long-press → anteprima con azioni.
- Il filtro Non letti/Tutti persiste per feed.
- Scroll: l'header si contrae a una nav bar con solo avatar 24pt + nome 17pt; i filtri restano appiccicati in cima.
- Lista vuota con filtro Non letti: testo centrato "Tutto letto" + link "Mostra tutti gli articoli", nessuna illustrazione.
- Il conteggio non letti nel sottotitolo si aggiorna dal vivo mentre si scorre se `markAsReadOnScroll` è attivo.

## Note

- Le miniature sono rappresentate da blocchi tinti: nel prodotto sono le immagini degli articoli, `scaledToFill` + clip sul radius, nessun bordo.
- Se il feed non ha immagini, la riga collassa a testo pieno larghezza (nessun placeholder vuoto ripetuto).
