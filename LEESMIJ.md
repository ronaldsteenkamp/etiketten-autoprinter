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
Ahk2Exe.exe /in "Etiketten_autoprinter.ahk" /out "Etiketten_autoprinter.exe" /base "<map van AutoHotkey v2>\AutoHotkey32.exe"
```
Gebruik altijd de **32-bit** base (`AutoHotkey32.exe`): Pharmacom draait op 32-bit Java.
De pagina, het pictogram en de WebView2Loader.dll worden in de .exe meegenomen.
De app heeft de WebView2 Runtime nodig; die zit standaard in Windows 10/11.

Het versienummer staat alleen in `AppVersie := "..."`; Ahk2Exe neemt het via de
`;@Ahk2Exe-Let`-regel daaronder over in de .exe. Controleer na het compileren de
versie (rechtsklik op de .exe → Eigenschappen → Details): de update-functie
vergelijkt die versie.

## Updates voor meerdere computers

Stel onder **Instellingen → Updates** een (netwerk)map in. Met *Deze versie in de
updatemap zetten* publiceer je de huidige versie; andere computers krijgen bij het
starten de vraag of ze willen bijwerken.

Bij het publiceren komt naast de .exe een controlewaarde
(`Etiketten_autoprinter.exe.sha256`). Een computer werkt alleen bij als de
gekopieerde .exe precies die controlewaarde heeft; een half gekopieerde of
beschadigde versie wordt geweigerd. Dit beschermt niet tegen iemand die beide
bestanden vervangt: geef daarom alleen beheerders schrijfrechten op de updatemap.
