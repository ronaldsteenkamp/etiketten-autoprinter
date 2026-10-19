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
T("VersieNummer 6.13 > 6.12.0", VersieNummer("6.13") > VersieNummer("6.12.0"))
T("VersieNummer 6.13 = 6.13.0.0 (.exe)", VersieNummer("6.13") = VersieNummer("6.13.0.0"))
T("VersieNummer 6.14 > 6.13", VersieNummer("6.14") > VersieNummer("6.13"))
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
T("Foutcode dossier zonder naam", FoutCode("kon niet bevestigen dat het geopende dossier van Pat.nr 123 is") = "P08")
T("Foutcode regel klopte niet meer", FoutCode("de regel met Ap = AN en ASB: Deelbaar klopte vlak voor het printen niet meer (Ap is niet meer AN)") = "P09")
T("Foutcode regel klopte niet: historie veranderd", FoutCode("de regel met Ap = AN klopte vlak voor het printen niet meer (de medicatiehistorie is veranderd)") = "P09")
T("Foutcode regel niet te selecteren", FoutCode("de regel met Ap = AN kon niet geselecteerd worden") = "P09")
T("Foutcode historie niet in dossier", FoutCode("de medicatiehistorie werd niet herkend in het dossier (zie logbestand)") = "P07")
T("Foutcode register niet bereikbaar", FoutCode("het register van geprinte pati" Chr(235) "nten is niet bereikbaar") = "P12")
T("Foutcode register met claimfout", FoutCode("het register van geprinte pati" Chr(235) "nten is niet bereikbaar (map X niet bereikbaar)") = "P12")
T("Foutcode register niet bijgewerkt", FoutCode("het register van geprinte pati" Chr(235) "nten kon niet bijgewerkt worden (het etiket is wel geprint)") = "P12")
T("Foutcode kolom Afd", FoutCode("de kolom Afd is niet gevonden: kan niet controleren dat de lijst alleen afdeling T1GUA bevat") = "L13")
T("FoutOmschrijving P12 en L13", FoutOmschrijving("P12") != "" && FoutOmschrijving("L13") != "")
T("Foutcode expliciet gaat voor tekst", FoutCode("iets dat op P11 lijkt: keerde niet terug naar de aanschrijfbuffer [P02]") = "P02")
T("Foutcode expliciet met toevoeging", FoutCode("tekst (Pharmacom staat weer op de aanschrijfbuffer) [P09]") = "P09")
T("MetCode laat expliciete code staan", MetCode("tekst [P07]") = "tekst [P07]")
T("Foutcode vraag open = L11", FoutCode("er staat een vraag van de app open of er loopt al een ronde") = "L11")
T("VeiligeTitel schermnaam", VeiligeTitel("Pharmacom - Aanschrijfbuffer") = "Pharmacom - Aanschrijfbuffer")
T("VeiligeTitel leeg", VeiligeTitel("") = "")
T("VeiligeTitel met naam", VeiligeTitel("Dossier Jansen, J") = "(titel verborgen)")
T("VeiligeTitel met Pat.nr", VeiligeTitel("Dossier 123456") = "(titel verborgen)")
T("VeiligeTitel dossier met naam", VeiligeTitel("Pharmacom - Dossier - AB Achternaam") = "Pharmacom - Dossier - (verborgen)")
T("VeiligeTitel dossier met naam en streepje", VeiligeTitel("Pharmacom - Dossier - de Vries - Jansen") = "Pharmacom - Dossier - (verborgen)")
T("VeiligeTitel alleen programma", VeiligeTitel("Pharmacom") = "Pharmacom")
T("VeiligeTitel te lang", VeiligeTitel("Een heel lange titel van meer dan veertig tekens lang") = "(titel verborgen)")
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
; Zonder melding (bijv. op GitHub): met /ci de uitkomst als exitcode
if A_Args.Length && A_Args[1] = "/ci"
    ExitApp Fouten ? 1 : 0
MsgBox Fouten ? Fouten " test(s) mislukt, zie " Uit : "Alle tests geslaagd.", "Eenheid", Fouten ? "Icon!" : "Iconi"
