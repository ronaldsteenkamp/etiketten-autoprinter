; Unit-tests voor de updates via GitHub (antwoord van de GitHub-API uitlezen).
; Draaien met:
;   AutoHotkey32.exe tests\Update.ahk
; Het resultaat komt in tests\uitvoer_update.txt (en in een melding).
#Requires AutoHotkey v2.0
#Warn All, Off
#Include ..\src\Hulp.ahk
#Include ..\src\Instellingen.ahk
#Include ..\src\Update.ahk

Uit := A_ScriptDir "\uitvoer_update.txt"
try FileDelete Uit
Fouten := 0
T(Naam, Ok) {
    global Fouten
    if !Ok
        Fouten++
    FileAppend (Ok ? "OK   " : "FOUT ") Naam "`n", Uit, "UTF-8"
}

; Ingekort antwoord zoals https://api.github.com/repos/<eigenaar>/<naam>/releases/latest
J := '
(
{
  "url": "https://api.github.com/repos/voorbeeld/etiketten/releases/1",
  "tag_name": "v6.10.0",
  "name": "Versie 6.10.0",
  "assets": [
    { "name": "Etiketten_autoprinter.exe.sha256",
      "browser_download_url": "https://github.com/voorbeeld/etiketten/releases/download/v6.10.0/Etiketten_autoprinter.exe.sha256" },
    { "name": "Etiketten_autoprinter.exe",
      "browser_download_url": "https://github.com/voorbeeld/etiketten/releases/download/v6.10.0/Etiketten_autoprinter.exe" }
  ]
}
)'
R := Update.LeesRelease(J)
T("Release gelezen", IsObject(R))
T("Versie zonder v", IsObject(R) && R.versie = "6.10.0")
T("Exe-adres", IsObject(R) && R.exe ~= "/Etiketten_autoprinter\.exe$")
T("Sha-adres", IsObject(R) && R.sha ~= "\.exe\.sha256$")
T("Nieuwer dan 6.9.1", IsObject(R) && VersieNummer(R.versie) > VersieNummer("6.9.1"))
T("Zonder controlewaarde = niet bruikbaar", !IsObject(Update.LeesRelease(StrReplace(J, "Etiketten_autoprinter.exe.sha256", "iets.txt"))))
T("Zonder tag = niet bruikbaar", !IsObject(Update.LeesRelease(StrReplace(J, "tag_name", "naam_tag"))))
T("Tag zonder v", Update.LeesRelease(StrReplace(J, '"v6.10.0"', '"6.10.0"')).versie = "6.10.0")
T("Foutmelding van GitHub = niet bruikbaar", !IsObject(Update.LeesRelease('{"message":"Not Found"}')))

; Zonder melding (bijv. op GitHub): met /ci de uitkomst als exitcode
if A_Args.Length && A_Args[1] = "/ci"
    ExitApp Fouten ? 1 : 0
MsgBox Fouten ? Fouten " test(s) mislukt, zie " Uit : "Alle updatetests geslaagd.", "Update", Fouten ? "Icon!" : "Iconi"
