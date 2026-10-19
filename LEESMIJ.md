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
  foute planning staat in de lijst als "Klopt niet" (code `[L12]`). Na het zoeken
  controleert de app dat de lijst (kolom Afd) alleen de gekozen afdeling bevat
  (`[L03]`). Is de kolom Afd niet te vinden, dan print hij niet (`[L13]`).
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

"Alleen ASB: Deelbaar" en het item in het afdrukmenu gelden per ingelogde
apotheek (ini-sectie `[Opties AN]`; in Instellingen gemarkeerd met de
apotheekcode). De dossiercontrole op Pat.nr staat altijd aan en is niet uit te
zetten (`DossierControleren` en `DossierAlleenPatnr` in de ini worden genegeerd). Staat daar niets, dan geldt de
algemene waarde. Wachttijden, geluid, venster bovenop (*tijdens het printen*,
standaard aan; *altijd*, standaard uit), bevestigen en toetsenbord
blokkeren horen bij de computer.

Na een update toont de app één keer **Wat is er nieuw** (lijst in
`src\Wijzigingen.ahk`; bij een nieuwe versie daar een regel toevoegen).

## Wat de app per patiënt doet

0. Zet een **claim** op de patiënt (`Gegevens\Geprint\Bezig\<datum> <Pat.nr>.txt`,
   exclusief aangemaakt) en leest daarna het register van vandaag opnieuw. Is de
   patiënt intussen geprint (bijv. op een andere computer), dan wordt hij
   overgeslagen. Heeft een andere ronde de claim, dan ook (zie *Register en claim*).
1. Zoekt de patiënt op Pat.nr in de aanschrijfbuffer en selecteert hem direct via de
   koppeling (zoals een klik; lukt dat niet, dan met pijltjestoetsen) en controleert
   de selectie.
2. Ctrl+B (dossier) → F4 (medicatiehistorie) → pijl omhoog. Vanaf het dossier gaan
   alle toetsen alleen naar het dossiervenster; staat er een ander venster voor
   (ook een melding van Pharmacom zelf), dan stopt de app (`[P03]`). De
   medicatiehistorie wordt alleen in het dossiervenster gezocht.
3. Controleert dat het dossier van de juiste patiënt is (Pat.nr in het dossiervenster).
   Deze controle staat altijd aan.
4. Selecteert de **bovenste** regel met Ap = de ingelogde apotheek (rechtsonder in
   Pharmacom, bijv. `AN - RS - 183`) en, als die optie aan staat, Herhaal info
   `ASB: Deelbaar`. Ook die regel wordt direct via de koppeling geselecteerd.
   Vlak voor het printen controleert de app opnieuw: de selectie staat in beide
   helften op die regel, de bovenste regels zijn niet veranderd, en op de regel
   staan nog dezelfde Ap, Herhaal info en etiketnaam. Zo niet: stoppen (`[P09]`).
5. Ctrl+P → wacht tot het afdrukmenu in het dossier zichtbaar is → kiest
   **Barcode etiket** (Alt+B) → wacht tot het menu dicht is → Escape → zet de
   patiënt in het register (vanaf Alt+B telt hij als geprint) en wacht tot de
   aanschrijfbuffer terug is. Daarna gaat de claim weer weg.

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

**Register en claim:** het register van vandaag (`Gegevens\Geprint\<datum>.txt`)
faalt nooit stil. Is de map niet bereikbaar, dan werkt de app de lijst niet bij en
start er geen ronde (`[P12]`); halverwege een ronde stopt hij. Kan een geprint
etiket niet in het register gezet worden, dan stopt de ronde (`[P12]`). De
registratie blijft dan in het geheugen en wordt weggeschreven zodra de map weer
bereikbaar is; de claim van die patiënt blijft staan, zodat andere computers hem
ook overslaan. Een claim die blijft staan (de app liep vast, of het register lukte
niet) betekent: die dag wordt deze patiënt overgeslagen met de melding *staat op
'bezig' bij <computer>*. Controleer dan of er een etiket is; daarna kan de
beheerder het claimbestand weghalen. Claims worden na 2 dagen opgeruimd.
Zo'n patiënt staat in de lijst al als *Controleren* ("Staat op 'bezig' bij
<computer>") en wordt niet aangevinkt. Ook als de waakhond de app afsloot tijdens
het printen, blijft de claim staan: dan is het etiket misschien wel geprint maar niet
geregistreerd, en print geen enkele ronde hem die dag nog eens.

