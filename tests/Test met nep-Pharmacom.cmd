@echo off
rem ====================================================================
rem Test met nep-Pharmacom: start de nep-Pharmacom (NepPharmacom.js, met
rem jjs.exe uit de Java van Pharmacom) en de app in testmodus.
rem
rem Testmodus: de app zoekt jjs.exe in plaats van Pharmacom (javaw.exe) en
rem gebruikt eigen instellingen en gegevens in %TEMP%\Etiketten autoprinter test
rem (de echte planning, het register en de logs worden niet geraakt). Hij mag
rem naast de gewone app draaien.
rem
rem Optioneel: meteen een ronde starten, bijv.
rem   "Test met nep-Pharmacom.cmd" T1/T1GUA/proef
rem   "Test met nep-Pharmacom.cmd" T1/T1GUA/print
rem Geprinte (nep)etiketten: tests\nep_geprint.txt
rem ====================================================================
setlocal
set "JJS="
for /d %%D in ("C:\PharmaPartners\jres\oracle\*") do if exist "%%D\bin\jjs.exe" set "JJS=%%D\bin\jjs.exe"
if not defined JJS (
    echo jjs.exe niet gevonden in C:\PharmaPartners\jres\oracle\*\bin
    pause
    exit /b 1
)
echo Nep-Pharmacom starten met %JJS%
start "Nep-Pharmacom" /min "%JJS%" "%~dp0NepPharmacom.js"
timeout /t 4 /nobreak >nul
set "ETIKETTEN_TEST=1"
set "ETIKETTEN_TEST_START=%~1"
rem Een nieuwe, nog niet gepubliceerde versie staat in Bouw\
set "EXE=%~dp0..\Etiketten_autoprinter.exe"
if exist "%~dp0..\Bouw\Etiketten_autoprinter.exe" set "EXE=%~dp0..\Bouw\Etiketten_autoprinter.exe"
start "" "%EXE%"
endlocal
