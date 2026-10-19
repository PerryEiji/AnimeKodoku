# AnimeKodoku

Client video open source per **iOS/iPadOS 17+ e macOS 14+**, scritto in Swift 5.9+ con SwiftUI, SwiftData e AVFoundation/AVKit. Ispirazione UX: Aidoku, con implementazione indipendente. Nessun video, anime o credenziale incluso. Licenza del codice: MIT.

## Apri e avvia

1. Su un **Mac con Xcode 15 o successivo**, estrai l'archivio e apri `AnimeKodoku.xcodeproj` (non `Package.swift`: il package serve ai test del dominio).
2. Seleziona lo schema **AnimeKodoku** per iPhone/iPad o **AnimeKodoku-macOS** per Mac.
3. Seleziona un simulatore iOS 17+ o “My Mac”, quindi premi Run. Non sono necessarie dipendenze SPM esterne, CocoaPods o XcodeGen.
4. Apri **Esplora → AnimeKodoku Demo → Apri catalogo**. Il catalogo ha 48 opere inventate, 24 per pagina, con 12 episodi dimostrativi per opera. Aggiungi un'opera alla libreria.
5. Il demo non include media. Per riprodurre un tuo video, in **Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables** imposta `DEMO_VIDEO_URL` su un MP4 o M3U8 HTTPS compatibile con AVPlayer. Opzionale: `DEMO_SUBTITLE_URL` su SRT/ASS UTF-8. Non incollare chiavi o credenziali negli URL.
6. Riavvia l'app e riapri il dettaglio per aggiornare gli URL degli episodi. Le variabili di schema valgono solo quando avvii da Xcode. Per una build installabile configura le chiavi omonime in **Build Settings → User-Defined** per entrambe le configurazioni; sono lette da Info.plist. `Config.example.xcconfig` mostra anche la sintassi corretta per un file xcconfig.
7. In alternativa importa un manifest REST da **Esplora** e collega un server conforme a `docs/SOURCES.md`.

Non serve un server per la libreria locale. Una fonte REST richiede invece un server già esistente: questo archivio contiene il client, non un servizio di hosting.

## Cosa è implementato

- Cinque tab: Libreria, Cerca, Esplora, Download, Impostazioni; NavigationStack, griglie adattive e layout compatibili con iPad/Mac.
- Libreria griglia/lista, ricerca locale, filtri persistenti stato/fonte/tag, gruppi salvati, selezione multipla e cambio stato/rimozione con conferma.
- Catalogo paginato con append e deduplica; ricerca globale concorrente, cronologia su invio, ambito fonte, filtri dichiarati dalla fonte e pagine successive con gli stessi parametri.
- Dettaglio con hero/cover, metadati, libreria e stato, episodi ordinabili, ripresa e marcatura visto.
- Player AVPlayer con overlay temporaneo, seek ±10 s tramite pulsanti/swipe orizzontale, scrubber, pinch fit/fill, velocità, episodio successivo, controlli tastiera base su Mac, sottotitoli esterni e incognito.
- Salvataggio progressi ogni 5 s, in pausa, all'uscita e al passaggio in background; episodio considerato visto al 90%, senza impostare automaticamente tutta la serie come completata.
- Background audio iOS con AVAudioSession, distacco del layer video quando l'app entra in background, Now Playing, remote commands, gestione interruzioni/cambio uscita audio.
- Download seriali MP4 con URLSession background; HLS offline con AVAssetDownloadURLSession su piattaforme supportate dagli SDK, riconnessione alle sessioni al riavvio, retry/annulla/elimina, archivio persistente e playback locale prioritario.
- SwiftData per libreria, cache dei metadati, episodi, progressi, preferenze, manifest e coda; backup JSON con ripristino validato e commit unico.
- Dynamic Type, etichette VoiceOver, controlli da almeno 44 pt e rispetto Reduce Motion. Le immagini mancanti mantengono il layout con artwork geometrico.

## Limiti espliciti

