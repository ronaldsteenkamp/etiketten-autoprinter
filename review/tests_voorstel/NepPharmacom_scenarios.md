# Voorgestelde scenario's voor `tests/NepPharmacom.js`

Doel: de kritieke paden uit `review/REVIEW.md` reproduceerbaar maken, eerst handmatig
(`tests\Test met nep-Pharmacom.cmd`), daarna in CI (zie `review/tests_ci_voorstel.yml`).

**Opzet.** Laat de nep-Pharmacom een scenario lezen uit een omgevingsvariabele
`NEP_SCENARIO` (bijvoorbeeld `java.lang.System.getenv("NEP_SCENARIO")`), zodat
`NepPharmacom.js` één bestand blijft. Leg per scenario vast welke regels in
`nep_geprint.txt` verwacht worden en welke foutcode in het log moet staan. Een
scenario is pas geslaagd als **beide** kloppen. Een stop zonder de verwachte code telt
als mislukt, net als een etiket dat er niet hoort.

| # | Scenario (`NEP_SCENARIO`) | Wat de nep doet | Verwacht gedrag van de app | Dekt |
|---|---|---|---|---|
| S1 | `verkeerde-patient` | Ctrl+B opent het dossier van de regel **onder** de geselecteerde | Stop met P08, geen etiket, rapport "Gestopt" | K4, H2 |
| S2 | `verkeerde-patient-zonder-controle` | Als S1, met `[Opties AN] DossierControleren=0` in de test-ini | Gewenst: weigeren te starten zonder dossiercontrole. Nu: etiket voor de verkeerde patiënt (vastleggen!) | K4 |
| S3 | `patnr-als-huisnummer` | Dossier van patiënt 900099 met het label "Dorpsstraat 900001", geselecteerd is 900001 | Gewenst: P08. Nu: bevestigd, etiket voor de verkeerde patiënt | H2 |
| S4 | `kort-patnr` | Pat.nr's 123 en 1234; dossier van 1234 voor geselecteerde 123 | P08 (de grens `(?!\d)` werkt). Regressietest | H2 |
| S5 | `twee-dossiers` | Er staat al een dossier (900002, historie open) achter het nieuwe dossier van 900001 | Gewenst: historie en selectie uit het venster van 900001. Nu: kijken welke tabel `Jab.ZoekTabellen` kiest | H1 |
| S6 | `focus-diefstal-voor-ctrlp` | 50 ms na het selecteren van de regel een eigen `JDialog` (niet modaal) naar voren | Optie "terughalen" uit: P02/P03, geen etiket. Aan: terughalen en dan dezelfde regel | H3 |
| S7 | `selectie-verspringt` | Na het selecteren van de AN-regel zet een timer de selectie op een andere regel (zoals een muisklik zonder blokkade) | Gewenst: P09 of opnieuw selecteren; nooit een etiket van een andere regel | H3 |
| S8 | `menu-item-ontbreekt` | Afdrukmenu zonder "Barcode etiket" | P10 "verscheen niet", niet geprint, niet in het register | – |
| S9 | `menu-item-uit` | "Barcode etiket" uitgeschakeld (`setEnabled(false)`) | P10 "kon niet gekozen worden" | – |
| S10 | `menu-sneltoets-anders` | Mnemonic van "Barcode etiket" = E | Kiest met Alt+E (de app leest de sneltoets uit) | – |
| S11 | `menu-te-laat` | Menu verschijnt pas na `MaxWachtPrint` + 500 ms | P10, en de late Escape mag het later geopende menu niet laten kiezen | – |
| S12 | `printfout-melding` | Na de keuze in het menu een modale `JOptionPane` "Printer niet bereikbaar" | Gewenst: stop met een nieuwe code, melding blijft staan, patiënt **niet** als geprint. Nu: Escape klikt hem weg en de patiënt telt als geprint | K2 |
| S13 | `melding-bij-dossier` | Ctrl+B toont eerst een modale melding ("Let op: CAVE") en dan pas het dossier | Gewenst: stoppen, melding laten staan. Nu: wordt als "dossier" gezien | M5 |
| S14 | `historie-oplopend` | Historie oplopend op datum (zoals nu in de nep, zie `historie()`) en een variant aflopend | Vastleggen welke regel gekozen wordt. Gewenst: altijd de nieuwste AN-regel, of stoppen als de sortering onbekend is | K3 |
| S15 | `geen-eigen-apotheek` | Alleen regels van BG | Overgeslagen "geen regel met Ap = AN", Escape, terug naar de buffer | – |
| S16 | `apotheek-deels` | Regels met Ap "AN2" en "AN" | Alleen "AN" (exacte vergelijking). Regressietest | – |
| S17 | `deelbaar-varianten` | Herhaal info "ASB: Deelbaar niet" boven "ASB: Deelbaar" | Gewenst: de tweede. Nu: de eerste | M9 |
| S18 | `historie-laadt-traag` | Historie eerst leeg, na 2,5 s gevuld | Wacht en kiest de juiste regel (MaxWachtLeeg 4000) | – |
| S19 | `historie-blijft-veranderen` | Elke 100 ms een regel erbij | P07 | – |
| S20 | `pharmacom-sluit` | Nep sluit zichzelf midden in een ronde | P01, blokkade weg, geen extra toetsen | – |
| S21 | `buffer-verandert` | Tijdens de ronde een regel bovenaan de buffer erbij | Elke patiënt wordt nog op Pat.nr gevonden. Er komt geen etiket voor de verkeerde regel | K4 |
| S22 | `fout-in-planning` | `[Test] Fout=dossier` en de ronde starten met `ETIKETTEN_TEST_START=T1/T1GUA/proef` | Gewenst: zoals het vangnet, dus blokkade weg en Ronde.Bezig uit. Nu: blokkade blijft staan (zie K1) | K1 |
| S23 | `dubbel-twee-computers` | Twee testexemplaren (andere `ETIKETTEN_TEST`-map, zelfde register) starten tegelijk dezelfde groep | Gewenst: geen patiënt twee keer. Nu: beide printen | M1 |
| S24 | `register-niet-schrijfbaar` | Register `Geprint\<datum>.txt` alleen-lezen maken | Gewenst: ronde stopt (registratie mislukt). Nu: gaat door, stil | M1 |
| S25 | `lege-groep` | T2/T2GUA (bestaat al) | Melding "Geen patiënten gevonden" gesloten, status *ok* met 0 | – |

**Ook meten in een lange ronde (bijv. 200 nep-patiënten):** het aantal handles en het
geheugen van `jjs.exe` en van de app (Taakbeheer of `Get-Process`), om lekken van
Java-objecten (JAB-handles) op te sporen. De code geeft ze zorgvuldig vrij, maar dat is
niet gemeten.
