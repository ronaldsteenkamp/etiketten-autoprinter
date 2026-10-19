# Etiketten autoprinter: checklist voor de ICT

Voor wie de app in een apotheek inricht of beheert. De gebruikersuitleg staat in
[LEESMIJ.md](../LEESMIJ.md).

## 1. Drie mappen, drie soorten rechten

De app gebruikt drie plekken. Zet ze **niet** in dezelfde map: de rapporten bevatten
naam en geboortedatum van patiënten, en wie de app (of de controlewaarde) in de
updatemap kan vervangen, kan code laten draaien op alle apotheek-pc's.

| Map | Inhoud | Lezen | Schrijven |
|---|---|---|---|
| **Updatemap** (bijv. `\\server\apps\Etiketten autoprinter`) | `Etiketten_autoprinter.exe` + `.sha256`, de gedeelde `Etiketten_autoprinter.ini` (planning, groepen, opties) | apotheekmedewerkers | de `.exe`/`.sha256`: alleen de beheerder. De `.ini`: apotheekmedewerkers (de app schrijft er planning en opties in) |
| **Datamap** (bijv. `\\server\apotheek\Etiketten autoprinter gegevens`) | `Gegevens\Log`, `Gegevens\Geprint` (register + claims), `Gegevens\Computers`, `Rapporten` | alleen apotheekmedewerkers | alleen apotheekmedewerkers |
| **Lokaal** (`%LOCALAPPDATA%\Etiketten autoprinter`) | de geïnstalleerde app, eigen `.ini` met alleen `[Update] Map` en `[Opslag] Map`, WebView2-cache | de gebruiker | de gebruiker |

Tip: zet de gedeelde `.ini` eventueel apart van de `.exe` met schrijfrechten alleen op
dat ene bestand; de app moet ook een `Etiketten_autoprinter.ini.slot` naast de ini
kunnen aanmaken en verwijderen (slot tijdens het schrijven).

**Alle computers moeten dezelfde datamap gebruiken.** Het register van geprinte
patiënten en de claims staan daar; met verschillende datamappen kan dezelfde patiënt
op twee computers geprint worden.

Instellen in de eigen ini van elke (lokaal geïnstalleerde) computer:

```
[Update]
Map=\\server\apps\Etiketten autoprinter
[Opslag]
Map=\\server\apotheek\Etiketten autoprinter gegevens
```

Een computer die de app vanaf de netwerkmap start, leest `[Opslag] Map` uit de ini in
die netwerkmap. Staat de datamap in de map van de app of in de updatemap, dan schrijft
de app bij elke start `LET OP: de gegevens ... staan in ...` in het log, en staat het
in **Diagnose**.

### Bestaande gegevens verhuizen

1. Sluit de app op alle computers.
2. Verplaats `Gegevens\` en `Rapporten\` naar de nieuwe datamap.
3. Zet `[Opslag] Map` op alle computers (en in de gedeelde ini).
4. Start de app en controleer in **Diagnose** de regel `Gegevens:`.

## 2. Nodig op elke werkplek

- Windows 10/11 met de **WebView2 Runtime** (zit standaard in Windows).
- Pharmacom (32-bit Java) met de **Java Access Bridge** aan: in de app *Koppeling
  inschakelen* (draait `jabswitch -enable` uit de Java-map van Pharmacom), daarna
  Pharmacom opnieuw starten.
- **PowerShell** mag starten: de app controleert daarmee de digitale handtekening
  van een update. Is de app ondertekend (SignPath) en kan PowerShell niet starten,
  dan worden updates geweigerd.
- Netwerk: `api.github.com` en `github.com` (nieuwe versies); anders alleen de
  updatemap.
- Geplande rondes: *Starten met Windows* aan, computer niet vergrendeld en niet in
  slaapstand op het geplande moment (de app houdt de computer vanaf 30 minuten ervoor
  wakker, maar kan hem niet wekken).

## 3. Beveiliging

- **Schrijfrechten op de `.exe` en `.sha256` in de updatemap: alleen de beheerder.**
  De controlewaarde beschermt tegen half gekopieerde bestanden, niet tegen iemand die
  beide vervangt.
- GitHub-account van de maker: tweestapsverificatie en branch protection op `main`.
- Zodra releases ondertekend zijn (SignPath): de app accepteert daarna alleen updates
  van dezelfde uitgever.
- SmartScreen-waarschuwing bij een download: na ondertekening verdwijnt die; tot dan
  het bestand vrijgeven of via de netwerkmap installeren.

## 4. Bewaartermijnen (AVG)

| Wat | Termijn | Waar instellen |
|---|---|---|
| Logbestanden (Pat.nr's, geen namen) | 30 dagen | — |
| Rapporten (naam, geboortedatum, etiket) | 90 dagen | `[Opslag] RapportDagen=` |
| Register van geprinte patiënten | 7 dagen | `[Opslag] RegisterDagen=` |
| Claims (`Gegevens\Geprint\Bezig`) | 2 dagen | — |

De app ruimt op bij het starten en elke 6 uur, maar alleen in de datamap die hij zelf
gebruikt.

## 5. Controle na het inrichten

1. **Diagnose** (in de app): `Gegevens:` wijst naar de datamap, geen `LET OP`-regel,
   koppeling actief, aanschrijfbuffer en medicatiehistorie herkend.
2. Een **proefronde** op een kleine groep: er wordt niets geprint; het rapport
   `Proefronde <datum>.csv` staat in de datamap.
3. Op een tweede computer: de lijst toont *Vandaag al geprint* voor wie op de eerste
   computer geprint is.
