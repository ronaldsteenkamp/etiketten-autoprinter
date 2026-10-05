# =====================================================================
# Schrijft de releasetekst voor versie <Versie> naar <Uit>: de regels van die
# versie uit src\Wijzigingen.ahk, plus installatie-uitleg. Gebruikt door
# maak_release.ps1 en door de GitHub-workflow (.github\workflows\release.yml).
# =====================================================================
param([Parameter(Mandatory = $true)][string]$Versie, [Parameter(Mandatory = $true)][string]$Uit)
$Map = Split-Path $PSScriptRoot -Parent
$Wijz = Get-Content (Join-Path $Map "src\Wijzigingen.ahk") -Raw -Encoding UTF8
$Tekst = "Versie $Versie"
$m = [regex]::Match($Wijz, '\["' + [regex]::Escape($Versie) + '",\s*\[(.*?)\]\]', 'Singleline')
if ($m.Success) {
    $Regels = [regex]::Matches($m.Groups[1].Value, '"((?:[^"]|"")*)"') | ForEach-Object { "- " + $_.Groups[1].Value.Replace('""', '"') }
    $Tekst = ($Regels -join "`n")
}
$Tekst += "`n`n**Installeren:** download ``Etiketten_autoprinter.exe``, start hem en kies *Op deze computer installeren*. Bestaande installaties bieden deze versie vanzelf aan. Zie de [README](../../#readme)."
$Tekst += "`n`nControlewaarde (SHA-256): zie ``Etiketten_autoprinter.exe.sha256``."
[IO.File]::WriteAllText($Uit, $Tekst, (New-Object Text.UTF8Encoding $false))
