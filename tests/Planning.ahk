; Unit-tests voor de planning (tijd, dagen, even/oneven weken). Draaien met:
;   AutoHotkey32.exe tests\Planning.ahk
; Het resultaat komt in tests\uitvoer_planning.txt (en in een melding).
#Requires AutoHotkey v2.0
#Warn All, Off
#Include ..\src\Hulp.ahk
#Include ..\src\Instellingen.ahk
#Include ..\src\Planning.ahk
#Include ..\src\Groepen.ahk
#Include ..\src\Opslag.ahk
#Include ..\src\Systeem.ahk

Uit := A_ScriptDir "\uitvoer_planning.txt"
try FileDelete Uit
Fouten := 0
T(Naam, Ok) {
    global Fouten
    if !Ok
        Fouten++
    FileAppend (Ok ? "OK   " : "FOUT ") Naam "`n", Uit, "UTF-8"
}
It(Extra := {}) {
    it := {id: 1, aan: 1, computer: A_ComputerName, dagen: "4", tijd: "08:00", weken: "even"}
    for k, v in Extra.OwnProps()
        it.%k% := v
    return it
}

; Donderdag 1 oktober 2026 = ISO-week 40 (even)
T("Weekdag do 1-10-2026 = 4", Planning.Weekdag("20261001120000") = 4)
T("Weekdag zo 4-10-2026 = 7", Planning.Weekdag("20261004120000") = 7)
T("Weekdag ma 5-10-2026 = 1", Planning.Weekdag("20261005120000") = 1)
T("Week 1-10-2026 = 40", Planning.WeekNr("20261001") = 40)
T("Week 31-12-2026 = 53", Planning.WeekNr("20261231") = 53)
T("Week 4-1-2027 = 1", Planning.WeekNr("20270104") = 1)
T("Even week klopt", Planning.WeekKlopt("even", "20261001"))
T("Oneven week klopt niet in week 40", !Planning.WeekKlopt("oneven", "20261001"))
T("Elke week", Planning.WeekKlopt("alle", "20261001"))

T("Start op 08:00", Planning.NuAan(It(), "20261001080000", ""))
T("Start op 08:14", Planning.NuAan(It(), "20261001081400", ""))
T("Niet meer op 08:15", !Planning.NuAan(It(), "20261001081500", ""))
T("Niet op 07:59", !Planning.NuAan(It(), "20261001075900", ""))
T("Niet op 07:59:59", !Planning.NuAan(It(), "20261001075959", ""))
T("Niet op 08:14:59 + 1 s", !Planning.NuAan(It(), "20261001081500", ""))
T("Wel op 08:14:59", Planning.NuAan(It(), "20261001081459", ""))
T("Niet op andere dag", !Planning.NuAan(It({dagen: "1235"}), "20261001080500", ""))
T("Niet in oneven-planning in even week", !Planning.NuAan(It({weken: "oneven"}), "20261001080500", ""))
T("Niet als uitgezet", !Planning.NuAan(It({aan: 0}), "20261001080500", ""))
T("Niet op een andere computer", !Planning.NuAan(It({computer: "ANDERE-PC"}), "20261001080500", ""))
T("Niet twee keer op een dag", !Planning.NuAan(It(), "20261001080500", "202610010800"))
T("Wel als gisteren gedraaid", Planning.NuAan(It(), "20261001080500", "202609300800"))
T("Tijd 7:30 zonder voorloopnul", Planning.NuAan(It({tijd: "7:30"}), "20261001073200", ""))

; --- Gemiste momenten ---
Ma := It({dagen: "1", weken: "alle"})          ; elke maandag 08:00
M := Planning.Momenten(Ma, "20261001000000", "20261013000000")
T("Momenten: 2 maandagen", M.Length = 2 && M[1] = "20261005080000" && M[2] = "20261012080000")
M := Planning.Momenten(It({dagen: "1", weken: "even"}), "20261001000000", "20261013000000")
T("Momenten: alleen even week (12-10)", M.Length = 1 && M[1] = "20261012080000")
T("Momenten: Van precies op het moment telt niet", Planning.Momenten(Ma, "20261005080000", "20261005090000").Length = 0)
T("Momenten: Tot precies op het moment telt wel", Planning.Momenten(Ma, "20261005070000", "20261005080000").Length = 1)
T("Gemist: beide maandagen", Planning.Gemist(Ma, "20261004120000", "20261012081500", "").Length = 2)
T("Gemist: 5-10 wel gedraaid", Planning.Gemist(Ma, "20261004120000", "20261012081500", "202610050801").Length = 1)
T("Gemist: niet als uitgezet", Planning.Gemist(It({dagen: "1", aan: 0}), "20261004120000", "20261012081500", "").Length = 0)
T("Gemist: niet voor andere computer", Planning.Gemist(It({dagen: "1", computer: "ANDERE-PC"}), "20261004120000", "20261012081500", "").Length = 0)

