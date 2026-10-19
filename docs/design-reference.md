# Aidoku — Design & Product Specification

> **Documento di riferimento per l'analisi e la riproduzione progettuale dell'esperienza Aidoku**  
> Progetto originale: https://github.com/Aidoku/Aidoku  
> Sito: https://aidoku.app/  
> Ultima verifica delle fonti pubbliche: **19 ottobre 2026**  
> Lingua del documento: italiano  
> Stato: **specifica ricostruttiva, non documento ufficiale di Aidoku**.

## 0. Ambito, affidabilità e modalità d'uso

Questo `design.md` descrive il prodotto Aidoku nel suo complesso: modello di navigazione, schermate, componenti, design visivo, lettura, fonti, download, tracciamento, accessibilità e requisiti funzionali. È concepito come **brief operativo per designer e sviluppatori** interessati a comprendere o ricreare un'esperienza comparabile.

**Base documentale verificata:** repository e README ufficiali, sito ufficiale Aidoku, note delle release ufficiali fino alla linea 0.9, guida introduttiva ufficiale. **Limite importante:** non è stato possibile clonare il repository né eseguire l'app in questa sessione. Pertanto **non** sono stati verificati individualmente tutti i file Swift, le gerarchie UIKit/SwiftUI, le misure in punti, i token cromatici, le schermate effettive e i comportamenti di ogni build. Non attribuire ad Aidoku come fatto certo le proposte di dettaglio identificate come *specifica suggerita*.

### Legenda di evidenza

- **[V] Verificato:** funzione esplicitamente documentata in fonti ufficiali.
- **[R] Ricostruzione:** conseguenza UX ragionevole della funzionalità, da verificare nell'app eseguita.
- **[P] Proposta:** decisione o specifica progettuale consigliata per implementare un'esperienza ispirata ad Aidoku; non affermazione sulla UI reale.

### Obiettivo d'uso

Un agente di sviluppo può usare questo documento per pianificare schermate, stati, componenti e test. Per dichiarare una replica pixel-perfect occorrono screenshot di riferimento e un audit della build su iPhone/iPad; questo documento **non** costituisce tale verifica.

---

## 1. Identità e principi di prodotto

### 1.1 Che cos'è Aidoku [V]

Aidoku è un lettore gratuito e open source di manga e altri fumetti per **iOS, iPadOS e macOS**, senza pubblicità, che combina contenuti da fonti esterne, file locali e server multimediali.

Capacità dichiarate nel repository ufficiale:

- Lettura di archivi locali **CBZ**.
- Provider integrati **Komga, Kavita e Suwayomi**.
- Motore di fonti esterne basato su **WASM**.
- Download per la lettura offline.
- Integrazioni di tracking, tra cui **AniList** e **MyAnimeList**.
- Ricerca di termini tramite **OCR/dizionari**.
- Disponibilità della piattaforma Apple anche per macOS.

### 1.2 Intento progettuale [R]

L'app deve far percepire i contenuti come un'unica biblioteca, pur mantenendo distinte le loro origini. La schermata di lettura deve dare massima priorità all'immagine, minimizzare l'interferenza dei controlli e conservare il contesto di avanzamento. Le attività ricorrenti (riprendere, cercare, scaricare, aggiornare) devono essere rapide e prevedibili.

### 1.3 Principi UX per una replica ispirata [P]

1. **Content first:** copertine e pagine al centro, chrome leggero.
2. **Native first:** gerarchie, transizioni e controlli coerenti con iOS/iPadOS/macOS.
3. **Local first per lo stato personale:** libreria, download, avanzamento e preferenze persistenti.
4. **Fonti esplicite:** provenienza, errori, compatibilità e configurazione chiari.
5. **Progressive disclosure:** preferenze avanzate disponibili senza sovraccaricare le schermate principali.
6. **Resilienza:** loading, ritardi, timeout, dati parziali e contenuti offline gestiti come stati normali.

---

## 2. Mappa dell'esperienza e navigazione

### 2.1 Domini funzionali [V]