**Schaduwmodus (nog geen stop, alleen in het log):** twee strengere controles
draaien mee en schrijven alleen in het log wat ze vinden. Zodra de logs laten zien
dat ze in de echte Pharmacom altijd kloppen, worden het echte controles:
- `SCHADUW Pat.nr-veld: gevonden / NIET gevonden`: staat het Pat.nr in het
  Pat.nr-veld van het dossier ("Pat.nr: 123", of label "Pat.nr" met de waarde
  erachter), en niet alleen ergens anders in het dossier?
- `SCHADUW sortering Laatste V/A: aflopend / NIET aflopend`: staat de
  medicatiehistorie op Laatste V/A, nieuwste bovenaan (bovenste 15 regels)? Zo niet,
  dan is "de bovenste regel" niet de nieuwste.

Tellen in de logs van alle computers (PowerShell, in `Gegevens\Log`):
`Select-String -Path *.txt -Pattern 'SCHADUW' | Group-Object { $_.Line -replace '^.*SCHADUW ([^:]+): (\S+( \S+)?).*$','$1: $2' } | Select Count, Name`

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
log, het rapport en de planningstatus. Een stop in de ronde krijgt zijn code
expliciet mee (`Ronde.Fout("P11", "tekst")`); het gedrag (zelf verder, terugzetten)
hangt alleen van die code af, niet van de tekst. Voor de planning en voor oude logs
herkent `FoutCode()` in `src\Hulp.ahk` de code nog aan de tekst; codes worden nooit
hergebruikt.

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
| P09 | Regel in de medicatiehistorie kon niet geselecteerd worden, of klopte vlak voor het printen niet meer |
| P10 | Afdrukmenu: verscheen niet, item niet te kiezen of sloot niet |
| P11 | Pharmacom keerde niet terug naar de aanschrijfbuffer |
| P12 | Register van geprinte patiënten niet bereikbaar of niet bij te werken |
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
| L13 | Planning: kolom Afd niet gevonden, dus niet te controleren dat de lijst alleen die afdeling bevat |
| X99 | Onverwachte fout in de app (vangnet) |

Of er echt een etiket uit de printer kwam, kan de app niet controleren: de
etikettenprinters (STAR/Zebra) worden via de Pharmacom-server aangestuurd, niet
via Windows. Het etiket zelf is de bevestiging.

Het dossier telt alleen als juist als het **Pat.nr** erin staat. Dat is niet uit te
zetten (de vroegere opties *Dossier controleren* en *Dossier alleen op Pat.nr
controleren* zijn vervallen).