; --- Uitstel (pc vergrendeld / Pharmacom bezet): langer startvenster ---
T("Uitgesteld: om 09:30 nog starten", Planning.NuAan(It(), "20261001093000", "", Planning.MaxUitstel))
T("Uitgesteld: om 10:00 niet meer", !Planning.NuAan(It(), "20261001100000", "", Planning.MaxUitstel))
T("Niet uitgesteld: om 09:30 niet", !Planning.NuAan(It(), "20261001093000", ""))

; --- Wakker blijven rond een geplande tijd (08:00, do 1-10) ---
Planning.Uitgesteld := Map()
L := [It({weken: "alle"})]
T("Wakker: 07:35 (25 min ervoor)", Planning.BijnaAanDeBeurt(L, "20261001073500"))
T("Wakker: 08:10 (in het startvenster)", Planning.BijnaAanDeBeurt(L, "20261001081000"))
T("Niet wakker: 07:20 (40 min ervoor)", !Planning.BijnaAanDeBeurt(L, "20261001072000"))
T("Niet wakker: 08:20 (venster voorbij)", !Planning.BijnaAanDeBeurt(L, "20261001082000"))
T("Niet wakker: andere computer", !Planning.BijnaAanDeBeurt([It({weken: "alle", computer: "ANDERE-PC"})], "20261001075000"))
Planning.Uitgesteld[1] := {moment: "20261001080000", reden: "test"}
T("Wakker: zolang iets uitgesteld is", Planning.BijnaAanDeBeurt(L, "20261001120000"))
Planning.Uitgesteld := Map()

; --- Vandaag nog iets gepland? (afsluiten na starten met Windows) ---
T("Nog vandaag: 06:00, ronde om 08:00", Planning.NogVandaag(L, "20261001060000"))
T("Nog vandaag: 08:10 (in het startvenster)", Planning.NogVandaag(L, "20261001081000"))
T("Niets meer vandaag: 08:20 (venster voorbij)", !Planning.NogVandaag(L, "20261001082000"))
T("Niets vandaag: andere dag", !Planning.NogVandaag([It({dagen: "1"})], "20261001060000"))
T("Niets vandaag: oneven-planning in even week", !Planning.NogVandaag([It({weken: "oneven"})], "20261001060000"))
T("Niets vandaag: uitgezet", !Planning.NogVandaag([It({aan: 0})], "20261001060000"))
T("Niets vandaag: andere computer", !Planning.NogVandaag([It({computer: "ANDERE-PC"})], "20261001060000"))
T("Niets vandaag: lege planning", !Planning.NogVandaag([], "20261001060000"))
T("Nog vandaag: tweede ronde om 23:30", Planning.NogVandaag([It(), It({id: 2, tijd: "23:30"})], "20261001120000"))
Planning.Uitgesteld[1] := {moment: "20261001080000", reden: "test"}
T("Nog vandaag: zolang iets uitgesteld is", Planning.NogVandaag(L, "20261001120000"))
Planning.Uitgesteld := Map()

; --- Vooraf-controle (een minuut vóór 08:00, do 1-10) ---
T("SecondenTot: 07:59:00 = 60", Planning.SecondenTot(It(), "20261001075900") = 60)
T("SecondenTot: 08:00:30 = -30", Planning.SecondenTot(It(), "20261001080030") = -30)
T("SecondenTot: andere dag = leeg", Planning.SecondenTot(It({dagen: "1"}), "20261001075900") = "")
T("SecondenTot: oneven week = leeg", Planning.SecondenTot(It({weken: "oneven"}), "20261001075900") = "")
T("SecondenTot: andere computer = leeg", Planning.SecondenTot(It({computer: "ANDERE-PC"}), "20261001075900") = "")

