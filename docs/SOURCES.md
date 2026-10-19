# Contratto fonti REST v1

Importa `source-manifest.example.json` dopo aver sostituito il dominio. Le risposte devono essere JSON UTF-8, senza wrapper di paginazione; risposta vuota `[]` indica fine pagine. Il client carica la pagina successiva solo su richiesta/in fondo al catalogo, conserva i parametri e interrompe pagine duplicate. Il server deve fornire ordinamento stabile; una pagina contenente solo elementi già visti viene considerata terminale.

| Metodo | Path relativo alla baseUrl | Parametri |
|---|---|---|
| GET | popular | page, a partire da 1 |
| GET | search | q, page, filter[id]=value |
| GET | details | id, ID completo con namespace |
| GET | episodes | animeId, ID completo con namespace |

Esempio: `/api/search?q=stelle&page=2&filter[sort]=title_desc`. URLComponents esegue l'escaping. Il server deve applicare ogni filtro dichiarato nel manifest; il client non mostra opzioni arbitrarie.

Anime:

```json
{
  "id": "my-server:show-42",
  "sourceId": "my-server",
  "title": "Un'opera del tuo server",
  "coverUrl": "https://your-server.example/covers/42.jpg",
  "bannerUrl": null,
  "description": "Descrizione",
  "status": "airing",
  "tags": ["Avventura"]
}
```

`popular` e `search` restituiscono un array di Anime; `details` un singolo Anime. `status`: airing, finished, upcoming, unknown. Gli URL null sono ammessi.

`episodes`:

```json
[
  {
    "id": "my-server:show-42:episode-1",
    "animeId": "my-server:show-42",
    "number": 1,
    "title": "Episodio 1",
    "videoUrl": "https://your-server.example/videos/1.mp4",
    "subtitleUrl": "https://your-server.example/subtitles/1.srt",
    "duration": 1440,
    "isWatched": false,
    "progress": 0
  }
]
```

Il client sovrappone i progressi locali ai nuovi metadata remoti; una risposta della fonte non cancella un episodio già visto. Gli ID devono essere immutabili, univoci e iniziare con `source.id + ":"`. Non usare il titolo come identità. `getDetails` deve restituire esattamente l'opera richiesta; `getEpisodes` soltanto episodi della stessa opera.

I video devono essere MP4/HLS riproducibili nativamente su Apple. Nessun header di autenticazione, cookie custom, DRM/FairPlay o rinnovo URL implementato in questa versione. Le configurazioni della fonte non devono contenere token; se si estende l'autenticazione, usare Keychain ed escludere le credenziali dai backup.

## JS/WASM in futuro

`SourceProtocol` separa l'esecuzione dal prodotto. Aggiungere un adattatore dedicato dietro lo stesso protocollo. Un runtime richiederà versionamento, permessi di rete, quote memoria/tempo, cancellazione, un contratto ABI, validazione dei bundle e test. Il manifest attuale rifiuta esplicitamente `kind` diversi da `rest`: nessun download di script viene eseguito di nascosto. Non sono incluse fonti per siti anime specifici.
