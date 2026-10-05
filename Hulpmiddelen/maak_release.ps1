# =====================================================================
# Nieuwe versie uitbrengen.
#
# Standaard (GitHub bouwt):
#   1. controleert dat alles vastgelegd en gepusht is
#   2. zet de tag v<AppVersie> en pusht die; GitHub (.github\workflows\
#      release.yml) draait dan de tests, bouwt de .exe, ondertekent hem (als
#      SignPath is ingesteld) en maakt de release
#   3. wacht op die bouw, downloadt de release, controleert de controlewaarde
#      en zet de .exe met controlewaarde in de netwerkmap (reserve)
#
# Met -Lokaal (als GitHub Actions niet beschikbaar is): de geteste .exe uit
# Bouw\ wordt hier de release (zonder ondertekening en herkomstbewijs).
#
# Nodig: GitHub CLI (gh), ingelogd met "gh auth login", en git.
#   powershell -ExecutionPolicy Bypass -File Hulpmiddelen\maak_release.ps1 [-Lokaal]
# =====================================================================
param([switch]$Lokaal)
$ErrorActionPreference = "Stop"
$Map = Split-Path $PSScriptRoot -Parent
# Draagbare git/gh (zie LEESMIJ) ook vinden als ze niet in PATH staan
$env:Path = "$env:LOCALAPPDATA\Programs\MinGit\cmd;$env:LOCALAPPDATA\Programs\gh\bin;" + $env:Path
foreach ($c in "git", "gh") { if (!(Get-Command $c -ErrorAction SilentlyContinue)) { throw "$c niet gevonden" } }
Push-Location $Map
try {
    $Versie = ([regex]::Match((Get-Content Etiketten_autoprinter.ahk -Raw), 'global AppVersie := "([^"]+)"')).Groups[1].Value
    if (!$Versie) { throw "AppVersie niet gevonden" }
    $Tag = "v$Versie"
    Write-Host "Versie $Versie"

    # Netwerkmap (= deze projectmap) bijwerken: reserve als GitHub niet
    # bereikbaar is, voor computers die vanaf de netwerkmap starten en voor
    # versies van voor 6.10. Eerst de controlewaarde weg, zodat niemand een
    # half gekopieerde .exe installeert.
    function NaarNetwerkmap($Exe, $Hash) {
        $Doel = Join-Path $Map "Etiketten_autoprinter.exe"
        if (Test-Path "$Doel.sha256") { [IO.File]::Delete("$Doel.sha256") }
        Copy-Item $Exe $Doel -Force
        if ((Get-FileHash $Doel -Algorithm SHA256).Hash.ToLower() -ne $Hash) { throw "Kopie in de netwerkmap klopt niet; controlewaarde niet gezet" }
        [IO.File]::WriteAllText("$Doel.sha256", $Hash, (New-Object Text.UTF8Encoding $false))
        Write-Host "Netwerkmap bijgewerkt naar $Versie."
    }

    if ($Lokaal) {
        $Exe = Join-Path $Map "Bouw\Etiketten_autoprinter.exe"
        if (!(Test-Path $Exe)) { throw "Geen $Exe. Compileer eerst naar Bouw\." }
        if (-not (Get-Item $Exe).VersionInfo.FileVersion.StartsWith($Versie)) { throw "Bouw\ bevat niet versie $Versie" }
        $Hash = (Get-FileHash $Exe -Algorithm SHA256).Hash.ToLower()
        [IO.File]::WriteAllText("$Exe.sha256", $Hash, (New-Object Text.UTF8Encoding $false))
        & "$PSScriptRoot\release_tekst.ps1" -Versie $Versie -Uit "$env:TEMP\etiketten_notes.md"
        gh release create $Tag $Exe "$Exe.sha256" --title "Versie $Versie" --notes-file "$env:TEMP\etiketten_notes.md"
        if ($LASTEXITCODE) { throw "gh release create mislukt" }
        NaarNetwerkmap $Exe $Hash
        return
    }

    # 1. Alles vastgelegd en gepusht?
    if (git status --porcelain) { throw "Er zijn nog niet vastgelegde wijzigingen (git status). Eerst committen." }
    git fetch -q origin
    if ((git rev-parse HEAD) -ne (git rev-parse origin/main)) { throw "main is niet gelijk aan GitHub. Eerst pushen (git push)." }
    if (git tag -l $Tag) { throw "Tag $Tag bestaat al. Verhoog AppVersie." }

    # 2. Tag zetten: GitHub bouwt
    git tag -a $Tag -m "Versie $Versie"
    git push -q origin $Tag
    Write-Host "Tag $Tag gepusht; GitHub bouwt nu de release..."
    Start-Sleep 10
    $Run = gh run list --workflow release.yml --branch $Tag --limit 1 --json databaseId --jq ".[0].databaseId"
    if ($Run) { gh run watch $Run --exit-status | Out-Null; if ($LASTEXITCODE) { throw "De bouw op GitHub is mislukt: gh run view $Run --log-failed" } }

    # 3. Release downloaden en in de netwerkmap zetten
    $Dl = Join-Path $env:TEMP "etiketten_release_$Versie"
    if (Test-Path $Dl) { Get-ChildItem $Dl | ForEach-Object { [IO.File]::Delete($_.FullName) } }
    gh release download $Tag --dir $Dl --pattern "Etiketten_autoprinter.exe*" --clobber
    $Exe = Join-Path $Dl "Etiketten_autoprinter.exe"
    $Hash = (Get-FileHash $Exe -Algorithm SHA256).Hash.ToLower()
    if ($Hash -ne (Get-Content "$Exe.sha256" -Raw).Trim()) { throw "Controlewaarde van de release klopt niet" }
    $Sig = Get-AuthenticodeSignature $Exe
    Write-Host ("Handtekening: " + $(if ($Sig.Status -eq "Valid") { $Sig.SignerCertificate.Subject } else { "geen (" + $Sig.Status + ")" }))
    gh attestation verify $Exe --repo (gh repo view --json nameWithOwner --jq .nameWithOwner) | Out-Null
    Write-Host ("Herkomstbewijs: " + $(if ($LASTEXITCODE) { "NIET bevestigd" } else { "bevestigd (gebouwd door GitHub uit deze repository)" }))
    NaarNetwerkmap $Exe $Hash
    Write-Host "Klaar: release $Tag staat op GitHub en in de netwerkmap."
} finally { Pop-Location }