| Dominio | Scopo | Capacità accertate |
|---|---|---|
| Libreria | Organizzare le opere seguite | Griglia/lista, filtri persistenti, selezione multipla, gruppi di filtri |
| Ricerca | Trovare opere | Scheda ricerca rinnovata, filtri, cronologia di ricerca |
| Fonti / Esplora | Sfogliare cataloghi | Fonti WASM, liste di fonti, ricerche salvate con filtri, fonti disattivabili |
| Opera | Vedere informazioni e capitoli | Dettagli e capitoli; migrazione tra fonti con confronto dei dettagli |
| Lettore | Leggere pagine e testo | Modalità pagina/doppia pagina/scroll/webtoon, controlli avanzati, Live Text/OCR |
| Download | Usare contenuti offline | Download, compressione, esportazione capitoli CBZ, background su iOS supportato |
| Statistiche | Comprendere le abitudini | Insights, tempo di lettura e conteggio capitoli |
| Tracker | Sincronizzare gli elenchi esterni | AniList, MAL e altri tracker documentati nelle release |
| Impostazioni | Personalizzare app e lettura | Ricerca nelle impostazioni, opzioni di lettura, backup |

### 2.2 Architettura informativa suggerita [P]

```text
App
├── Libreria
│   ├── Vista griglia / elenco
│   ├── Filtri, ordinamento, gruppi salvati
│   ├── Operazioni multiple
│   └── Dettaglio opera ──> Capitoli ──> Lettore
├── Ricerca
│   ├── Query, suggerimenti/cronologia
│   ├── Filtri di ricerca
│   └── Risultati ──> Dettaglio opera
├── Esplora / Fonti
│   ├── Fonti installate e cataloghi
│   ├── Liste e configurazione fonti
│   ├── Ricerca e filtri per singola fonte
│   └── Dettaglio opera
├── Download
│   ├── In corso / completati / errori
│   └── Archivio offline
└── Impostazioni
    ├── Lettore / aspetto
    ├── Fonti / server
    ├── Tracker
    ├── Backup / ripristino
    ├── Insights e cronologia
    └── Informazioni
```

**Nota:** i domini indicati sono reali, ma questa specifica disposizione delle tab e delle sottopagine è **proposta**, non un'estrazione verificata del navigation tree Swift.

### 2.3 Pattern di navigazione [P]

- **iPhone:** tab bar inferiore per i domini primari; stack di navigazione all'interno di ogni tab.
- **iPad:** contenuti principali ampliati, griglie responsive, eventuale sidebar quando la gerarchia lo giustifica.
- **macOS:** adattare i controlli a toolbar, menu e interazioni pointer/keyboard.
- Apertura del lettore come vista immersiva, con ritorno che conserva opera, capitolo, filtri e posizione di scroll.
- Sheet per azioni contestuali brevi; schermate complete per configurazioni complesse e stato dei download.

---

## 3. Design system

> **Tutti i valori numerici e cromatici di questa sezione sono token suggeriti [P], non valori estratti da Aidoku.**

### 3.1 Linguaggio visivo [R/P]

Interfaccia sobria, nativa, orientata alle copertine e alle tavole. Superfici prevalentemente neutre, sfondi adattivi light/dark, contenitori poco invadenti. Preferire componenti di sistema, tipografia SF e simboli SF Symbols, in modo che l'interfaccia sembri coerente con l'ecosistema Apple.

### 3.2 Token suggeriti [P]

| Categoria | Token | Light | Dark |
|---|---|---|---|
| Background | `surface.base` | `#FFFFFF` | `#000000` |
| Background secondario | `surface.secondary` | `#F2F2F7` | `#1C1C1E` |
| Testo primario | `text.primary` | `#111113` | `#F5F5F7` |
| Testo secondario | `text.secondary` | `#6E6E73` | `#98989D` |
| Separatore | `border.subtle` | `#D1D1D6` | `#38383A` |
| Accent | `accent.primary` | Tinta di sistema | Tinta di sistema |
| Errore | `semantic.error` | Rosso di sistema | Rosso di sistema |
| Conferma | `semantic.success` | Verde di sistema | Verde di sistema |

Non fissare una palette “ufficiale Aidoku” senza estrazione dagli asset del progetto e confronto con schermate reali.

### 3.3 Tipografia [P]

- Font di sistema iOS con Dynamic Type.
- Titolo della schermata: large title nativo dove appropriato.
- Titolo opera: headline, massimo 2–3 righe in griglia.
- Metadata (fonte, ultimo capitolo, progresso): subheadline/caption.
- Liste e impostazioni: gerarchia tipografica nativa, non microtesti fissi.
- Evitare che i titoli lunghi deformino cards, tab o bottom sheets.

### 3.4 Spaziature e layout [P]

