; Probe: bevestigt gedrag van de echte AHK-runtime voor de review.
; Draaien: AutoHotkey32.exe review\probes\Probe_runtime.ahk (uitvoer: probe_uitvoer.txt ernaast)
#Requires AutoHotkey v2.0
#Warn All, Off
#Include ..\..\src\Hulp.ahk
#Include ..\..\src\Instellingen.ahk
#Include ..\..\src\Planning.ahk
#Include ..\..\src\Groepen.ahk
#Include ..\..\src\Opslag.ahk

Uit := A_ScriptDir "\probe_uitvoer.txt"
try FileDelete Uit
P(Naam, Waarde) => FileAppend(Naam " => " Waarde "`n", Uit, "UTF-8")

; 1. Vergelijking zoals in Ph.ZoekRij (t.Cel(...) = Waarde) en Ronde (h.Cel(r,"ap") != Apotheek)
P("'0123' = '123' (ZoekRij)", "0123" = "123")
P("'123' = '123.0'", "123" = "123.0")
P("'1e3' = '1000'", "1e3" = "1000")
P("'0x10' = '16'", "0x10" = "16")
P("'an' != 'AN' (Ap-vergelijking)", "an" != "AN")
P("' AN' != 'AN'", " AN" != "AN")
M := Map(), M["0123"] := 1
P("Map heeft '123' als '0123' geregistreerd", M.Has("123"))

; 2. Pat.nr-patroon uit Ph.BevestigDossier (regel 350), letterlijk overgenomen
Patroon(patnr) => patnr != "" ? "(?<!\d)\Q" patnr "\E(?!\d)" : ""
for t in ["Pat.nr: 1234", "Dorpsstraat 123", "Tel. 06-123", "BSN 123456789", "Pat.nr: 123", "123a", "AN - RS - 183"]
    P("patroon '123' in '" t "'", RegExMatch(t, Patroon("123")) ? "MATCH" : "geen")
P("patroon '183' in statusbalk 'AN - RS - 183'", RegExMatch("AN - RS - 183", Patroon("183")) ? "MATCH" : "geen")

; 3. Achternaam + geboortedatum (regels 346-349, 357-358)
GebPat(geb) {
    if RegExMatch(geb, "^(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})$", &G)
        return "(?<!\d)0?" Integer(G[1]) "[-/.]0?" Integer(G[2]) "[-/.](" G[3] "|" SubStr(G[3], -2) ")(?!\d)"
    return ""
}
P("InStr('de Jong-Bakker', 'Jong')", InStr("de Jong-Bakker, P.", "Jong") > 0)
P("InStr('Jongeneel', 'Jong')", InStr("Jongeneel, K.", "Jong") > 0)
P("geb 01-02-1950 matcht '1-2-50'", RegExMatch("Geboren 1-2-50", GebPat("01-02-1950")) > 0)
P("geb 01-02-1950 matcht '01.02.1950'", RegExMatch("01.02.1950", GebPat("01-02-1950")) > 0)

; 4. Deelbaar-patroon (Ph.DeelbaarPatroon)
for t in ["ASB: Deelbaar", "ASB: Deelbaar niet", "asb:deelbaarheid onbekend", "ASB: Niet deelbaar"]
    P("Deelbaar '" t "'", RegExMatch(t, "i)^ASB:\s*Deelbaar") ? "MATCH" : "geen")

; 5. Versienummers
for v in [["6.13", "6.12.0"], ["6.13.1", "6.13"], ["6.1000", "7.0"], ["6.13.0.1", "6.13"], ["v6.14", "6.13"], ["6.14-beta", "6.13"]]
    P("VersieNummer " v[1] " > " v[2], VersieNummer(v[1]) > VersieNummer(v[2]))

; 6. ISO-weken rond de jaarwisseling 2026/2027
d := "20261214"
loop 5 {
    P("Week " FormatTime(d, "yyyy-MM-dd") , Planning.WeekNr(d) " (" (Mod(Planning.WeekNr(d), 2) ? "oneven" : "even") ")")
    d := DateAdd(d, 7, "Days")
}

; 7. Format met tekst (NuAan regel 206)
P("Format('{:02}{:02}00', '7', '30')", Format("{:02}{:02}00", "7", "30"))

; 8. Ongeldige tijd in de planning (NuAan / Momenten)
It := {id: 1, aan: 1, computer: A_ComputerName, dagen: "1234567", tijd: "25:00", weken: "alle"}
try P("NuAan tijd 25:00", Planning.NuAan(It, "20261015120000", ""))
catch as e
    P("NuAan tijd 25:00", "FOUT: " e.Message)
try P("Momenten tijd 25:00", Planning.Momenten(It, "20261014000000", "20261016000000").Length)
catch as e
    P("Momenten tijd 25:00", "FOUT: " e.Message)
It.tijd := "8:99"
try P("NuAan tijd 8:99", Planning.NuAan(It, "20261015120000", ""))
catch as e
    P("NuAan tijd 8:99", "FOUT: " e.Message)

; 9. Zomertijd: planning 02:30 op 29-03-2026 (klok 02:00 -> 03:00)
It2 := {id: 2, aan: 1, computer: A_ComputerName, dagen: "7", tijd: "02:30", weken: "alle"}
P("NuAan 02:30 om 03:00 (na de sprong)", Planning.NuAan(It2, "20260329030000", ""))
P("Gemist 02:30 op 29-03", Planning.Gemist(It2, "20260329000000", "20260329031500", "").Length)

; 10. Opruimen: DateDiff in dagen (Hulp.Opruimen, '> Dagen')
P("DateDiff 30 dagen + 23 uur", DateDiff("20261015230000", "20260915000000", "Days"))

; 11. CSV-regel zoals Opslag.Rapporteer (formule-injectie)
Regel := ""
for v in ["12:00:00", "900001", '=HYPERLINK("http://x";"klik")', "01-02-1950", "AN", "-2+3", "Geprint"]
    Regel .= (A_Index > 1 ? ";" : "") '"' StrReplace(v, '"', '""') '"'
P("CSV-regel", Regel)

; 12. Waakhond.Patient: IsInteger met voorloopnul
P("Integer('0012345')", Integer("0012345"))

; 13. TitelIsBuffer: venster zonder schermnaam
P("TitelIsBuffer('Pharmacom')", TitelIsBuffer("Pharmacom"))
P("TitelIsBuffer('Pharmacom - Patiënt dossier')", TitelIsBuffer("Pharmacom - Pati" Chr(235) "nt dossier"))
ExitApp
