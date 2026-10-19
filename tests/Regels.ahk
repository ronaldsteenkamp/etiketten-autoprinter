; Unit-tests voor de beslisregels (src\Regels.ahk): welke patiënt mag
; geprint worden, welke regel wordt gekozen, klopt het dossier, staat de
; historie op datum. Draaien met:
;   AutoHotkey32.exe tests\Regels.ahk
; Het resultaat komt in tests\uitvoer_regels.txt (en in een melding).
#Requires AutoHotkey v2.0
#Include ..\src\Hulp.ahk
#Include ..\src\Regels.ahk

Uit := A_ScriptDir "\uitvoer_regels.txt"
try FileDelete Uit
Fouten := 0
T(Naam, Ok) {
    global Fouten
    if !Ok
        Fouten++
    FileAppend (Ok ? "OK   " : "FOUT ") Naam "`n", Uit, "UTF-8"
}

; --- Soort in de lijst ---
G := Map("100", "09:15"), B := Map("200", "PC-2")
S(Patnr, Ontslag := "") => Regels.Soort(Patnr, Ontslag, G, B)
T("Soort: gewone patient = print", S("300")[1] = "print")
T("Soort: geen Pat.nr = controle", S("")[1] = "controle")
T("Soort: ontslagdatum = ontslag", S("300", "01-10-2026")[1] = "ontslag")
T("Soort: rare ontslagwaarde = controle", S("300", "onbekend")[1] = "controle")
T("Soort: vandaag geprint = al", S("100")[1] = "al" && InStr(S("100")[2], "09:15"))
T("Soort: claim van ander = controle", S("200")[1] = "controle" && InStr(S("200")[2], "PC-2"))
T("Soort: ontslag gaat voor geprint", S("100", "01-10-2026")[1] = "ontslag")
T("Soort: geprint gaat voor claim", Regels.Soort("200", "", Map("200", "10:00"), B)[1] = "al")

; --- Regel kiezen ---
Hist := [["BG", "ASB: Deelbaar"], ["AN", ""], ["AN", "ASB: Deelbaar"], ["AN", "ASB: Deelbaar"]]
Cel := (r, k) => Hist[r + 1][k = "ap" ? 1 : 2]
T("KiesRegel: bovenste AN", Regels.KiesRegel(Hist.Length, Cel, "AN", false) = 1)
T("KiesRegel: bovenste AN met ASB: Deelbaar", Regels.KiesRegel(Hist.Length, Cel, "AN", true) = 2)
T("KiesRegel: andere apotheek", Regels.KiesRegel(Hist.Length, Cel, "BG", true) = 0)
T("KiesRegel: geen regel", Regels.KiesRegel(Hist.Length, Cel, "XY", false) = -1)
T("KiesRegel: lege historie", Regels.KiesRegel(0, Cel, "AN", false) = -1)
T("KiesRegel: Ap moet precies kloppen", Regels.KiesRegel(1, (r, k) => k = "ap" ? "ANX" : "", "AN", false) = -1)
T("KiesRegel: deelbaar met spatie/hoofdletters", Regels.KiesRegel(1, (r, k) => k = "ap" ? "AN" : "asb:Deelbaar 1x", "AN", true) = 0)

; --- Dossier: Pat.nr ---
D(Teksten, Patnr := "123456") => Regels.DossierPatnr(Teksten, Patnr)
T("Dossier: 'Pat.nr: 123456' = veld", D(["Patient dossier", "Pat.nr: 123456"]).veld)
T("Dossier: label en waarde apart = veld", D(["Pat.nr", "123456"]).veld && D(["Pat.nr:", "123456"]).veld)
T("Dossier: 'Patiëntnr 123456' = veld", D(["Pati" Chr(235) "ntnr 123456"]).veld)
T("Dossier: elders = los, geen veld", D(["Relatie 123456"]).los && !D(["Relatie 123456"]).veld)
T("Dossier: ander Pat.nr = niets", !D(["Pat.nr: 654321"]).los && !D(["Pat.nr: 654321"]).veld)
T("Dossier: deel van een langer getal telt niet", !D(["Pat.nr: 1234567"]).los)
T("Dossier: label met waarde van ander", !D(["Pat.nr", "999", "123456"]).veld && D(["Pat.nr", "999", "123456"]).los)
T("Dossier: lege tekst tussen label en waarde", D(["Pat.nr:", "", "123456"]).veld)
T("Dossier: voorloopnullen", D(["Pat.nr: 00123456"]).veld)
T("Dossier: leeg Pat.nr = niets", !D(["Pat.nr: 123456"], "").los)

; --- Datums en sortering ---
T("Datum dd-mm-jjjj", Regels.DatumGetal("05-09-2026") = "20260905")
T("Datum d-m-jj", Regels.DatumGetal("5-9-26") = "20260905")
T("Datum jjjj-mm-dd", Regels.DatumGetal("2026-09-05") = "20260905")
T("Datum oud jaartal", Regels.DatumGetal("01-02-50") = "19500201")
T("Datum ongeldig", Regels.DatumGetal("31-13-2026") = "" && Regels.DatumGetal("") = "" && Regels.DatumGetal("gisteren") = "")
T("Aflopend: nieuwste bovenaan", Regels.Aflopend(["05-09-2026", "04-09-2026", "01-09-2026"]) = "")
T("Aflopend: gelijke datums", Regels.Aflopend(["05-09-2026", "05-09-2026"]) = "")
T("Aflopend: oudste bovenaan", InStr(Regels.Aflopend(["01-09-2026", "04-09-2026"]), "regel 2"))
T("Aflopend: lege datums tellen niet", Regels.Aflopend(["05-09-2026", "", "01-09-2026"]) = "")
T("Aflopend: over de jaargrens", Regels.Aflopend(["02-01-2027", "30-12-2026"]) = "")
T("Aflopend: lege lijst", Regels.Aflopend([]) = "")

; Zonder melding (bijv. op GitHub): met /ci de uitkomst als exitcode
if A_Args.Length && A_Args[1] = "/ci"
    ExitApp Fouten ? 1 : 0
MsgBox Fouten ? Fouten " test(s) mislukt, zie " Uit : "Alle regeltests geslaagd.", "Regels", Fouten ? "Icon!" : "Iconi"
