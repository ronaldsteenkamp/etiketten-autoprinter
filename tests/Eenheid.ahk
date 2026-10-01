; Unit-tests voor de hulpfuncties (src\Hulp.ahk). Draaien met:
;   AutoHotkey32.exe tests\Eenheid.ahk
; Het resultaat komt in tests\uitvoer.txt (en in een melding).
#Requires AutoHotkey v2.0
#Include ..\src\Hulp.ahk

Uit := A_ScriptDir "\uitvoer.txt"
try FileDelete Uit
Leeg := A_Temp "\etiketten_leeg.txt"
FileOpen(Leeg, "w").Close()
Fouten := 0
T(Naam, Ok) {
    global Fouten
    if !Ok
        Fouten++
    FileAppend (Ok ? "OK   " : "FOUT ") Naam "`n", Uit, "UTF-8"
}

T("VersieNummer 6.0.0 > 5.8.0", VersieNummer("6.0.0") > VersieNummer("5.8.0"))
T("VersieNummer 5.10.0 > 5.9.9", VersieNummer("5.10.0") > VersieNummer("5.9.9"))
T("VersieNummer leeg = 0", VersieNummer("") = 0)
T("VersieNummer 5.8.1.0", VersieNummer("5.8.1.0") = 5008001)
T("IsDatum 25-08-1963", IsDatum("25-08-1963"))
T("IsDatum 5-8-63", IsDatum("5-8-63"))
T("IsDatum 1963-08-25", IsDatum("1963-08-25"))
T("IsDatum tekst", !IsDatum("onbekend"))
T("FmtTijd 75", FmtTijd(75) = "1:15")
T("UriDecode", UriDecode("C%3A%5CMap%20met%20spatie%5C%C3%AB") = "C:\Map met spatie\" Chr(235))
T("UriEncode", UriEncode("Hoi Ronald,`nvraag: ë &?") = "Hoi%20Ronald%2C%0Avraag%3A%20%C3%AB%20%26%3F")
T("UriEncode terug", UriDecode(UriEncode("a b/ë")) = "a b/ë")
B := Buffer(3), StrPut("Man", B, 3, "CP0")
T("Base64", Base64(B) = "TWFu")
T("Json object", Json({a: 'x"y', b: [1, "2"]}) = '{"a":"x\"y","b":["1","2"]}')
T("Json Map", Json(Map("k", "v")) = '{"k":"v"}')
T("Json regeleinde", Json("a`nb") = '"a\nb"')
T("Sha256 leeg bestand", Sha256(Leeg) = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
T("Sha256 ontbrekend bestand", Sha256(A_Temp "\bestaat-niet-etiketten.txt") = "")

try FileDelete Leeg
MsgBox Fouten ? Fouten " test(s) mislukt, zie " Uit : "Alle tests geslaagd.", "Eenheid", Fouten ? "Icon!" : "Iconi"