Welk item uit het afdrukmenu gekozen wordt, staat in de ini onder `[Opties]` als
`PrintMenu=Barcode etiket` (exact de tekst uit het menu, bijv. `Afleveretiket`).
De sneltoets leest de app zelf uit Pharmacom.

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
| `tests\*.ahk`, `tests\alle_tests.ps1` | Unit-tests: hulpfuncties (`Eenheid`), planning, updates, register en claims (`Register`), beslisregels (`Regels`) |
| `src\lib\` | WebView2-bibliotheek van thqby (MIT-licentie) met de 32-bit WebView2Loader.dll |
| `Etiketten_autoprinter.exe` | De app (32-bit, moet 32-bit blijven: Pharmacom draait op 32-bit Java) |
| `Etiketten_autoprinter.ico` | Pictogram |
| `ui\venster.html`, `ui\icoon.png` | De interface (HTML/CSS in WebView2, de Edge-browser van Windows); wordt in de .exe meegenomen, dus na een wijziging opnieuw compileren |
| `Etiketten_autoprinter.ini` | Instellingen (opties, wachttijden, updatemap) |
| `Gegevens\` | Logbestand (Pat.nr's, geen namen; venstertitels met cijfers of een komma worden "(titel verborgen)"), `Geprint\<datum>.txt` (wie vandaag geprint is) en `Geprint\Bezig\` (claims van patiënten die nu verwerkt worden) |
| `Rapporten\` | Een CSV-rapport per ronde (opent in Excel) |
| `Hulpmiddelen\icoon.svg`, `icoon-klein.svg` | Ontwerp van het app-icoon (groot en vereenvoudigd voor 16-24 px) |
| `Hulpmiddelen\maak_icoon.ps1` | Maakt `Etiketten_autoprinter.ico` en `ui\icoon.png` uit de SVG's (rendert met Microsoft Edge) |
| `Hulpmiddelen\jab_tabellen_tonen.ps1` | Toont welke tabellen/kolommen Pharmacom laat zien (voor onderhoud) |
| `Archief\` | Oude versies (v4, v5.7.2 en de AutoHotkey v1-broncode van v5.8.0) |

## Bewaartermijnen

Bij het starten en daarna elke 6 uur (niet tijdens een ronde) ruimt de app oude
bestanden op (op basis van de wijzigingsdatum); hoeveel staat in het log:

| Wat | Termijn | Instelling in de ini (`[Opslag]`) |
|---|---|---|
| Logbestanden | 30 dagen | — |
| Rapporten (bevatten naam en geboortedatum) | 90 dagen | `RapportDagen=90` |
| Register `Geprint\<datum>.txt` | 7 dagen | `RegisterDagen=7` |
| Claims `Geprint\Bezig\*.txt` | 2 dagen | — |

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

**Foutscenario's (groep T3 / T3FOUT).** Per patiënt één ding dat mis kan gaan. Vink
alleen de patiënt aan die je wilt testen (de ronde stopt bij een fout) en kijk of de
uitkomst klopt; na een stop moet Pharmacom weer op de aanschrijfbuffer staan en mag
er niets in `nep_geprint.txt` bij gekomen zijn.

| Pat.nr | Scenario | Verwacht |
|---|---|---|
| 900031 | Dossier toont een ander Pat.nr | Stop `[P08]`, niets geprint |
| 900032 | Ctrl+B opent een melding in plaats van het dossier | Stop `[P07]` (geen historie in dat venster), niets geprint |
| 900033 | Historie ververst bij het selecteren (nieuwe bovenste regel) | Stop `[P09]`, niets geprint |
| 900034 | Ctrl+P doet niets | Stop `[P10]`, niets geprint |
| 900035 | Historie oudste bovenaan | Geprint (SIMVASTATINE); log: `SCHADUW sortering Laatste V/A: NIET aflopend` |
| 900036 | Pat.nr niet in een Pat.nr-veld | Geprint; log: `SCHADUW Pat.nr-veld: NIET gevonden` |
| 900037 | Historie verschijnt pas na 2,5 s | Geprint (METFORMINE) |

Bij alle gewone patiënten (T1, T2) moet het log `SCHADUW Pat.nr-veld: gevonden` en
`SCHADUW sortering Laatste V/A: aflopend` geven.

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

## Updates voor meerdere computers

Onder **Instellingen → Netwerkmap en updates** staat de netwerkmap waar de app
vandaan komt. Die is tegelijk de map met de gedeelde planning en instellingen (zie
*Op deze computer installeren*), dus laat hem staan tenzij de map verhuist. Daar
zie je ook waar de app naar updates kijkt en wanneer het laatst (met de uitkomst),
en kun je *Nu controleren op updates*.

Een nieuwe versie zet `Hulpmiddelen\maak_release.ps1` op GitHub én in de
netwerkmap (zie *Een release maken*). Lokaal geïnstalleerde computers krijgen bij het
starten (en daarna elke 4 uur een melding) de vraag of ze willen bijwerken;
computers die vanaf de netwerkmap starten hebben hem na een herstart. De knop *Deze
versie in de updatemap zetten* is vervallen (`maak_release.ps1 -Lokaal` doet dat
in noodgevallen).

Een app die vanaf de netwerkmap zelf draait, werkt **niet** bij van GitHub: dat zou
de gedeelde .exe vervangen zonder controlewaarde, waarna de lokale installaties de
update weigeren.

Bij het publiceren komt naast de .exe een controlewaarde
(`Etiketten_autoprinter.exe.sha256`). Een computer werkt alleen bij als de
gekopieerde .exe precies die controlewaarde heeft; een half gekopieerde of
beschadigde versie wordt geweigerd. Dit beschermt niet tegen iemand die beide
bestanden vervangt: geef daarom alleen beheerders schrijfrechten op de updatemap.

**Handtekening:** vóór het installeren kijkt de app naar de digitale handtekening
(Authenticode, via PowerShell `Get-AuthenticodeSignature`) en zet die in het log. Is
de draaiende versie zelf geldig ondertekend (zodra SignPath actief is), dan moet de
nieuwe versie geldig ondertekend zijn door dezelfde uitgever, anders weigert de app
de update. Zolang de app niet ondertekend is, wordt alleen gelogd. Let op: kan
PowerShell op een computer niet starten, dan kan een ondertekende app daar niet meer
bijwerken (status "onbekend").