Sistema di base da 4 pt: 4, 8, 12, 16, 20, 24, 32. Margini laterali adattivi: ~16 pt su iPhone, maggiori su iPad. Touch target non inferiori a 44×44 pt. Grid card proporzionale alla copertina, con aspect ratio corretto e immagini `aspectFill` soltanto sulle anteprime, mai sulle pagine del lettore.

### 3.5 Componenti riutilizzabili [P]

- `MangaCoverCard`: immagine, titolo, badge opzionali, overlay progresso.
- `MangaListRow`: thumbnail, titolo, capitolo/aggiornamento, stato.
- `SourceIdentity`: icona, nome fonte, lingua, indicatori disponibilità.
- `ChapterRow`: numero/titolo, data, scanlator, letto/non letto, download.
- `FilterChip` / `FilterPanel` / `SortMenu` / `SavedFilterGroup`.
- `ProgressIndicator`: progresso lettura, refresh e download con valori distinti.
- `EmptyState`: simbolo, testo conciso, azione primaria.
- `ErrorState`: motivo, dettagli tecnici opzionali, riprova.
- `ReaderChrome`: overlay temporaneo per navigazione e opzioni.
- `DownloadTaskRow`: stato, avanzamento, annulla/riprova.
- `ConfirmationDialog`: per rimozioni, reset, modifiche distruttive.
- `SettingsRow`: icona opzionale, etichetta, valore, navigazione.

### 3.6 Iconografia e animazione [P]

SF Symbols ove possibile, uso coerente di simboli fill/non-fill. Animazioni rapide, motivate dal cambiamento di stato. Preservare **Reduce Motion**. Transizioni di ingresso/uscita del lettore fluide: la release v0.8 documenta transizioni aggiornate in stile iOS 26 [V], non una specifica curva di easing.

---

## 4. Schermata Libreria

### 4.1 Scopo

Punto di accesso alla collezione personale e alle opere in corso [R].

### 4.2 Elementi [V/R]

- Possibilità di **visualizzazione griglia e lista** [V, v0.8].
- **Filtri persistenti** e ulteriori opzioni di filtro [V, v0.8].
- **Multi-select** migliorata [V, v0.8].
- **Gruppi di filtri salvati** utili a categorizzare le opere [V, v0.8.2].
- Refresh della libreria con indicatore di progresso migliorato [V, v0.7.2].
- Indicatori di capitoli non letti e download disponibili [V, v0.7.3].

### 4.3 Comportamenti dettagliati consigliati [P]

1. Aprendo la scheda viene ripristinata l'ultima modalità griglia/lista, il filtro, l'ordinamento e possibilmente la posizione di scroll.
2. Filtro attivo chiaramente visibile; un solo comando per ripristinare i valori.
3. L'interfaccia rimane responsiva durante refresh e aggiornamenti incrementali.
4. Tap sulla cover → dettaglio opera; pressione prolungata → menu rapido.
5. Selezione multipla con toolbar contestuale; nessuna azione distruttiva senza conferma.
6. Nello stato offline si mostra la cache senza simulare disponibilità di rete.

### 4.4 Stati da progettare [P]

Libreria vuota; caricamento iniziale; copertina non disponibile; ricerca senza risultati; filtro senza risultati; aggiornamento in corso; errore parziale di una fonte; fonte non più disponibile; elementi selezionati; modalità lista; modalità griglia.

---

## 5. Ricerca globale e ricerca nelle fonti

### 5.1 Funzioni verificate

- Ricerca con interfaccia ridisegnata, **filtri** e **cronologia di ricerca** [V, v0.7.3].
- Ricerca specifica nelle fonti e possibilità di **salvare testo e configurazioni filtro** [V, v0.8.2].

### 5.2 Specifica di interazione [P]

- Campo di ricerca prioritario, con cancellazione esplicita e feedback in caricamento.
- Cronologia persistente, eliminazione singola e complessiva.
- Risultati presentati per copertina, titolo e fonte; nessuna fusione silenziosa di opere omonime.
- Gestione di filtri forniti dalla fonte: i tipi di filtro e le loro opzioni **non** devono essere codificati in modo fisso a livello app.
- Il reset deve preservare i default dichiarati dalla singola fonte.
- In caso di più fonti: indicare quali sono state effettivamente interrogate, quali hanno fallito e quali non supportano il filtro.
- La paginazione deve esporre lo stato `hasNextPage`; caricamento append-only senza duplicare o sostituire la prima pagina.

