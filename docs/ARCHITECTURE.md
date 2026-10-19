# Architettura e scelte tecniche

## Dipendenze

Domain → Foundation. Feature → Domain + servizi iniettati. Infrastructure → Domain + framework Apple. App → composizione dei servizi. I confini sono organizzativi in un singolo app target; `AnimeKodokuCore` riusa dominio e parser per i test Swift Package.

LocalStore e i ViewModel sono MainActor: l'accesso SwiftData e gli aggiornamenti UI avvengono sul main actor. NetworkClient è un actor; i fetch asincroni non bloccano la UI, il parsing dei sottotitoli usa un task detached. Il JSON REST di metadata ha un limite 20 MB dopo ricezione e la validazione dei manifest ha limite 1 MB; non è un runtime per grandi flussi multimediali. Il player usa AVPlayer direttamente, con AVPlayerLayer e integrazione AVKit per la selezione AirPlay.

## Persistenza

StoredRecord è un modello SwiftData con chiave unica e payload Codable. Sono persistiti record distinti per library, anime, episodes, preferences, downloads e sourceManifests. Lo schema esterno del backup ha versione 1. Questo evita di far attraversare il layer Domain da oggetti @Model; non sostituisce una futura strategia esplicita di migrazione quando si evolvono i payload. I contenuti della cache sono mantenuti per permettere la libreria offline; una politica di eviction della cache metadati resta un'estensione.

Il ripristino valida formato/versione/ID duplicati e riferimenti prima della scrittura; commit unico per le collezioni ripristinate. I progressi non cambiano lo stato della serie in “completata”: la selezione dell'utente prevale. Incognito impedisce salvataggi di progressi; la cronologia di ricerca resta una preferenza separata.

## Download

Due sessioni con identificatore stabile: file MP4 e asset HLS. Delegate separato non isolato sul main actor per spostare i file temporanei immediatamente. Eventi immutabili tornano sulla main queue; lo stato della coda viene salvato in SwiftData. Un attempt ID diverso per ogni retry impedisce che callback tardivi di task annullati modifichino una nuova richiesta. I path persistiti sono relativi al sandbox per tollerare lo spostamento del container.

HLS usa il pacchetto gestito dal sistema: non rinominare in MP4 e non spostarlo come un comune file temporaneo. Sono completati solo i record con location disponibile e callback di completamento riuscito. I task attivi vengono riconciliati al riavvio; quelli interrotti sono ritentabili, con un nuovo trasferimento. Non è implementato un resume byte-range persistente per MP4. La coda gestisce una singola attività alla volta per ridurre consumo e concorrenza. I percorsi dei video non sono esportati nel backup JSON.

## Player

PlayerSession possiede AVPlayer, l'osservatore temporale, KVO, notifiche e remote commands. Ogni sessione ha una generazione per scartare risultati asincroni obsoleti. `stop()` salva, annulla caricamenti, rimuove osservatori/target e rilascia l'item. Al background il layer si sgancia, ma il player/audio resta attivo. All'uscita dal player l'audio si arresta.

SubtitleParser gestisce SRT e sezioni Events ASS/SSA con Format esplicito, righe multiple e intervalli sovrapposti. Gli stili vengono rimossi; non equivale a libass. I sottotitoli caricati manualmente non vengono inclusi nel backup né associati permanentemente all'episodio.

## Tracker

TrackerService è il confine di integrazione. TrackerPlaceholder restituisce un errore esplicito: nessuna sincronizzazione dichiarata riuscita. Per un'implementazione reale servono OAuth tramite ASWebAuthenticationSession, callback URL, token in Keychain, API del provider, mapping anime ID e riconciliazione senza sovrascrittura silenziosa del progresso locale. Non sono incluse password o finte sessioni di accesso.

## Estensioni prioritarie

1. Eseguire CI e matrice su dispositivi reali, correggere ogni failure prima di distribuire.
2. Schema SwiftData versionato e migrazioni payload; pulizia cache metadata e thumbnail dedicata.
3. Download selezione audio/sottotitoli HLS, policy spazio, resumeData MP4, supporto content-type per URL senza estensione.
4. OAuth tracker con storage sicuro e mapping verificato.
5. Motore ASS avanzato opzionale, dopo valutazione licenza e distribuzione del renderer.
6. Runtime JS/WASM isolato, solo dopo specifica di sicurezza e compatibilità; evitare di promettere compatibilità con sorgenti Aidoku senza un'ABI adatta ai video.
