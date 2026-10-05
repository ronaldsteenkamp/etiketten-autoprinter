# =====================================================================
# Draait alle unit-tests zonder meldingen (/ci) en geeft exitcode 1 als er
# iets mislukt. Gebruikt op GitHub (Actions) en lokaal:
#   powershell -ExecutionPolicy Bypass -File tests\alle_tests.ps1 -Ahk "<pad>\AutoHotkey32.exe"
# =====================================================================
param([Parameter(Mandatory = $true)][string]$Ahk)
$ErrorActionPreference = "Stop"
$Map = $PSScriptRoot
$Mislukt = 0
foreach ($Test in "Eenheid", "Planning", "Update") {
    $Fout = Join-Path $env:TEMP "test_$Test.err"
    $p = Start-Process $Ahk -ArgumentList "/ErrorStdOut `"$Map\$Test.ahk`" /ci" -PassThru -Wait -NoNewWindow -RedirectStandardError $Fout
    $Uitvoer = Get-ChildItem $Map -Filter "uitvoer*.txt" | Where-Object { $_.Name -eq "uitvoer.txt" -and $Test -eq "Eenheid" -or $_.Name -eq "uitvoer_$($Test.ToLower()).txt" }
    $Regels = if ($Uitvoer) { Get-Content $Uitvoer.FullName -Encoding UTF8 } else { @() }
    $Fouten = @($Regels | Where-Object { $_ -like "FOUT*" })
    $Script = Get-Content $Fout -ErrorAction SilentlyContinue
    if ($p.ExitCode -ne 0 -or $Fouten.Count -or $Script -or !$Regels.Count) {
        $Mislukt++
        Write-Host "MISLUKT: $Test (exitcode $($p.ExitCode), $($Regels.Count) tests, $($Fouten.Count) fout)"
        $Fouten | ForEach-Object { Write-Host "  $_" }
        $Script | ForEach-Object { Write-Host "  $_" }
    } else {
        Write-Host "OK: $Test ($($Regels.Count) tests)"
    }
}
if ($Mislukt) { Write-Host "$Mislukt testbestand(en) mislukt"; exit 1 }
Write-Host "Alle tests geslaagd"
