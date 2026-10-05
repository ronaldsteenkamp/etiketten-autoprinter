# =====================================================================
# Maakt een GitHub-release van de geteste versie in Bouw\:
#   - controlewaarde Bouw\Etiketten_autoprinter.exe.sha256
#   - release v<versie> met de .exe en de controlewaarde, en als tekst de
#     regels van die versie uit src\Wijzigingen.ahk
# Nodig: GitHub CLI (gh), ingelogd met "gh auth login". Zonder gh toont het
# script wat je met de hand op GitHub moet doen.
#
# Gebruik (vanuit de projectmap):
#   powershell -ExecutionPolicy Bypass -File Hulpmiddelen\maak_release.ps1
# =====================================================================
$ErrorActionPreference = "Stop"
$Map = Split-Path $PSScriptRoot -Parent
$Exe = Join-Path $Map "Bouw\Etiketten_autoprinter.exe"
if (!(Test-Path $Exe)) { throw "Geen $Exe. Compileer eerst naar Bouw\ (zie LEESMIJ.md)." }

$Versie = (Get-Item $Exe).VersionInfo.FileVersion -replace '^(\d+\.\d+\.\d+).*', '$1'
$Sha = "$Exe.sha256"
$Hash = (Get-FileHash $Exe -Algorithm SHA256).Hash.ToLower()
[IO.File]::WriteAllText($Sha, $Hash, (New-Object Text.UTF8Encoding $false))
Write-Host "Versie $Versie, controlewaarde $Hash"

# Releasetekst: de regels van deze versie uit Wijzigingen.ahk
$Wijz = Get-Content (Join-Path $Map "src\Wijzigingen.ahk") -Raw -Encoding UTF8
$Notes = "Versie $Versie"
$m = [regex]::Match($Wijz, '\["' + [regex]::Escape($Versie) + '",\s*\[(.*?)\]\]', 'Singleline')
if ($m.Success) {
    $Regels = [regex]::Matches($m.Groups[1].Value, '"((?:[^"]|"")*)"') | ForEach-Object { "- " + $_.Groups[1].Value.Replace('""', '"') }
    $Notes = ($Regels -join "`n") + "`n`nInstalleren: download Etiketten_autoprinter.exe, start hem en kies 'Op deze computer installeren'. Zie de README."
}
$NotesBestand = Join-Path $env:TEMP "etiketten_release_notes.md"
[IO.File]::WriteAllText($NotesBestand, $Notes, (New-Object Text.UTF8Encoding $false))

if (Get-Command gh -ErrorAction SilentlyContinue) {
    Push-Location $Map
    try { gh release create "v$Versie" $Exe $Sha --title "Versie $Versie" --notes-file $NotesBestand }
    finally { Pop-Location }
    Write-Host "Release v$Versie aangemaakt. De app biedt hem aan bij de volgende start."
} else {
    Write-Host ""
    Write-Host "GitHub CLI (gh) niet gevonden. Met de hand op GitHub:"
    Write-Host "  1. Releases -> Draft a new release, tag: v$Versie, titel: Versie $Versie"
    Write-Host "  2. Sleep deze twee bestanden erin:"
    Write-Host "       $Exe"
    Write-Host "       $Sha"
    Write-Host "  3. Tekst: zie $NotesBestand"
    Write-Host "  4. Publish release"
}
