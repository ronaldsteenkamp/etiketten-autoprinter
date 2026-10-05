# Etiketten autoprinter voor Pharmacom

Print automatisch etiketten voor de patiënten in de aanschrijfbuffer van
Pharmacom: per patiënt het dossier openen, controleren dat het de juiste patiënt
is, de bovenste regel van de eigen apotheek kiezen (eventueel alleen
"ASB: Deelbaar") en het barcode-etiket printen. Met planning per afdeling, een
proefronde en een rapport per ronde.

Een hulpmiddel voor apotheekmedewerkers; geen officieel product van
PharmaPartners of de apotheek. Gebruik op eigen verantwoordelijkheid en controleer
de etiketten.

## Installeren

1. Download `Etiketten_autoprinter.exe` bij de nieuwste
   [release](../../releases/latest).
2. Start hem. Windows kan waarschuwen omdat het bestand van internet komt: kies
   *Meer informatie* → *Toch uitvoeren* (of laat je ICT het bestand vrijgeven).
3. Kies **Op deze computer installeren**. De app komt in
   `%LOCALAPPDATA%\Etiketten autoprinter`, met een snelkoppeling op het bureaublad en
   in het startmenu. Het gedownloade bestand kun je daarna weggooien.
4. Eenmalig: klik in de app op **Koppeling inschakelen** en start Pharmacom
   opnieuw (dit zet de Java Access Bridge aan).

Nieuwe versies worden bij het starten van de app aangeboden; bijwerken gaat met één
klik (de download wordt gecontroleerd met de controlewaarde uit de release).

## Problemen en ideeën

Loop je ergens tegenaan of heb je een idee? In de app: **Vraag of idee** (het
ballonnetje rechtsboven) → **GitHub**. Daarmee open je hier een melding met de
versie en de foutcodes al ingevuld (nooit patiëntgegevens). Je kunt ook direct een
[issue](../../issues/new/choose) aanmaken.

## Meer

Uitleg over gebruik, planning, foutcodes, instellingen en onderhoud staat in
[LEESMIJ.md](LEESMIJ.md).

Nodig: Windows 10/11, Pharmacom (32-bit Java), de WebView2 Runtime (zit in Windows).

Licentie: [MIT](LICENSE).

## Code signing policy

Releases are built from this repository by GitHub Actions
([release.yml](.github/workflows/release.yml)), with a build provenance attestation
(`gh attestation verify Etiketten_autoprinter.exe --repo ronaldsteenkamp/etiketten-autoprinter`).
Once approved, Windows releases are signed:

*Free code signing provided by [SignPath.io](https://about.signpath.io), certificate
by [SignPath Foundation](https://signpath.org).*

- Committers and reviewers: [Ronald Steenkamp](https://github.com/ronaldsteenkamp)
- Approvers: [Ronald Steenkamp](https://github.com/ronaldsteenkamp)

**Privacy policy:** this program will not transfer any information to other
networked systems unless specifically requested by the user or the person
installing or operating it. The only automatic network access is reading the latest
release information from the GitHub API (api.github.com) and, when the user agrees,
downloading the new version from GitHub. Patient data stays on the local computer
and the pharmacy's own network folder.