; --- Klopt de groep? (instelling/afdeling) ---
B := {instellingen: Map("T1", "2 WEKELIJKS 1", "T2", "2 WEKELIJKS 2", "GI", "Gezamenlijk")
    , afdelingen: Map("T1", Map("T1HA", "T1 Halers", "T1GUA", "T1 GUA"), "T2", Map("T2HA", "T2 Halers"), "GI", Map())}
T("Groep klopt", Planning.GroepFout("T1", "T1HA", B) = "")
T("Groep: afdeling van andere instelling", InStr(Planning.GroepFout("T1", "T2HA", B), "hoort bij instelling T2"))
T("Groep: onbekende afdeling", InStr(Planning.GroepFout("T1", "T1XX", B), "niet bekend bij instelling T1"))
T("Groep: onbekende instelling", InStr(Planning.GroepFout("T9", "T1HA", B), "instelling T9 is niet bekend"))
T("Groep: instelling zonder afdelingen = niet afkeuren", Planning.GroepFout("GI", "IETS", B) = "")
T("Groep: niets opgehaald = niet afkeuren", Planning.GroepFout("T1", "T2HA", {instellingen: Map(), afdelingen: Map()}) = "")

; --- Planning-timer (v6.17) ---------------------------------------------------
; Na ontgrendelen stopte de vaste timer: "SetTimer PlanningTik, -3000" maakte
; van de timer van 20 s een eenmalige. Nagebootst met een korte timer; het
; log gaat naar een lijst, de apotheek is leeg (Tik doet dan verder niets).
Logregels := []
Opslag.DefineProp("Log", {call: (this, Msg) => Logregels.Push(Msg)})
Inst.Apotheek := ""
Planning.Interval := 200
SetTimer PlanningTik, Planning.Interval
SessieWijziging(8)                 ; WTS_SESSION_UNLOCK
Sleep 3500                         ; de extra controle na 3 s is geweest
Planning.LaatsteTik := 0
Sleep 1000
T("Timer: planning loopt nog na ontgrendelen", Planning.LaatsteTik != 0)
T("Timer: ontgrendelen gelogd", Logregels.Length && Logregels[Logregels.Length] = "Computer ontgrendeld")

; Bewaking: 2 minuten geen Tik = timer gestopt -> opnieuw zetten en loggen
T("Bewaking: timer loopt = niets doen", !Planning.BewaakTimer())
SetTimer PlanningTik, 0            ; timer gestopt
Planning.LaatsteTik := A_TickCount - Planning.MaxStil - 1000
T("Bewaking: stille timer hersteld", Planning.BewaakTimer())
T("Bewaking: herstel gelogd", InStr(Logregels[Logregels.Length], "Planning-timer hersteld"))
Sleep 300
Planning.LaatsteTik := 0
Sleep 600
T("Bewaking: timer loopt weer", Planning.LaatsteTik != 0)
SetTimer PlanningTik, 0

; Twee Tiks vlak na elkaar (vaste timer + controle na ontgrendelen): een
; tweede Tik tijdens de eerste doet niets, dus nooit twee keer dezelfde ronde
Uitgevoerd := 0
NepTik(this, *) {
    global Uitgevoerd
    Uitgevoerd++
    Planning.Tik()                 ; de andere timer, terwijl deze nog loopt
    if Uitgevoerd = 1
        throw Error("testfout")
}
Planning.DefineProp("TikUitvoeren", {call: NepTik})
try Planning.Tik()
T("Dubbel: tweede Tik tijdens de eerste doet niets", Uitgevoerd = 1)
T("Dubbel: na een fout weer vrij", !Planning.InTik)
Planning.Tik()
T("Dubbel: volgende Tik loopt gewoon", Uitgevoerd = 2 && !Planning.InTik)

; Zonder melding (bijv. op GitHub): met /ci de uitkomst als exitcode
if A_Args.Length && A_Args[1] = "/ci"
    ExitApp Fouten ? 1 : 0
MsgBox Fouten ? Fouten " test(s) mislukt, zie " Uit : "Alle planningstests geslaagd.", "Planning", Fouten ? "Icon!" : "Iconi"
