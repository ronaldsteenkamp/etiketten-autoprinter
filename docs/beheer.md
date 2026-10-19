# Etiketten autoprinter: beheer

Voor wie de app in de apotheek beheert: updates, installeren, gegevens van alle
computers en bewaartermijnen. Inrichten op een nieuwe werkplek (mappen, rechten): [ICT.md](ICT.md).
Gebruik: [LEESMIJ.md](../LEESMIJ.md). Ontwikkelen en releases: [ontwikkeling.md](ontwikkeling.md).

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

## Updates voor meerdere computers

Onder **Instellingen → Netwerkmap en updates** staat de netwerkmap waar de app
vandaan komt. Die is tegelijk de map met de gedeelde planning en instellingen (zie
*Op deze computer installeren*), dus laat hem staan tenzij de map verhuist. Daar
zie je ook waar de app naar updates kijkt en wanneer het laatst (met de uitkomst),
en kun je *Nu controleren op updates*.

Een nieuwe versie zet `Hulpmiddelen\maak_release.ps1` op GitHub én in de
netwerkmap (zie *Een release maken* in [ontwikkeling.md](ontwikkeling.md)). Lokaal geïnstalleerde computers krijgen bij het
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

## Bewaartermijnen

Bij het starten en daarna elke 6 uur (niet tijdens een ronde) ruimt de app oude
bestanden op (op basis van de wijzigingsdatum); hoeveel staat in het log:

| Wat | Termijn | Instelling in de ini (`[Opslag]`) |
|---|---|---|
| Logbestanden | 30 dagen | — |
| Rapporten (bevatten naam en geboortedatum) | 90 dagen | `RapportDagen=90` |
| Register `Geprint\<datum>.txt` | 7 dagen | `RegisterDagen=7` |
| Claims `Geprint\Bezig\*.txt` | 2 dagen | — |