### 5.3 Contratto raccomandato per i filtri [P]

```text
SourceFilter {
  sourceId
  stableKey
  displayName
  kind: select | multiSelect | text | toggle | range | sort
  defaultValue
  selectedValue
  options[]
}
```

**Regola critica:** persistenza per identificatori **stabili** e scope della fonte, non unicamente per l'etichetta tradotta. `Order by`, filtri e paginazione devono essere applicati al provider e non solamente all'interfaccia; dopo la selezione, ripartire da pagina 1 mantenendo tutte le altre scelte.

---

## 6. Esplora, cataloghi e gestione delle fonti

### 6.1 Funzioni documentate [V]

- Integrazione di fonti esterne tramite runtime WASM.
- Provider integrati per server personali: Komga, Kavita e Suwayomi.
- Fonti disattivabili in presenza di instabilità [v0.9].
- Indicatore per liste di fonti non più presenti e quindi non aggiornate [v0.8.2].
- Miglioramenti di compatibilità e gestione Cloudflare [v0.9].

### 6.2 UX consigliata [P]

- Dividere visivamente **fonti installate**, **liste di fonti**, **server collegati**.
- Ogni fonte espone nome, icona, lingua, versione/stato quando disponibili.
- Azioni contestuali: apri, configura, aggiorna, disattiva, rimuovi.
- Distinguere errori di rete, autenticazione, sorgente obsoleta, challenge antibot, parsing e contenuto mancante.
- Mostrare chiaramente che i cataloghi sono forniti da soggetti esterni.
- Non promettere compatibilità permanente: la disponibilità dipende dai provider.

### 6.3 Privacy e sicurezza [P]

Per server personali conservare segreti in Keychain; non stampare credenziali in log o backup in chiaro. Per motori WASM minimizzare le autorizzazioni, sanificare metadata e URL e definire timeout, limiti di risorse e gestione errori.

---

## 7. Dettaglio opera

### 7.1 Obiettivo [R]

Collegare esplorazione, informazioni editoriali, stato personale, capitoli e accesso rapido al lettore.

### 7.2 Anatomia suggerita [P]

1. **Hero:** copertina, titolo principale, eventuali nomi alternativi, autore, fonte.
2. **Azioni primarie:** leggi/riprendi, aggiungi/rimuovi libreria, download ove supportato.
3. **Metadata:** descrizione, generi/tag, stato editoriale, aggiornamento.
4. **Capitoli:** ordinamento, progressi per capitolo, lingua/scanlator se esposti.
5. **Integrazioni:** tracker e migrazione fonte quando pertinenti.

### 7.3 Comportamenti verificati e indicativi

- Un nuovo flusso di **migrazione delle opere tra fonti** mostra dettagli e permette di scegliere se copiare dati [V, v0.8.3].
- Esiste un concetto di **preferenza dello scanlator** per i capitoli successivi [V, v0.8.2].
- Le azioni specifiche e l'esatta collocazione visiva restano da verificare sull'app eseguita.

### 7.4 Stati [P]

Opera con capitoli, opera senza capitoli, informazioni incomplete, link fonte scaduto, più traduzioni, capitoli già letti, download in corso, contenuto già in libreria, migrazione in preparazione.

---

## 8. Lettore: centro dell'esperienza

### 8.1 Requisiti di lettura verificati [V]

- Modalità adatte a pagine singole, doppie e webtoon/scroll verticale.
- Modalità continua **con spazi tra pagine** [v0.8.3].
- Isolamento automatico delle pagine larghe in doppia pagina e suddivisione di pagine larghe in modalità singola [v0.7.2].
- Offset e miglioramenti della doppia pagina [v0.8.3].
- Possibilità di nascondere le barre al cambio pagina [v0.8.2].
- Background automatico derivato dal colore della pagina [v0.8].
- **Live Text** di Apple per testo nelle immagini [v0.8].
- **OCR con dizionari compatibili Yomitan**, su iOS 18+ [v0.9].
- **Auto-scroll** nella modalità webtoon [v0.9].
- Indicatore **incognito** quando la lettura non viene tracciata [v0.8].
- Lettore di capitoli solo testo sperimentale, con paginazione e font configurabile [v0.8.2].

### 8.2 Layout immersivo [P]

