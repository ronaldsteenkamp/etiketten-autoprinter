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
- **Niets gepland vandaag:** is de app met Windows gestart (de snelkoppeling geeft
  `/opstart` mee) en staat er vandaag voor deze computer niets (meer) op de planning,
  dan toont hij na 10 seconden "Vandaag niets gepland" en sluit hij 30 seconden later
  (met **Openhouden** blijft hij open). Hij blijft wel open als de apotheek nog niet
  bekend is, als er gemiste rondes te melden zijn of als er al een ronde loopt. Met de
  hand gestart blijft de app altijd open. Een oude snelkoppeling zonder `/opstart`
  werkt de app zelf bij.
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

## Meer

- [docs/beheer.md](docs/beheer.md): updates, installeren, gegevens van alle computers, bewaartermijnen
- [docs/ICT.md](docs/ICT.md): inrichten op een nieuwe werkplek (mappen, rechten, checklist)
- [docs/ontwikkeling.md](docs/ontwikkeling.md): opbouw van de code, compileren, testen (nep-Pharmacom), releases
