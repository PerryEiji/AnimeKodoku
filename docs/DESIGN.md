# Applicazione del design Aidoku ad AnimeKodoku

Il documento allegato distingue dati verificati [V], ricostruzioni [R] e proposte [P]. Non viene promessa una replica pixel-perfect dell'app originale. Le sezioni 3, 4, 8 e 14 guidano questa implementazione.

## Token (sezione 3)

| Token | Implementazione |
|---|---|
| surface.base dark | Nero, #000000; player sempre nero |
| surface.secondary dark | #1C1C1E per artwork placeholder/superfici |
| text.primary / secondary | Semantic SwiftUI primary/secondary, adattivi |
| accent.primary | Viola video-premium RGB 0.60 / 0.52 / 1.0 |
| semantic.error / success | Rosso e verde di sistema, accompagnati da testo/icona |
| Font | SF di sistema; largeTitle, title2, headline, body, caption |
| Spaziatura | Multipli di 4: 8, 12, 16, 20, 24, 32 pt |
| Cover | 2:3 in libreria, raggio 12; griglia adattiva 140–220 pt |
| Touch target | Minimo 44×44 per pulsanti icona; label leggibili con Dynamic Type |

La palette premium modifica l'accent suggerito dal brief, mantenendo superfici neutre e componenti di sistema. La modalità chiara è opzionale per shell e liste; il player resta scuro.

## Libreria (sezione 4)

Griglia predefinita, lista opzionale, intersezione di stato/fonte/tag persistita con ID stabili, chip gruppi salvati e indicazione filtri attivi. Multi-select usa checkmark oltre al colore; rimozione con conferma. Ricerca locale per titolo. Empty state diverso per libreria vuota e filtri senza risultati. Il refresh remoto avviene al dettaglio: nessun comando “aggiorna tutta la libreria” fittizio.

## Lettore video (sezione 8)

Il contenuto conserva il rapporto originale (`resizeAspect`); pinch o menu attivano il riempimento con possibile crop. Overlay con titolo in alto, comandi centrali e timeline in basso, nascosto dopo 4 secondi di riproduzione. VoiceOver mantiene i controlli disponibili. Reduce Motion disattiva le transizioni decorative. Sottotitoli con sfondo semitrasparente e posizione rialzata quando i controlli sono visibili. Gli swipe hanno pulsanti equivalenti accessibili.

## Architettura e stati (sezione 14)

Shell e componenti, feature autonome, domain value types, adattatori, persistenza e player separati in cartelle. REST costituisce il runtime funzionante; WASM/JS sono estensioni future. Le pagine mantengono parametri e ordine; deduplica e fine risultati esplicita. Ogni fonte può fallire indipendentemente nella ricerca globale. I download locali vengono risolti prima degli URL di rete, anche se la fonte è disabilitata.

## Accessibilità e adattamento

Uso di semantic fonts, focus nativo e NavigationStack; lista e griglie responsive, toolbar native, import/export file di sistema. Player Mac con barra spaziatrice per play/pausa. Nessuna affermazione di audit VoiceOver, contrasto o rotazione su dispositivo già superato: la matrice in VALIDATION.md va completata su Apple hardware.