La pagina occupa il viewport disponibile; le barre e le impostazioni diventano temporanee durante la lettura. Inserire navigazione in alto (titolo/capitolo, indietro) e controlli contestuali in basso (progresso, selezione capitolo, opzioni); nasconderli quando l'utente si concentra sul contenuto. **Non sovrapporre elementi permanenti** a vignette, dialoghi e immagini.

### 8.3 Modalità e opzioni [P]

| Modalità | Direzione/interazione | Casi d'uso |
|---|---|---|
| Pagina singola | Avanzamento discreto | Manga tradizionale |
| Doppia pagina | Due pagine affiancate | iPad e panoramico |
| Continuo | Scorrimento verticale | Lettura fluida |
| Continuo con spazi | Scorrimento e separatori | Tavole separate |
| Webtoon | Striscia lunga verticale | Manhwa/webtoon |
| Testo sperimentale | Pagine e font configurabili | Capitoli testuali |

Prevedere impostazioni per direzione RTL/LTR, adattamento contenuto, luminosità/sfondo, comportamento barre, zoom, gestione pagine ampie; **la presenza di ogni singola opzione non è stata verificata**.

### 8.4 Macchina a stati suggerita [P]

```text
idle
  -> loadingChapter
  -> renderingPage
  -> reading
       -> changingPage -> reading
       -> showingControls -> reading
       -> changingChapter -> loadingChapter
       -> dictionaryLookup -> reading
       -> error -> retry | offlineFallback
  -> exited (persist progress)
```

Preservare il progresso per capitolo e pagina, ma evitare salvataggi superflui a ogni frame di scroll. Precaricare con limiti di memoria espliciti; la release 0.9-4 indica che il webtoon reader ha richiesto ottimizzazioni di memoria e caricamento pagine [V].

### 8.5 Gestualità e accessibilità [P]

Tap per mostrare/nascondere controlli, swipe per avanzamento, pinch per zoom dove appropriato, long press per azioni disponibili. Evitare conflitti fra selezione OCR, zoom e navigazione. VoiceOver deve leggere gli elementi dell'interfaccia; le immagini non sono automaticamente convertite in testo accessibile. Rispettare Reduce Motion e dimensioni schermo/rotazione.

---

## 9. Download e lettura offline

### 9.1 Funzioni verificate [V]

- Download dei capitoli.
- Download in background **su iOS 26+** dalla release v0.7.3.
- Compressione download con miglioramenti a velocità e spazio.
- **Export dei capitoli scaricati in CBZ**.
- Badge con conteggi dei capitoli scaricati.
- Import/lettura di file CBZ locali; supporto a metadata `ComicInfo.xml` nelle release più recenti.

### 9.2 Specifica suggerita [P]

La gestione dei download dovrebbe mostrare queue, attività, errori, progressi, spazio occupato e comandi di annullamento/riprova. File parziali non devono apparire come completati. Fornire opzioni per download su rete cellulare/Wi-Fi, conservazione dei capitoli e pulizia della cache ove implementabili.

### 9.3 Resilienza [P]

Una fonte che sparisce non deve cancellare automaticamente il contenuto già scaricato. I capitoli locali devono restare identificabili attraverso ID stabili. Gestire download ripresi, duplicati, interruzioni e spazio insufficiente. Esplicitare le limitazioni imposte da iOS ai task background.

---

## 10. Tracker, cronologia e Insights

### 10.1 Verificato [V]

- Integrazione con tracker come AniList e MyAnimeList.
- Tracker Komga e Kavita; tracker MangaBaka introdotto in v0.8.2.
- Insights sul tempo trascorso a leggere dalla release v0.8.
- Miglioramenti nel conteggio capitoli delle statistiche nelle patch successive.
- Modalità incognito con indicatore visibile e disattivazione del tracking della cronologia.

### 10.2 Comportamenti suggeriti [P]

- Collegamento account con autorizzazioni chiare e possibilità di disconnessione.
- Distingue progresso locale, progresso remoto e eventuali conflitti.
- Sync ritentabile; nessun avanzamento inventato se l'operazione remota non riesce.
- Insights con periodi, tempo di lettura e capitoli completati; informare che i dati antecedenti all'introduzione del tracking temporale potrebbero non esistere.
- Modalità incognito: indicazione persistente, nessuna raccolta della cronologia associata durante la sessione.

---

## 11. Impostazioni, backup e personalizzazione

### 11.1 Verificato [V]

