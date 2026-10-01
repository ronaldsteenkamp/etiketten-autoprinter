; Unit-tests voor de planning (tijd, dagen, even/oneven weken). Draaien met:
;   AutoHotkey32.exe tests\Planning.ahk
; Het resultaat komt in tests\uitvoer_planning.txt (en in een melding).
#Requires AutoHotkey v2.0
#Warn All, Off
#Include ..\src\Hulp.ahk
#Include ..\src\Instellingen.ahk
#Include ..\src\Planning.ahk

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

MsgBox Fouten ? Fouten " test(s) mislukt, zie " Uit : "Alle planningstests geslaagd.", "Planning", Fouten ? "Icon!" : "Iconi"
