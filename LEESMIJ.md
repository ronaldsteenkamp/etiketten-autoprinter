# Etiketten autoprinter voor Pharmacom

Print automatisch etiketten voor alle patiënten in de aanschrijfbuffer van
Pharmacom die geen ontslagdatum hebben.

## Gebruik

1. Open Pharmacom op het scherm **Aanschrijfbuffer**.
2. Start `Etiketten_autoprinter.exe`. De lijst vult zich vanzelf en wordt bijgewerkt
   als de aanschrijfbuffer verandert.
3. Haal eventueel vinkjes weg bij patiënten die je niet wilt printen.
4. Klik op **Start printen**. Tijdens het printen zijn toetsenbord en muis
   geblokkeerd; **Esc** stopt direct.
5. Gestopt? Klik op **Doorgaan**: wie al geprint is, wordt overgeslagen.

De app kijkt elke 3 seconden kort (± 5 ms) of de aanschrijfbuffer veranderd is
(aantal regels, eerste en laatste Pat.nr) en elke 30 seconden volledig. Hij
pauzeert als de app of Pharmacom geminimaliseerd is, of als Pharmacom een ander
scherm toont dan de aanschrijfbuffer (dan staat bovenaan "open de
aanschrijfbuffer").

Eenmalig: klik op **Koppeling inschakelen** en start Pharmacom opnieuw
(dit zet de Java Access Bridge aan, waarmee de app Pharmacom kan uitlezen).

## Proefronde

Met **Proef** (of Ctrl+Shift+Enter) doorloopt de app de aangevinkte patiënten
precies zoals bij printen (dossier openen, controleren, regel zoeken en
selecteren), maar drukt Escape in plaats van te printen. Er wordt niets geprint
en niets als geprint geregistreerd. Per patiënt zie je "Zou printen: <etiket>";
er komt een rapport `Proefronde <datum>.csv` in de map Rapporten.

## Planning

Onder **Planning** (of Ctrl+G) stel je in welke groepen (afdelingen) automatisch
geprint worden: Instelling + Afdeling (typen of kiezen uit de lijst; de naam is
de naam van de groep en elke groep kan maar één keer gepland worden), een
optionele opmerking,
dagen, tijd en elke week / even weken / oneven weken (ISO-weeknummer).

- Instelling en Afdeling vult de app direct in via de koppeling (focus op het
  tekstvak, tekst erin zetten, Tab); lukt dat niet, dan klikken en typen. Op
  **Zoeken** klikt de app wel gewoon met de muis: een knop "klikken" via de
  koppeling blokkeert de app als Pharmacom daarna een melding toont.
- **Alle groepen ophalen** leest alle instellingen en afdelingen uit Pharmacom
  (venster "Kies een instelling" en de keuzelijst bij Afdeling) en zet daarna je
  eigen groep terug. De lijst staat per apotheek in de ini (`[Groepen AN]`).
- Volgorde: regels slepen, of de pijltjes gebruiken; **A–Z** sorteert op naam.

- Een planning start binnen 15 minuten na de ingestelde tijd, één keer per dag,
  zolang de app draait en Pharmacom open is.
- Eerst 30 seconden aftellen met **Annuleren**; daarna vult de app Instelling en
  Afdeling in Pharmacom in, klikt op Zoeken, controleert dat de lijst die afdeling
  bevat en print. Vandaag al geprinte patiënten worden nooit opnieuw geprint.
- Alleen de computer waarop de planning is gemaakt voert hem uit (zo print nooit
  meer dan één computer dezelfde groep); met "hier uitvoeren" verplaats je hem.
- Per regel: kolfje = nu als proefronde (niets printen), driehoekje = nu uitvoeren.
- De planning staat per apotheek in de ini (`[Planning AN]`).
- Elke regel toont hoe de laatste keer afliep: *gelukt*, *mislukt*, *geannuleerd*
  of *niet uitgevoerd* (`[Planning status]`). Was de app uit of Pharmacom dicht
  op een gepland moment, dan meldt de app dat bij de volgende start (tot 7 dagen
  terug), met een melding en bij het icoon bij de klok.
- Zet **Starten met Windows** aan (Instellingen) als je de planning gebruikt:
  de app maakt dan een snelkoppeling in de map Opstarten van Windows.
- De aanschrijfbuffer hoeft niet open te staan: staat Pharmacom op een ander
  scherm (bijv. het dashboard), dan opent de planning hem zelf met Ctrl+F11 (de
  knop *Aanschrijfbuffer* in de werkbalk). Na de ronde blijft hij open. De
  apotheek leest de app uit de statusbalk van Pharmacom (staat op elk scherm).
- **Uitstel:** kan een geplande ronde niet starten omdat de computer vergrendeld
  is, Pharmacom niet open is, er een melding of inlogvenster openstaat of
  niemand is ingelogd, dan wacht hij (status
  *uitgesteld*) en start hij zodra het kan, tot 2 uur na de ingestelde tijd.
  Daarna: *mislukt* met de reden, en een melding. Na ontgrendelen kijkt de app
  meteen. Ook na het aftellen wordt dit nog een keer gecontroleerd.
- **Zelf verder na een hapering:** stopt een geplande ronde (niet door Esc/Stop,
  niet omdat Pharmacom dicht of niet actief was) en staat Pharmacom daarna weer op
  de aanschrijfbuffer, dan gaat de app na 3 seconden zelf verder, tot 3 keer. Wie al
  geprint is, wordt overgeslagen. Stopt hij twee keer bij dezelfde patiënt, dan wordt
  die overgeslagen (status en melding noemen het Pat.nr: handmatig controleren).
- **Planning controleren:** een combinatie van instelling en afdeling die volgens
  *Alle groepen ophalen* niet bestaat, kan niet opgeslagen worden; een bestaande
  foute planning staat in de lijst als "Klopt niet" (code `[L12]`).
- **Lege groep:** de melding "Geen patiënten gevonden" van Pharmacom sluit de app
  zelf (anders bleef die openstaan en wachtte de volgende planning).
- **Vooraf-controle:** een minuut vóór een geplande tijd kijkt de app, zonder iets
  in Pharmacom in te voeren, of de ronde kan starten (computer niet vergrendeld,
  Pharmacom open en bereikbaar, geen melding open, iemand ingelogd, de juiste
  apotheek). Zo niet, dan meteen een waarschuwing (melding bij de klok, geluid en de
  statusregel), zodat iemand het nog kan oplossen. Het resultaat staat in het log
  (`Vooraf-controle`).
- **Apotheek onthouden:** de laatst gelezen apotheek staat per computer in de ini
  (`[App]` `Apotheek <computer>`). Zo kent de planning de apotheek ook direct na het
  opstarten. Vlak voor de ronde controleert de app of die apotheek echt is ingelogd.
- **Geen slaapstand:** vanaf 30 minuten vóór een geplande tijd tot het einde van
  het startvenster (en zolang een ronde uitgesteld is), en tijdens elke ronde,
  vraagt de app Windows om niet in slaapstand te gaan. Een computer die al slaapt
  kan de app niet wekken.
- Testen zonder Pharmacom: in de ini `[Test]` `Belemmering=<reden>` doet alsof
  het niet kan (daarna weer weghalen).

## Waakhond

Bij het starten start de app een tweede, onzichtbaar proces: dezelfde .exe met
`/waakhond` (in Taakbeheer zie je de app dus twee keer). De app geeft elke
seconde een levensteken. Blijft dat 20 seconden uit terwijl toetsenbord en muis
geblokkeerd zijn (de app hangt), dan sluit de waakhond de app af, zodat de
blokkade weg is. Hij logt dat (`WAAKHOND`), meldt met welk Pat.nr de app bezig
was en vraagt of de app opnieuw moet starten. De waakhond stopt vanzelf als de
app sluit. Omdat de waakhond dezelfde .exe is, regelt de app zelf dat er maar één
exemplaar draait (in plaats van `#SingleInstance Force`).

Elk uur (en bij het verbinden) komt het geheugengebruik van Pharmacom in het log,
om te zien of Pharmacom in de loop van de dag zwaarder wordt.

## Sneltoetsen

| Toets | Actie |
|---|---|
| F5 (of ↻ boven de lijst) | Opnieuw uitlezen en vinkjes terugzetten |
| Ctrl+Enter | Start printen |
| Ctrl+Shift+Enter | Proefronde |
| Esc | Stoppen tijdens het printen, of dialoog sluiten |
| Ctrl+G / Ctrl+I | Planning / Instellingen |
| F1 | Overzicht van de sneltoetsen |

## Instellingen per apotheek

"Alleen ASB: Deelbaar", "Dossier controleren", "Dossier alleen op Pat.nr" en het
item in het afdrukmenu gelden per ingelogde apotheek (ini-sectie `[Opties AN]`;
in Instellingen gemarkeerd met de apotheekcode). Staat daar niets, dan geldt de
algemene waarde. Wachttijden, geluid, venster bovenop, bevestigen en toetsenbord
blokkeren horen bij de computer.

Na een update toont de app één keer **Wat is er nieuw** (lijst in
`src\Wijzigingen.ahk`; bij een nieuwe versie daar een regel toevoegen).

## Wat de app per patiënt doet

1. Zoekt de patiënt op Pat.nr in de aanschrijfbuffer en selecteert hem direct via de
   koppeling (zoals een klik; lukt dat niet, dan met pijltjestoetsen) en controleert
   de selectie.
2. Ctrl+B (dossier) → F4 (medicatiehistorie) → pijl omhoog.
3. Controleert dat het dossier van de juiste patiënt is (Pat.nr in het dossiervenster).
4. Selecteert de **bovenste** regel met Ap = de ingelogde apotheek (rechtsonder in
   Pharmacom, bijv. `AN - RS - 183`) en, als die optie aan staat, Herhaal info
   `ASB: Deelbaar`. Ook die regel wordt direct via de koppeling geselecteerd en in
   beide helften van de medicatiehistorie gecontroleerd.
5. Ctrl+P → wacht tot het afdrukmenu in het dossier zichtbaar is → kiest
   **Barcode etiket** (Alt+B) → wacht tot het menu dicht is → Escape, en wacht tot
   de aanschrijfbuffer terug is.

Klopt iets niet (selectie, scherm, dossier, actief venster), dan stopt de app.
Hij gokt nooit. Verschijnt het afdrukmenu met het juiste item niet binnen
`MaxWachtPrint` ms (minimaal 1000, standaard 3000), dan stopt de app zonder iets
te kiezen; die patiënt telt dan als *niet* geprint.

Stopt de app door een fout, dan zet hij Pharmacom zelf terug op de
aanschrijfbuffer (Escape voor het afdrukmenu en het dossier), zodat **Doorgaan**
meteen werkt. Dat doet hij ook als je zelf stopt (Esc/Stop); alleen als
Pharmacom niet meer het actieve venster is, laat hij alles staan.

**Vangnet:** gaat er iets onverwachts mis in de app zelf (een programmafout),
dan haalt de app eerst de blokkade van toetsenbord en muis eraf, stopt de ronde,
zet Pharmacom terug op de aanschrijfbuffer, schrijft de fout in het log
(`ONVERWACHTE FOUT`) en toont een melding. Was het etiket al gekozen, dan telt
die patiënt als geprint. De app blijft draaien; met **Doorgaan** ga je verder.
Testen kan alleen in een proefronde: zet in de ini `[Test]` `Fout=dossier`
(daarna weer weghalen).

**Pharmacom terughalen** (optie, standaard uit): springt er tijdens het printen een
venster van een ander programma voor Pharmacom (bijv. een Teams-melding), dan haalt
de app Pharmacom terug en gaat verder, in plaats van te stoppen. Alleen als
toetsenbord en muis geblokkeerd zijn, nooit als het venster van de app zelf actief is,
en hoogstens 5 keer per ronde. Elke keer staat in het log (`focus teruggehaald van ...`).

**Pharmacom afgesloten:** de koppeling meldt het meteen als Pharmacom afsluit. Loopt er
een ronde, dan stopt die direct (`[P01]`).

**Eén exemplaar:** start de app een tweede keer (ook via een ander pad, bijv. `W:\`
en `\\server\`), dan sluit het oude exemplaar. Twee exemplaren zouden elkaar de focus
afpakken en een planning dubbel kunnen uitvoeren.

## Foutcodes

Elke stop of mislukte planning krijgt een vaste code achter de tekst, bijv.
"Pharmacom keerde niet terug naar de aanschrijfbuffer [P11]", in de melding, het
log, het rapport en de planningstatus. De lijst staat in `FoutCode()` in
`src\Hulp.ahk`; codes worden nooit hergebruikt.

| Code | Betekenis |
|---|---|
| G01 | Gestopt door de gebruiker (Esc / Stop) |
| P01 | Pharmacom is afgesloten tijdens de ronde |
| P02 | Pharmacom was niet (meer) het actieve venster / kon niet naar voren |
| P03 | Het dossier was niet meer het actieve venster |
| P04 | Aanschrijfbuffer niet zichtbaar / ging niet open |
| P05 | Patiënt kon niet geselecteerd worden in de aanschrijfbuffer |
| P06 | Patiëntdossier verscheen niet |
| P07 | Medicatiehistorie niet herkend of bleef veranderen |
| P08 | Dossier niet bevestigd (Pat.nr) |
| P09 | Regel in de medicatiehistorie kon niet geselecteerd worden |
| P10 | Afdrukmenu: verscheen niet, item niet te kiezen of sloot niet |
| P11 | Pharmacom keerde niet terug naar de aanschrijfbuffer |
| L01 | Planning: veld Instelling/Afdeling niet gevonden of code niet geaccepteerd |
| L02 | Planning: knop Zoeken niet gevonden of zoeken duurde te lang |
| L03 | Planning: lijst bevat patiënten van een andere afdeling |
| L04 | Planning: computer vergrendeld |
| L05 | Planning: Pharmacom niet open / geen verbinding |
| L06 | Planning: melding of venster open in Pharmacom |
| L07 | Planning: niemand ingelogd |
| L08 | Planning: een andere apotheek is ingelogd |
| L09 | Planning: Pharmacom kon niet gecontroleerd worden |
| L10 | Planning: niet gestart binnen 2 uur |
| L11 | Planning: er liep al een ronde |
| L12 | Planning klopt niet: afdeling hoort niet bij de instelling |
| X99 | Onverwachte fout in de app (vangnet) |

Of er echt een etiket uit de printer kwam, kan de app niet controleren: de
etikettenprinters (STAR/Zebra) worden via de Pharmacom-server aangestuurd, niet
via Windows. Het etiket zelf is de bevestiging.

Het dossier telt standaard alleen als juist als het **Pat.nr** erin staat (optie
*Dossier alleen op Pat.nr controleren*). Zet je die uit, dan mag achternaam +
geboortedatum ook.

Welk item uit het afdrukmenu gekozen wordt, staat in de ini onder `[Opties]` als
`PrintMenu=Barcode etiket` (exact de tekst uit het menu, bijv. `Afleveretiket`).
De sneltoets leest de app zelf uit Pharmacom.

## Mappen

| Map / bestand | Inhoud |
|---|---|
| `Etiketten_autoprinter.ahk` | Hoofdbestand (AutoHotkey v2): start de app en voegt de modules samen |
| `src\Jab.ahk` | Java Access Bridge: Pharmacom uitlezen, tabellen, menu's, regels selecteren |
| `src\Pharmacom.ahk` | De stappen in Pharmacom (verbinden, selecteren, dossier controleren, printen, terugzetten) |
| `src\Ronde.ahk` | De patiëntenlijst en de printronde |
| `src\Venster.ahk` | Het venster (WebView2), knoppen, dialogen, instellingen, diagnose |
| `src\Opslag.ahk`, `src\Instellingen.ahk`, `src\Invoer.ahk`, `src\Update.ahk`, `src\Hulp.ahk` | Log/register/rapporten, ini, toetsenbord blokkeren, updates, hulpfuncties |
| `src\Planning.ahk`, `src\Wijzigingen.ahk` | Geplande rondes; "Wat is er nieuw" |
| `src\Systeem.ahk` | Vergrendeling, geen slaapstand, waakhond, geheugen van Pharmacom |
| `tests\Eenheid.ahk`, `tests\Planning.ahk` | Unit-tests (hulpfuncties; planning: dagen, weken, tijdvenster) |
| `src\lib\` | WebView2-bibliotheek van thqby (MIT-licentie) met de 32-bit WebView2Loader.dll |
| `Etiketten_autoprinter.exe` | De app (32-bit, moet 32-bit blijven: Pharmacom draait op 32-bit Java) |
| `Etiketten_autoprinter.ico` | Pictogram |
| `ui\venster.html`, `ui\icoon.png` | De interface (HTML/CSS in WebView2, de Edge-browser van Windows); wordt in de .exe meegenomen, dus na een wijziging opnieuw compileren |
| `Etiketten_autoprinter.ini` | Instellingen (opties, wachttijden, updatemap) |
| `Gegevens\` | Logbestand (alleen Pat.nr's) en `Geprint\<datum>.txt` (wie vandaag geprint is) |
| `Rapporten\` | Een CSV-rapport per ronde (opent in Excel) |
| `Hulpmiddelen\icoon.svg`, `icoon-klein.svg` | Ontwerp van het app-icoon (groot en vereenvoudigd voor 16-24 px) |
| `Hulpmiddelen\maak_icoon.ps1` | Maakt `Etiketten_autoprinter.ico` en `ui\icoon.png` uit de SVG's (rendert met Microsoft Edge) |
| `Hulpmiddelen\jab_tabellen_tonen.ps1` | Toont welke tabellen/kolommen Pharmacom laat zien (voor onderhoud) |
| `Archief\` | Oude versies (v4, v5.7.2 en de AutoHotkey v1-broncode van v5.8.0) |

## Bewaartermijnen

Bij het starten ruimt de app oude bestanden op (op basis van de wijzigingsdatum):

| Wat | Termijn | Instelling in de ini (`[Opslag]`) |
|---|---|---|
| Logbestanden | 30 dagen | — |
| Rapporten (bevatten naam en geboortedatum) | 90 dagen | `RapportDagen=90` |
| Register `Geprint\<datum>.txt` | 7 dagen | `RegisterDagen=7` |

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
letters) ernaast, of gebruik *Deze versie in de updatemap zetten*.
Gebruik altijd de **32-bit** base (`AutoHotkey32.exe`): Pharmacom draait op 32-bit Java.
De pagina, het pictogram en de WebView2Loader.dll worden in de .exe meegenomen.
De app heeft de WebView2 Runtime nodig; die zit standaard in Windows 10/11.

Het versienummer staat alleen in `AppVersie := "..."`; Ahk2Exe neemt het via de
`;@Ahk2Exe-Let`-regel daaronder over in de .exe. Controleer na het compileren de
versie (rechtsklik op de .exe → Eigenschappen → Details): de update-functie
vergelijkt die versie.

## Gegevens van alle computers

- **Logbestanden** staan in de gedeelde map (`Gegevens\Log`, één per dag per
  computer), ook van lokaal geïnstalleerde computers.
- **Toestand per computer** (`Gegevens\Computers\<computer>.ini`): laatst gedraaid
  en status per planning, laatst bekende apotheek, versie, pad en wanneer de app
  daar het laatst draaide. Alleen de computer zelf schrijft in zijn bestand (een
  gedeelde ini wordt bij elke wijziging helemaal herschreven: twee computers
  tegelijk = een wijziging kwijt). Oude waarden uit de gedeelde ini worden nog
  gelezen.
- **Instellingen → Computers:** overzicht met versie (oud = oranje), netwerkmap of
  lokaal, apotheek en laatst gezien.
- **Diagnose** telt de foutcodes van de afgelopen 30 dagen in de logs van alle
  computers, en het aantal afgeronde rondes.

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

## Op deze computer installeren

Start je de app vanaf de netwerkmap, dan toont Windows elke keer een
beveiligingswaarschuwing ("Bestand openen"). De app biedt daarom aan zichzelf op
de computer te installeren (`%LOCALAPPDATA%\Etiketten autoprinter`, met
snelkoppelingen op het bureaublad en in het startmenu; ook via Instellingen →
*Op deze computer installeren*). "Niet meer vragen" geldt per computer.

De lokale app heeft in zijn eigen ini alleen `[Update] Map` (de netwerkmap) en
`[Opslag] Map`. Al het andere (planning, groepen, opties) leest hij uit de ini in
de netwerkmap, gedeeld met de andere computers. Is de netwerkmap bij het starten
niet bereikbaar, dan gebruikt hij zijn eigen ini (zonder planning) en meldt dat.
Nieuwe versies in de netwerkmap worden bij het starten aangeboden. Stond *Starten
met Windows* aan, dan wijst die na het installeren naar de lokale app.

Alternatief zonder installeren: de server als *lokaal intranet* laten instellen
in Windows (Internetopties → Beveiliging → Lokaal intranet → Sites). Dat is een
beveiligingsinstelling; laat dat door de ICT doen.

## Updates via GitHub

Naast de updatemap kan de app nieuwe versies van GitHub halen. De repository staat
in `AppGitHub := "eigenaar/naam"` (hoofdbestand), of per ini in `[Update]
GitHub=eigenaar/naam`. Bij het starten kijkt de app eerst in de updatemap; staat daar
niets nieuwers, dan bij de nieuwste release op GitHub
(`api.github.com/repos/<repo>/releases/latest`). Een release moet twee bestanden
hebben: `Etiketten_autoprinter.exe` en `Etiketten_autoprinter.exe.sha256`. De
download komt in `%TEMP%\Etiketten autoprinter download` en wordt net zo
gecontroleerd als bij de updatemap. Downloaden gebruikt de proxy-instellingen van
Windows. Is GitHub niet bereikbaar, dan staat dat alleen in het log.

Een release maken: test de versie in `Bouw\`, en dan
`powershell -ExecutionPolicy Bypass -File Hulpmiddelen\maak_release.ps1` (met de
GitHub CLI `gh`, ingelogd met `gh auth login`; zonder `gh` toont het script de
stappen voor de website). De releasetekst komt uit `src\Wijzigingen.ahk`.

Wat nooit in de repository komt (zie `.gitignore`): `Gegevens\` (logs, register),
`Rapporten\` (namen en geboortedata), de ini (planning, computernamen), `.exe`'s en
controlewaarden (die gaan in de release), `Bouw\` en testuitvoer.

Wie de .exe van GitHub downloadt en vanuit Downloads of het bureaublad start, krijgt
de vraag *Op deze computer installeren*; die installatie haalt updates dan van
GitHub.

## Updates voor meerdere computers

Stel onder **Instellingen → Updates** een (netwerk)map in. Met *Deze versie in de
updatemap zetten* publiceer je de huidige versie; andere computers krijgen bij het
starten de vraag of ze willen bijwerken.

Bij het publiceren komt naast de .exe een controlewaarde
(`Etiketten_autoprinter.exe.sha256`). Een computer werkt alleen bij als de
gekopieerde .exe precies die controlewaarde heeft; een half gekopieerde of
beschadigde versie wordt geweigerd. Dit beschermt niet tegen iemand die beide
bestanden vervangt: geef daarom alleen beheerders schrijfrechten op de updatemap.