- Impostazioni con organizzazione migliorata e **ricerca** dalla release v0.7.2.
- Backup automatici periodici in background dalla v0.7.3.
- Opzioni di lettura globali e specifiche della fonte secondo il sito ufficiale.
- Esportazione locale in CBZ per capitoli scaricati.

### 11.2 Tassonomia suggerita [P]

| Gruppo | Possibili opzioni |
|---|---|
| Aspetto | Tema, uso della tinta di sistema, densità |
| Lettore | Modalità predefinita, doppia pagina, sfondo, barre, direzione |
| Libreria | Vista predefinita, ordinamento, filtri/gruppi |
| Download | Qualità/compressione, gestione spazio, attività |
| Fonti | Installate, liste, server, aggiornamenti |
| Tracker | Account collegati, sync, errori |
| Dati | Backup, ripristino, esportazioni |
| Privacy | Cronologia, incognito, cache |
| Informazioni | Versione, licenze, aiuto, segnalazioni |

La disponibilità concreta delle voci va verificata nella build di riferimento prima di attribuirle ad Aidoku.

---

## 12. Stati trasversali e feedback

| Stato | Pattern UX consigliato [P] |
|---|---|
| Loading breve | Indicatore discreto e placeholder che conserva il layout |
| Loading lungo | Progress visibile, eventuale annullamento |
| Empty | Spiegazione specifica + azione utile |
| Rete assente | Contenuto in cache/offline e banner non invasivo |
| Fonte disabilitata | Indicatore leggibile + azione di gestione |
| Errore recuperabile | Messaggio comprensibile, retry, dettagli diagnostici |
| Errore credenziali | Richiesta di ricollegamento, senza esporre token |
| Nessuna pagina successiva | Fine dei risultati chiara, niente spinner infinito |
| Sync in conflitto | Origine e destinazione chiare, opzione di risoluzione |
| Download incompleto | Stato parziale distinto dal completato |
| Azione distruttiva | Conferma, ambito dei dati coinvolti, undo se possibile |

---

## 13. Modello dati concettuale [P]

**Non è lo schema del database Swift del repository**: è un modello progettuale di interoperabilità.

```text
Source
  id, name, language, kind, version, enabled, settings

Manga
  id, sourceId, sourceMangaId, title, altTitles, coverUrl,
  authors[], artists[], description, tags[], status, updatedAt

LibraryEntry
  mangaId, addedAt, categoryIds[], readingStatus,
  lastChapterId, lastPage, lastReadAt

Chapter
  id, mangaId, sourceChapterId, name, index, language,
  scanlator, releasedAt, isRead, pageCount

ReadingProgress
  mangaId, chapterId, pageIndex, pageOffset, updatedAt

DownloadTask
  id, chapterId, state, completedBytes, totalBytes,
  retryCount, localPath

SourceFilterState
  sourceId, stableFilterIds[], values, sortKey, updatedAt

SearchState
  scope, query, selectedFilters, nextPage, results[]

TrackerConnection
  provider, identity, status, lastSyncAt

ReaderPreferences
  readingMode, direction, doublePageOffset, background,
  autoScroll, chromeBehavior

BackupMetadata
  createdAt, version, contentTypes[], location
```

**Identità:** non usare soltanto il titolo come chiave: opere omonime, diversi scanlator e fonti differenti sono comuni. Definire gli ID immutabili a livello di sorgente e un'eventuale relazione di equivalenza per migrazioni gestita separatamente.

---

## 14. Architettura tecnica: ciò che è noto e ciò che non lo è

### 14.1 Fatti verificati [V]

- Repository pubblico Swift/Xcode con directory dell'app, test e progetto Xcode.
- Licenza del codice principalmente **GPLv3**; traduzioni soggette a **Apache 2.0**; contributori soggetti alle regole CLA descritte nel README.
- Fonti esterne eseguite tramite sistema **WASM**.
- Supporto dei provider locali/remoti documentati sopra.

### 14.2 Organizzazione logica suggerita [P]

```text
App shell / Navigation
  ├─ UI & design tokens
  ├─ Library feature
  ├─ Search feature
  ├─ Browse & source management
  ├─ Manga details
  ├─ Reader engine
  ├─ Downloads & local archives
  ├─ Trackers & Insights
  └─ Settings & backups

Domain layer
  ├─ Manga / Chapter / Page
  ├─ Reading progress
  ├─ Source filter contract
  └─ Download / sync state

Infrastructure
  ├─ WASM source adapter
  ├─ Komga / Kavita / Suwayomi adapters
  ├─ Local file importer / exporter
  ├─ Persistence & cache
  ├─ Network/image pipeline
  └─ Credentials & background tasks
```

