# Feedy

Feedy è un lettore RSS nativo per macOS, con un'interfaccia a tre colonne in stile Mail: elenco feed a sinistra, lista articoli (con stato letto/non letto e ricerca) al centro, vista articolo a destra.

## Funzionalità

- Aggiunta/rimozione feed (RSS, Atom, JSON Feed)
- Aggiornamento all'avvio e su richiesta (bottone in toolbar / Cmd-R)
- Stato letto/non letto per articolo, con menu contestuale per segnare come letto/non letto e copiare il link
- Rendering articoli con stile coerente (CSS unico, indipendente dal feed sorgente) e font size regolabile (A-/A+, Cmd-+/Cmd--/Cmd-0)
- Traduzione articoli inglese → italiano on-device, tramite il framework `Translation` di Apple
- Indicatore di salute per ogni feed (ultimo errore di fetch, se presente)

## Stack tecnico

Swift, SwiftUI, SwiftData, WKWebView, [FeedKit](https://github.com/nmdias/FeedKit) 10.4 (parsing RSS/Atom/JSON), [SwiftSoup](https://github.com/scinfu/SwiftSoup) (sanitizzazione HTML), framework `Translation` di Apple, XCTest.

Richiede macOS 15.0+ (deployment target, alzato da 14 per `Translation`).

## Build ed esecuzione

Da riga di comando, dalla cartella `Feedy` (quella con `Feedy.xcodeproj`):

```bash
cd Feedy
xcodebuild -scheme Feedy -destination 'platform=macOS' build
```

Test:

```bash
xcodebuild test -scheme Feedy -destination 'platform=macOS'
```

Per creare una build Release installabile in `/Applications`, vedi [`build.md`](build.md).

## Struttura del progetto

```
Feedy/                            Xcode project root (contiene Feedy.xcodeproj)
  Feedy/
    FeedyApp.swift                 Entry point dell'app, setup ModelContainer
    ContentView.swift              Shell a tre colonne (NavigationSplitView)
    Models/                        Entità SwiftData (Feed, Article)
    Core/                          Logica di dominio pura/testabile (parsing, sanitizzazione, import, rendering)
    Views/                         Viste SwiftUI (Sidebar, ArticleList, ArticleDetail, WebView, AddFeedSheet)
    Resources/article.css          Foglio di stile unico per il rendering degli articoli
  FeedyTests/
    Fixtures/                      Fixture di feed XML e HTML "sporco" usate nei test
```

La logica di dominio in `Core/` è disaccoppiata da SwiftUI/SwiftData/rete tramite protocolli, così parsing dei feed, sanitizzazione HTML, import articoli e rendering sono testabili senza UI né accesso di rete.

Maggiori dettagli architetturali in [`CLAUDE.md`](CLAUDE.md).

## Cosa manca (fuori scope per v1)

Estrazione full-text per feed troncati, auto-discovery dei feed da un URL, cartelle/gruppi, refresh in background, ricerca full-text nel corpo, caching immagini, pulizia/pruning del DB, fetch delle favicon.
