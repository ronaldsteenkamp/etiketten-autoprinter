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
    it := {aan: 1, computer: A_ComputerName, dagen: "4", tijd: "08:00", weken: "even"}
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

MsgBox Fouten ? Fouten " test(s) mislukt, zie " Uit : "Alle planningstests geslaagd.", "Planning", Fouten ? "Icon!" : "Iconi"