Non attribuire pattern come MVVM, Combine, Core Data, SwiftData o specifici package manager al codice Aidoku senza audit diretto dei file.

### 14.3 Contratti non negoziabili per un'implementazione

- Le fonti decidono quali filtri e ordinamenti sono realmente supportati.
- Le pagine successive conservano gli stessi parametri di ricerca.
- L'app distingue assenza di risultati da errore di caricamento.
- Operazioni di rete e parsing non bloccano la UI.
- Le risorse vengono liberate quando si cambia capitolo o fonte.
- Il progresso locale non viene sovrascritto silenziosamente da un tracker esterno.
- Dati sensibili non entrano in log, crash report o esportazioni non cifrate.

---

## 15. Comportamento responsive e piattaforme [P]

### iPhone

Una colonna visiva principale, schede con griglia adattiva, tab accessibili al pollice, lettore full-screen e controlli che evitano safe area/notch/Dynamic Island. Orientamento landscape testato per doppia pagina.

### iPad

Griglie più dense; layout a due colonne se aumenta l'efficienza; pannelli di filtro più ampi; pieno supporto multitasking, resize e rotazione; lettore in modalità doppia pagina da verificare sui vari aspect ratio.

### macOS

Tastiera e pointer come interazioni primarie aggiuntive, hover, menu, scorciatoie, dimensionamento finestre e contenuti responsive. Evitare di portare letteralmente ogni bottom sheet mobile sul desktop.

---

## 16. Accessibilità, localizzazione e qualità

### Accessibilità [P]

Dynamic Type, VoiceOver con etichette utili su copertine e progressi, contrasto, Reduce Motion, dimensioni touch, navigazione da tastiera, rispetto del focus, supporto RTL quando appropriato. Non dedurre la leggibilità testuale di una tavola dal semplice fatto che l'immagine è visibile.

### Localizzazione [V/P]

Il progetto invita a contribuire alle traduzioni tramite **Weblate** [V]. Per una UI ispirata, isolare tutte le stringhe e non usare testo localizzato come identificatore persistente [P].

### Performance [P]

Misurare tempo di apertura libreria, fluidità dello scroll, consumo memoria webtoon, transizioni capitolo, latenza filtro, caricamento paginato e attività in background. È particolarmente importante perché le release documentano interventi sulla velocità della libreria e memoria del lettore webtoon [V].

---

## 17. User journey fondamentali [P]

**J1 — Iniziare da zero:** installazione → aggiunta fonte o server → catalogo → opera → aggiunta libreria → lettura primo capitolo.

**J2 — Riprendere:** avvio → libreria → titolo in corso → riprendi capitolo/pagina → lettura → stato aggiornato.

**J3 — Ricerca complessa:** fonte → ricerca → scelta sort/filtri → risultati pagina 1 → scroll/infinite load → pagina 2+ → apri opera → torna mantenendo query, risultati e scroll.

**J4 — Offline:** opera → scarica capitoli → interrompi rete → apri dalla libreria → leggi → progresso persistente.

**J5 — Migrazione:** opera nella fonte A → migra alla fonte B → confronta identità e capitoli → copia dati selezionati → verifica progresso e collegamenti.

**J6 — Studio lingua:** lettura → seleziona riconoscimento testo → lookup dizionario compatibile → ritorna alla stessa pagina senza perdita del contesto.

**J7 — Recupero:** backup disponibile → ripristino → validazione libreria, progressi, preferenze, collegamenti e archivi locali.

---

## 18. Criteri di accettazione verificabili [P]

### Libreria

- [ ] Cambiare da griglia a lista non cancella i filtri.
- [ ] Chiudere e riaprire preserva il filtro salvato.
- [ ] Le copertine fallite non fanno collassare il layout.
- [ ] Il refresh non blocca lo scrolling.

### Fonti e ricerca

- [ ] L'ordinamento modifica effettivamente i parametri inviati alla fonte.
- [ ] Una scelta filtro non viene persa tornando da un dettaglio.
- [ ] Dopo pagina 1, la pagina 2 viene caricata e aggiunta, non sostituita.
- [ ] Niente duplicazioni o loop quando una fonte ripete risultati.
- [ ] Un filtro senza supporto backend non viene mostrato come funzionante.
- [ ] Una fonte disabilitata è distinguibile da una fonte temporaneamente offline.

