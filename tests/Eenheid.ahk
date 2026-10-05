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
T("Titel aanschrijfbuffer", TitelIsBuffer("Pharmacom - Aanschrijfbuffer"))
T("Titel dashboard", !TitelIsBuffer("Pharmacom - Apotheek dashboard"))
T("Titel zonder schermnaam", TitelIsBuffer("Pharmacom"))
T("Json object", Json({a: 'x"y', b: [1, "2"]}) = '{"a":"x\"y","b":["1","2"]}')
T("Json Map", Json(Map("k", "v")) = '{"k":"v"}')
T("Json regeleinde", Json("a`nb") = '"a\nb"')
T("Sha256 leeg bestand", Sha256(Leeg) = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
T("Sha256 ontbrekend bestand", Sha256(A_Temp "\bestaat-niet-etiketten.txt") = "")
T("Foutcode gebruiker", FoutCode("gestopt door gebruiker") = "G01")
T("Foutcode niet terug", FoutCode("Pharmacom keerde niet terug naar de aanschrijfbuffer") = "P11")
T("Foutcode na printen niet terug", FoutCode("Pharmacom keerde na het printen niet terug naar de aanschrijfbuffer") = "P11")
T("Foutcode niet actief", FoutCode("Pharmacom was niet meer het actieve venster") = "P02")
T("Foutcode dossier niet actief", FoutCode("het dossier was niet meer het actieve venster") = "P03")
T("Foutcode buffer niet open", FoutCode("de aanschrijfbuffer ging niet open (Ctrl+F11)") = "P04")
T("Foutcode afdrukmenu", FoutCode("het afdrukmenu met 'Barcode etiket' verscheen niet (er is niets geprint)") = "P10")
T("Foutcode dossier", FoutCode("kon niet bevestigen dat het geopende dossier van X (1) is") = "P08")
T("Foutcode veld", FoutCode("Pharmacom kent Afdeling: T9 niet") = "L01")
T("Foutcode niemand ingelogd", FoutCode("er is niemand ingelogd in Pharmacom (geen apotheek te zien)") = "L07")
T("Foutcode andere apotheek", FoutCode("in Pharmacom is apotheek BG ingelogd, deze planning is van AN") = "L08")
T("Foutcode controle", FoutCode("Pharmacom kon niet gecontroleerd worden (x)") = "L09")
T("Foutcode onbekend", FoutCode("iets anders") = "")
T("MetCode", MetCode("gestopt door gebruiker") = "gestopt door gebruiker [G01]")
T("MetCode niet dubbel", MetCode("gestopt door gebruiker [G01]") = "gestopt door gebruiker [G01]")
T("MetCode leeg", MetCode("") = "")
T("Foutcode groep klopt niet", FoutCode("afdeling T2HA hoort bij instelling T2, niet bij T1") = "L12")
T("FoutOmschrijving", FoutOmschrijving("P11") != "" && FoutOmschrijving("Z00") = "")
L := TelLogregels(["10:00:00.1 - Ronde klaar: 3 geprint, 0 overgeslagen in 0:10"
    , "10:01:00.1 - Geplande ronde 'T1 GUA' klaar: 2 geprint"
    , "10:02:00.1 - Proefronde gestopt: Pharmacom keerde niet terug naar de aanschrijfbuffer [P11] (0 ...)"
    , "10:03:00.1 -   groep zoeken mislukt: Pharmacom accepteerde Afdeling: X niet [L01]"
    , "10:04:00.1 - Ronde gestopt: iets [P11]"
    , "  [P11] 2x  regel uit een diagnose (geen tijd)"])
T("TelLogregels klaar", L.klaar = 2)
T("TelLogregels P11", L.codes.Has("P11") && L.codes["P11"] = 2)
T("TelLogregels L01", L.codes.Has("L01") && L.codes["L01"] = 1)

try FileDelete Leeg
MsgBox Fouten ? Fouten " test(s) mislukt, zie " Uit : "Alle tests geslaagd.", "Eenheid", Fouten ? "Icon!" : "Iconi"
