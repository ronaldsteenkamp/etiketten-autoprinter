# Etiketten autoprinter: ontwikkeling

Voor wie aan de app werkt: opbouw, compileren, testen en releases.
Gebruik: [LEESMIJ.md](../LEESMIJ.md). Beheer: [beheer.md](beheer.md).

## Mappen

| Map / bestand | Inhoud |
|---|---|
| `Etiketten_autoprinter.ahk` | Hoofdbestand (AutoHotkey v2): start de app en voegt de modules samen |
| `src\Jab.ahk` | Java Access Bridge: Pharmacom uitlezen, tabellen, menu's, regels selecteren |
| `src\Pharmacom.ahk` | De stappen in Pharmacom (verbinden, selecteren, dossier controleren, printen, terugzetten) |
| `src\Zoekvelden.ahk` | Instelling en Afdeling invullen, Zoeken, aanschrijfbuffer openen (Ctrl+F11), alle groepen ophalen (klasse `PhZoek`) |
| `src\Ronde.ahk` | De patiëntenlijst en de printronde |
| `src\Venster.ahk` | Het venster (WebView2), knoppen, dialogen, instellingen, diagnose |
| `src\Opslag.ahk`, `src\Instellingen.ahk`, `src\Invoer.ahk`, `src\Update.ahk`, `src\Hulp.ahk` | Log/register/rapporten, ini, toetsenbord blokkeren, updates, hulpfuncties |
| `src\Planning.ahk`, `src\Groepen.ahk`, `src\Wijzigingen.ahk` | Geplande rondes; bekende groepen per apotheek; "Wat is er nieuw" |
| `src\Systeem.ahk` | Vergrendeling, geen slaapstand, waakhond, geheugen van Pharmacom |
| `src\Regels.ahk` | Beslisregels zonder Pharmacom: soort in de lijst, regel kiezen, Pat.nr in het dossier, sortering (los getest) |
| `tests\*.ahk`, `tests\alle_tests.ps1` | Unit-tests: hulpfuncties (`Eenheid`), planning, updates, ronde na een onverwachte fout (`Ronde`), register, claims en het slot op de ini (`Register`), beslisregels (`Regels`) |
| `src\lib\` | WebView2-bibliotheek van thqby (MIT-licentie) met de 32-bit WebView2Loader.dll; versies en controlewaarden in `src\lib\HERKOMST.md` |
| `docs\` | Beheer (`beheer.md`), inrichten voor de ICT (`ICT.md`), deze uitleg (`ontwikkeling.md`) |
| `review\` | Een eerdere review (v6.13) met proeven en testvoorstellen |
| `Etiketten_autoprinter.exe` | De app (32-bit, moet 32-bit blijven: Pharmacom draait op 32-bit Java) |
| `Etiketten_autoprinter.ico` | Pictogram |
| `ui\venster.html`, `ui\icoon.png` | De interface (HTML/CSS in WebView2, de Edge-browser van Windows); wordt in de .exe meegenomen, dus na een wijziging opnieuw compileren |
| `Etiketten_autoprinter.ini` | Instellingen (opties, wachttijden, updatemap) |
| `Gegevens\` | Logbestand (Pat.nr's, geen namen; venstertitels met cijfers of een komma worden "(titel verborgen)"), `Geprint\<datum>.txt` (wie vandaag geprint is) en `Geprint\Bezig\` (claims van patiënten die nu verwerkt worden) |
| `Rapporten\` | Een CSV-rapport per ronde (opent in Excel) |
| `Hulpmiddelen\icoon.svg`, `icoon-klein.svg` | Ontwerp van het app-icoon (groot en vereenvoudigd voor 16-24 px) |
| `Hulpmiddelen\maak_icoon.ps1` | Maakt `Etiketten_autoprinter.ico` en `ui\icoon.png` uit de SVG's (rendert met Microsoft Edge) |
| `Hulpmiddelen\jab_tabellen_tonen.ps1` | Toont welke tabellen/kolommen Pharmacom laat zien (voor onderhoud) |
| `Archief\` | Oude versies (v4, v5.7.2, v5.8.0); niet meer in git (staat in de tag `archief` en alleen nog lokaal) |

## Compileren

Nodig: AutoHotkey **v2** (32-bit) en Ahk2Exe 1.1.37 of nieuwer.

```
Ahk2Exe.exe /in "Etiketten_autoprinter.ahk" /out "Bouw\Etiketten_autoprinter.exe" /base "<map van AutoHotkey v2>\AutoHotkey32.exe"
```
Compileer naar **`Bouw\`**, niet direct in deze map: deze map is ook de updatemap.
Staat hier een nieuwere .exe zonder passende controlewaarde, dan weigeren de andere
computers de update ("Bijwerken niet mogelijk"). Test de nieuwe versie (bijv. met de
nep-Pharmacom, die `Bouw\` gebruikt als daar een .exe staat), kopieer hem daarna naar
deze map en zet de controlewaarde (`Etiketten_autoprinter.exe.sha256`, SHA-256 in kleine
letters) ernaast. `Hulpmiddelen\maak_release.ps1` maakt die controlewaarde in `Bouw\`
al aan; dan kun je beide bestanden kopiëren.
Gebruik altijd de **32-bit** base (`AutoHotkey32.exe`): Pharmacom draait op 32-bit Java.
De pagina, het pictogram en de WebView2Loader.dll worden in de .exe meegenomen.
De app heeft de WebView2 Runtime nodig; die zit standaard in Windows 10/11.

Versienummers hebben sinds 6.13 twee delen (`6.13`, `6.14`, ...; daarvoor drie,
zoals `6.12.0`); de app vergelijkt ze als getal, dus 6.13 is nieuwer dan 6.12.0. De
.exe krijgt `6.13.0.0`. Het versienummer staat alleen in `AppVersie := "..."`; Ahk2Exe neemt het via de
`;@Ahk2Exe-Let`-regel daaronder over in de .exe. Controleer na het compileren de
versie (rechtsklik op de .exe → Eigenschappen → Details): de update-functie
vergelijkt die versie.

## Testen met de nep-Pharmacom

`tests\Test met nep-Pharmacom.cmd` start `tests\NepPharmacom.js` (met `jjs.exe` uit
de Java van Pharmacom; niets te installeren) en de app in **testmodus**: de app zoekt
dan `jjs.exe` in plaats van Pharmacom, en gebruikt eigen instellingen en gegevens in
`%TEMP%\Etiketten autoprinter test`. De echte planning, het register en de logs
worden dus niet geraakt, en hij mag naast de gewone app draaien.

De nep-Pharmacom doet het dashboard, de aanschrijfbuffer (Ctrl+F11, zoekvelden,
Zoeken, "Geen patiënten gevonden"), het dossier (Ctrl+B), de medicatiehistorie (F4)
en het afdrukmenu (Ctrl+P) na, met verzonnen patiënten (Pat.nr 9000xx): gewone,
zonder regel van AN, met een lege historie, met een ontslagdatum en zonder
"ASB: Deelbaar". T2/T2GUA is een lege groep. Geprinte (nep)etiketten komen in
`tests\nep_geprint.txt`.

Met een argument start de app meteen een ronde, zoals een planning:
`"Test met nep-Pharmacom.cmd" T1/T1GUA/proef` of `.../print`.

**Foutscenario's (instelling T3, één afdeling per scenario).** Elke afdeling heeft
één patiënt met één ding dat mis kan gaan; start ze apart, bijv.
`"Test met nep-Pharmacom.cmd" T3/T3DOS/print`. Na een stop moet Pharmacom weer op de
aanschrijfbuffer staan en mag er niets in `nep_geprint.txt` bij gekomen zijn. (Bij
een geplande ronde gaat de app na een hapering zelf verder; stopt hij twee keer bij
dezelfde patiënt, dan wordt die overgeslagen.)

| Groep | Pat.nr | Scenario | Verwacht |
|---|---|---|---|
| T3/T3DOS | 900031 | Dossier toont een ander Pat.nr | Stop `[P08]`, niets geprint |
| T3/T3POP | 900032 | Ctrl+B opent een melding in plaats van het dossier | Stop `[P07]` (geen historie in dat venster), niets geprint |
| T3/T3VER | 900033 | Historie ververst bij het selecteren (nieuwe bovenste regel) | Stop `[P09]`, niets geprint |
| T3/T3MEN | 900034 | Ctrl+P doet niets | Stop `[P10]`, niets geprint |
| T3/T3SRT | 900035 | Historie oudste bovenaan | Geprint (SIMVASTATINE); log: `SCHADUW sortering Laatste V/A: NIET aflopend` |
| T3/T3VLD | 900036 | Pat.nr niet in een Pat.nr-veld | Geprint; log: `SCHADUW Pat.nr-veld: NIET gevonden` |
| T3/T3TRG | 900037 | Historie verschijnt pas na 2,5 s | Geprint (METFORMINE) |

Bij alle gewone patiënten (T1, T2) moet het log `SCHADUW Pat.nr-veld: gevonden` en
`SCHADUW sortering Laatste V/A: aflopend` geven.

## Updates via GitHub

GitHub is de **eerste bron** voor nieuwe versies. De repository staat in
`AppGitHub := "eigenaar/naam"` (hoofdbestand), of per ini in `[Update]
GitHub=eigenaar/naam`. Bij het starten kijkt de app naar de nieuwste release op GitHub
(`api.github.com/repos/<repo>/releases/latest`). Alleen als GitHub niet bereikbaar is
(of niet ingesteld), kijkt hij in de updatemap (netwerkmap) als reserve. Een release moet twee bestanden
hebben: `Etiketten_autoprinter.exe` en `Etiketten_autoprinter.exe.sha256`. De
download komt in `%TEMP%\Etiketten autoprinter download` en wordt net zo
gecontroleerd als bij de updatemap. Downloaden gebruikt de proxy-instellingen van
Windows. Is GitHub niet bereikbaar, dan staat dat alleen in het log.

### Een release maken (GitHub bouwt)

1. Verhoog `AppVersie`, zet de wijzigingen in `src\Wijzigingen.ahk`, test (lokaal in
   `Bouw\`, eventueel met de nep-Pharmacom), commit en push. Bij elke push draait
   GitHub de tests (`.github\workflows\tests.yml`; zie het tabblad *Actions*).
2. `powershell -ExecutionPolicy Bypass -File Hulpmiddelen\maak_release.ps1`:
   zet de tag `v<AppVersie>` en pusht die. GitHub (`.github\workflows\release.yml`)
   controleert dat tag en versie gelijk zijn, draait de tests, compileert met
   AutoHotkey 2.0.26 (32-bit) en Ahk2Exe 1.1.37.02, ondertekent (als SignPath is
   ingesteld, zie hieronder), maakt de controlewaarde en een **herkomstbewijs**
   (build provenance attestation) en publiceert de release met de tekst uit
   `src\Wijzigingen.ahk` (`Hulpmiddelen\release_tekst.ps1`).
3. Het script wacht op die bouw, downloadt de release, controleert controlewaarde,
   handtekening en herkomstbewijs, en zet de .exe met controlewaarde in de
   netwerkmap (reserve, en voor computers die vanaf de netwerkmap starten of een
   versie van voor 6.10 hebben).

Herkomst controleren kan iedereen:
`gh attestation verify Etiketten_autoprinter.exe --repo ronaldsteenkamp/etiketten-autoprinter`.

Werkt GitHub Actions niet: `maak_release.ps1 -Lokaal` maakt de release van de geteste
.exe in `Bouw\` (zonder ondertekening en herkomstbewijs). Git en de GitHub CLI staan
draagbaar in `%LOCALAPPDATA%\Programs\MinGit` en `...\gh`; het script vindt ze zelf.

Tests zonder melding (zoals op GitHub):
`powershell -ExecutionPolicy Bypass -File tests\alle_tests.ps1 -Ahk "<pad>\AutoHotkey32.exe"`.

### Ondertekenen (SignPath Foundation)

Gratis voor open source; haalt de SmartScreen-waarschuwing ("Windows heeft uw pc
beschermd") weg. Aanvragen op [signpath.org](https://signpath.org) (nodig: de
MIT-licentie, een release, de *Code signing policy* in de README en
tweestapsverificatie op GitHub). Na goedkeuring in de repository instellen
(Settings → Secrets and variables → Actions): secret `SIGNPATH_API_TOKEN`, en
variabelen `SIGNPATH_ORGANIZATION_ID`, `SIGNPATH_PROJECT_SLUG`,
`SIGNPATH_POLICY_SLUG`. Daarna ondertekent `release.yml` elke release; zonder die
instellingen wordt de stap overgeslagen.

### Meldingen en problemen

Meldingen rechtsonder (bij de klok) zijn aan te klikken: bij een planningsmelding
opent de planning, anders het venster (`Melder` in `src\Systeem.ahk`). In *Vraag of
idee* maakt de knop **GitHub** een openbaar issue (`.github\ISSUE_TEMPLATE\
probleem.yml`) met versie, omgeving en foutcodes al ingevuld; nooit computernaam,
apotheek of regels uit het log.

Wat nooit in de repository komt (zie `.gitignore`): `Gegevens\` (logs, register),
`Rapporten\` (namen en geboortedata), de ini (planning, computernamen), `.exe`'s en
controlewaarden (die gaan in de release), `Bouw\` en testuitvoer.

Wie de .exe van GitHub downloadt en vanuit Downloads of het bureaublad start, krijgt
de vraag *Op deze computer installeren*; die installatie haalt updates dan van
GitHub.