### Lettore

- [ ] Riprende alla pagina corretta dopo chiusura/riapertura.
- [ ] Cambiare modalità non perde il capitolo attivo.
- [ ] Le pagine larghe e la doppia pagina non vengono tagliate in modo improprio.
- [ ] Nella modalità webtoon vengono liberate le immagini non più necessarie.
- [ ] Incognito non salva la cronologia della sessione.

### Download e dati

- [ ] Un download fallito è ritentabile.
- [ ] Contenuto scaricato leggibile senza rete.
- [ ] Esportazioni CBZ sono apribili da un lettore compatibile.
- [ ] Backup/ripristino non produce duplicati incoerenti.

### Accessibilità

- [ ] Tutti i controlli principali sono utilizzabili con VoiceOver.
- [ ] Dynamic Type non tronca azioni critiche.
- [ ] Stati di errore, progresso e selezione sono distinguibili anche senza colore.

---

## 19. Audit necessario per una replica fedele 1:1

Questo documento è completo come **specifica funzionale e direzione di design**, ma una riproduzione autenticamente fedele richiede queste ulteriori evidenze:

1. **Checkout del repository alla commit esatta** e lettura degli entry point Swift, della configurazione delle schermate e degli assets.
2. **Inventario screenshot** di ogni tab, sottomenu, sheet, dark/light mode e reader mode; idealmente acquisito su iPhone e iPad.
3. **Misurazione token reali:** colore/accent, typography, radius, padding, dimensioni cover, toolbar, iconografia.
4. **Audit navigation tree:** nomi e numero esatto delle tab, tab selection, sidebar, routing, gesture native.
5. **Matrice impostazioni:** voce per voce, default esatti, scope globali/per fonte/per manga, valori consentiti.
6. **Audit componenti:** view Swift/UIView e stati osservabili, senza supposizioni sul framework impiegato da ciascuna schermata.
7. **Test su fonte WASM reale:** struttura filtri, ordine, cursori/pagine, mantenimento dello stato e fallimenti.
8. **Verifica Apple platform:** disponibilità delle funzioni in base a versione iOS e dispositivo.
9. **Confronto screenshot/diff** prima di ogni claim “pixel-perfect”.

Quando questo audit sarà possibile, sostituire i token [P] e i pattern [R] con riferimenti puntuali: `path/to/file.swift`, simbolo, commit hash, screenshot e condizione di test.

---

## 20. Fonti primarie

1. Repository ufficiale Aidoku: https://github.com/Aidoku/Aidoku
2. README ufficiale: https://github.com/Aidoku/Aidoku/blob/main/README.md
3. Release ufficiali: https://github.com/Aidoku/Aidoku/releases
4. Sito ufficiale: https://aidoku.app/
5. Guida introduttiva: https://aidoku.app/help/guides/getting-started/

### Note sulle versioni

- **v0.9-4** (16 ottobre 2026): fix webtoon pagine/memoria, ricerca macOS e altre correzioni.
- **v0.9** (3 settembre 2026): OCR + dizionari, Suwayomi, auto-scroll webtoon, stabilità fonti.
- **v0.8.3** (18 maggio 2026): migrazione migliorata, lettura continua con gap, doppia pagina.
- **v0.8.2** (18 marzo 2026): gruppi filtro, ricerche salvate, opzioni lettore, tracker MangaBaka.
- **v0.8** (3 gennaio 2026): insights, libreria e filtri, Live Text, incognito, transizioni iOS 26.
- **v0.7.3**: ricerca rinnovata, backup/download background e CBZ.
- **v0.7.2**: nuove impostazioni con ricerca, trattamento pagine larghe, progresso refresh.

---

## 21. Vincoli legali e di prodotto

Aidoku è open source, ma **open source non significa assenza di obblighi**. Prima di riutilizzare codice o distribuire un derivato, leggere `LICENSE` e il README alla revisione effettiva; la GPLv3 e le specifiche condizioni contributive/distributive dichiarate dagli autori vanno rispettate. Le traduzioni hanno una disciplina distinta. Non redistribuire indiscriminatamente copertine, tavole, fonti o dati protetti: i diritti dei contenuti restano dei rispettivi titolari.

**Fine documento.**
