# Verifica riproducibile

## Limite della verifica eseguita qui

L'ambiente di generazione è Linux senza Xcode o Swift. `scripts/validate_static.py` verifica sintassi tramite tree-sitter-swift se installato, XML/plist, asset e riferimenti PBX. Gli XCTest sono inclusi ma non eseguiti qui. Il risultato statico è in `docs/STATIC_CHECKS.txt`; non dimostra la correttezza del type checking Apple, del provisioning, del rendering o del runtime AVFoundation.

Per ripetere il controllo statico: Python 3.10+ e, solo per il parsing Swift, `pip install tree-sitter tree-sitter-swift`; eseguire `python3 scripts/validate_static.py`. Questi package sono strumenti di verifica, non dipendenze dell'app.

## Verifica Apple obbligatoria prima della distribuzione

Su macOS con Xcode 15+: `./scripts/build.sh`. Il package contiene 13 XCTest per timestamp SRT/ASS, Unicode, sovrapposizioni, filtri intersecati, ID, Codable e roundtrip backup. La CI compila entrambi gli app target senza firma. Per una distribuzione effettiva, eseguire inoltre archivio firmato e installazione su dispositivo.

## Matrice manuale

| Scenario | Procedura | Risultato atteso |
|---|---|---|
| Primo avvio | Apri tutte le tab senza rete | Libreria/download vuoti spiegati, catalogo Demo accessibile |
| Paginazione | Demo, scorri oltre 24 opere | 48 totali, senza duplicati, fine catalogo |
| Ricerca | Cerca “orizzonte”, cambia sort della Demo | Titoli coerenti con query e ordine; filtro mantenuto tornando dal dettaglio |
| Libreria | Aggiungi 3 opere, cambia stato/fonte/tag, salva gruppo, riavvia | Filtri/gruppi e modalità conservati |
| Multi-select | Seleziona 2 opere, cambia stato; rimuovi | Stato aggiornato; conferma prima della rimozione |
| Fonti | Importa JSON valido/invalido e disabilita la fonte | REST installata o errore esplicito; nessun runtime JS implicito |
| Errori rete | REST offline, timeout, JSON errato | Errore recuperabile distinto da zero risultati |
| Ripresa | Riproduci 25 s, esci e rientra, riavvia | Riprende all'ultimo salvataggio, scarto normale entro 5 s |
| Incognito | Abilita prima di riprodurre, avanza ed esci | Progresso preesistente invariato |
| SRT/ASS | Importa i file fixture, fai seek alle battute | Battute nel tempo corretto; ASS senza stile avanzato |
| Audio background | Dispositivo reale: avvia, blocca schermo | Audio continua se il contenuto lo consente; comandi lock screen funzionanti |
| Interruzione audio | Chiamata/interruzione e scollega cuffie | Pausa sicura; ripresa solo quando consentita |
| MP4 offline | Scarica file supportato, modalità aereo, apri dai Download | Video da file locale; nessuna fonte necessaria |
| HLS offline | Scarica VOD M3U8 senza DRM, modalità aereo | Pacchetto HLS riproducibile da AVPlayer, non MP4 |
| Background download | Avvia, manda app in background e attendi | Progresso/stato riconciliati al rientro; rispettate policy sistema |
| Cancellazione/retry | Annulla e riprova rapidamente, termina processo | Nessun callback vecchio altera il nuovo tentativo; file parziali non completati |
| Backup | Esporta; cambia dati; importa e conferma; importa JSON invalido | Ripristino coerente o errore, nessun duplicato |
| Accessibilità | VoiceOver, Dynamic Type accessibilità, Reduce Motion | Controlli principali raggiungibili, leggibili, senza animazioni non richieste |
| iPad/Mac | Resize, landscape, multitasking, tastiera | Griglia adattiva; player e comandi restano accessibili |
| Memoria | Apri/chiudi e cambia episodio ripetutamente in Instruments | Nessun observer/AVPlayerItem accumulato |

Non sono ancora stati eseguiti audit prestazionali, screenshot comparativi, test su account tracker reali o test di resilienza su tutte le varianti HLS. La presenza del file di CI non significa che la pipeline sia stata già eseguita.