| Area | Comportamento di questa versione |
|---|---|
| Fonti | REST e Mock funzionano; JS/WASM sono contratti di estensione, senza runtime eseguibile. |
| AniList/MAL | Placeholder dichiarato. Non simula login, collegamenti o sync riusciti. OAuth, Keychain e mapping ID restano da implementare. |
| HLS → MP4 | **Non converte.** AVFoundation scarica un pacchetto HLS offline riproducibile da AVPlayer. Unire segmenti `.ts` non produce un MP4 valido in generale. DRM, live, URL scaduti o server non compatibili possono impedire il download. |
| MP4 offline | URL HTTPS con estensione `.mp4`; il video deve avere codec compatibili con il dispositivo. Download di URL opachi senza estensione non ancora supportato. |
| Sottotitoli ASS | Tempi, testo, righe multiple, sovrapposizioni; i tag di stile vengono rimossi. Nessun renderer libass, karaoke, font incorporato o posizionamento avanzato. SRT/ASS: UTF-8, massimo 5 MB. |
| Background | Il sistema programma i trasferimenti. Chiusura forzata, policy di rete/energia o contenuti non disponibili possono interromperli. Non esiste un valore Info.plist `downloads`: basta la sessione background; `UIBackgroundModes` abilita `audio`. |
| Offline subtitles | Il video viene prima completato, poi i sottotitoli esterni sono scaricati quando l'app può eseguire codice. Il loro completamento in background non è garantito; eventuale errore è visibile. L'import manuale nel player vale per la sessione corrente. |
| Restore | Sostituisce libreria/progressi/preferenze. I video locali e le installazioni REST restano sul dispositivo; installa nuovamente le fonti mancanti su un nuovo dispositivo. |
| Sync | Solo dati locali; nessuna sincronizzazione iCloud/cross-device in questa versione. |
| Lingua | UI italiana. Le stringhe sono estraibili da Xcode, ma non sono fornite traduzioni complete. Gli ID persistenti non dipendono dalle etichette. |
| Distribuzione | Progetto sorgente, non IPA firmato. Firma, profili, test su hardware e configurazione di distribuzione appartengono alla build sul tuo Mac. |

## Compila e verifica

```bash
./scripts/build.sh
```

Lo script esegue `swift test` (13 test di dominio e parser) e la compilazione senza firma per simulatore iOS e macOS. La CI in `.github/workflows/build.yml` fa gli stessi controlli su un runner Mac.

**Stato di verifica della consegna:** generato in ambiente Linux, senza `swift`, Xcode o SDK Apple. Sono stati verificati parsing sintattico Swift, integrità PBX, XML/plist, asset, riferimenti file e archivio con strumenti statici. Non è stata eseguita una compilazione Apple né sono stati eseguiti gli XCTest qui. Consulta `docs/VALIDATION.md` per i controlli riproducibili e i test su dispositivo. Non interpretare il controllo statico come certificazione della build.

## Genera un IPA

Su Mac:

1. In Xcode, target **AnimeKodoku → Signing & Capabilities**, imposta un bundle ID univoco e il tuo Team. Lascia attiva la firma automatica.
2. Con un iPhone collegato puoi usare Run per un'installazione di sviluppo; un account gratuito può consentire test personali con limiti di provisioning. Un export IPA distribuibile dipende dai profili e dal tipo di account Apple disponibili.
3. Seleziona **Any iOS Device (arm64)** e usa **Product → Archive**, quindi **Distribute App** con il metodo consentito dal tuo account.
4. Per CLI, sostituisci Team e bundle ID e aggiorna `ExportOptions.plist` con il Team e il metodo di export supportato dalla tua versione Xcode (il template `development` è per Xcode 15; Xcode più recenti possono usare `debugging`).

```bash
xcodebuild -project AnimeKodoku.xcodeproj -scheme AnimeKodoku \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/AnimeKodoku.xcarchive \
  DEVELOPMENT_TEAM=YOUR_TEAM_ID PRODUCT_BUNDLE_IDENTIFIER=your.unique.id \
  -allowProvisioningUpdates archive

xcodebuild -exportArchive -archivePath build/AnimeKodoku.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath build/export \
  -allowProvisioningUpdates
```

Non puoi compilare o firmare un IPA Apple usando solamente questo progetto su Windows. Nessun segreto di firma è incluso.

## Struttura

```text
AnimeKodoku.xcodeproj/          Due target nativi e schemi condivisi
Package.swift                  Dominio/parser e XCTest, non executable app
AnimeKodoku/
  App/                         Bootstrap, DI, shell, token e componenti
  Domain/                      Modelli Codable/Hashable e contratti
  Features/
    Library/ Browse/ Search/ Detail/ Player/ Downloads/ Settings/
  Infrastructure/
    Network/ Persistence/ Sources/ Player/ Downloads/ Tracking/
  Resources/                   Info.plist, assets, entitlements, privacy
Tests/AnimeKodokuCoreTests/     Casi di regressione dominio e sottotitoli
docs/                          Contratto REST, design, validazione
```

Le cartelle separano responsabilità; questo progetto non dichiara moduli binari separati per ogni feature. Il dominio non dipende da SwiftUI o SwiftData. I ViewModel coordinano servizi iniettati; la persistenza converte struct in payload versionabili all'interno di record SwiftData.

Design: `docs/DESIGN.md` e `docs/design-reference.md`. Contratto REST: `docs/SOURCES.md`. Per estendere l'app senza nascondere funzionalità incomplete: `docs/ARCHITECTURE.md`.
