; Unit-tests voor het register van geprinte patiënten en de claims
; (src\Opslag.ahk): niet bereikbaar = nooit stil doorgaan. Draaien met:
;   AutoHotkey32.exe tests\Register.ahk
; Het resultaat komt in tests\uitvoer_register.txt (en in een melding). Werkt in
; een eigen map in %TEMP%; raakt het echte register niet.
#Requires AutoHotkey v2.0
#Warn All, Off
#Include ..\src\Hulp.ahk
#Include ..\src\Instellingen.ahk
#Include ..\src\Opslag.ahk

Uit := A_ScriptDir "\uitvoer_register.txt"
try FileDelete Uit
Fouten := 0
T(Naam, Ok) {
    global Fouten
    if !Ok
        Fouten++
    FileAppend (Ok ? "OK   " : "FOUT ") Naam "`n", Uit, "UTF-8"
}
Basis := A_Temp "\etiketten_registertest"
try DirDelete Basis, true
Opslag.LogMap := Basis "\Log"
Opslag.GeprintMap := Basis "\Geprint"
Opslag.ClaimMap := Basis "\Geprint\Bezig"

; --- Register: map niet bereikbaar ---
T("Register onbereikbaar = leeg antwoord (niet: niemand geprint)", Opslag.LeesRegister() = "")
T("Registreren onbereikbaar = leeg", Opslag.Registreer("111") = "")
T("Niet weggeschreven registratie wacht", Opslag.Wachtend.Length = 1)

; --- Weer bereikbaar: wachtende registratie telt mee en wordt weggeschreven ---
DirCreate Opslag.GeprintMap
R := Opslag.LeesRegister()
T("Register leest na herstel", IsObject(R))
T("Wachtende registratie telt mee", IsObject(R) && R.Has("111"))
T("Niets meer wachtend na wegschrijven", Opslag.Wachtend.Length = 0)
R := Opslag.LeesRegister()
T("Registratie staat nu in het bestand", IsObject(R) && R.Has("111"))
T("Registreren lukt", Opslag.Registreer("222") != "")
R := Opslag.LeesRegister()
T("Beide registraties gelezen", IsObject(R) && R.Has("222") && R.Count = 2)

; --- Claims ---
c := Opslag.Claim("333")
T("Claim lukt", c.HasProp("ok"))
T("Claimbestand bestaat", FileExist(Opslag.ClaimBestand("333")) != "")
T("Eigen claim opnieuw = ok", Opslag.Claim("333").HasProp("ok"))
Opslag.GeefVrij("333")
T("Vrijgeven haalt eigen claim weg", !FileExist(Opslag.ClaimBestand("333")))
FileAppend "ANDERE-PC iemand 1234 20261019100000", Opslag.ClaimBestand("444"), "UTF-8-RAW"
c := Opslag.Claim("444")
T("Claim van een andere computer = bezet", c.HasProp("bezet") && c.bezet = "ANDERE-PC")
Opslag.GeefVrij("444")
T("Claim van een andere computer blijft staan", FileExist(Opslag.ClaimBestand("444")) != "")
DirDelete Opslag.ClaimMap, true
T("Claimmap weg = opnieuw aangemaakt", Opslag.Claim("555").HasProp("ok"))

; --- Slot op de gedeelde ini (Inst.Schrijf / Inst.Wis) ---
Inst.Bestand := Basis "\gedeeld.ini"
Slot := Inst.Bestand ".slot"
Inst.Schrijf("waarde", "Test", "a")
T("Ini: geschreven", IniRead(Inst.Bestand, "Test", "a", "") = "waarde")
T("Ini: slot weer weg", !FileExist(Slot))
Inst.Wis("Test", "a")
T("Ini: gewist", IniRead(Inst.Bestand, "Test", "a", "") = "")
; Oud slot (andere computer liep vast): wordt weggehaald, schrijven lukt
FileAppend "ANDERE-PC 20261019", Slot
FileSetTime DateAdd(A_Now, -5, "Minutes"), Slot, "M"
Inst.Schrijf("b", "Test", "b")
T("Ini: oud slot weggehaald en geschreven", IniRead(Inst.Bestand, "Test", "b", "") = "b" && !FileExist(Slot))
; Vers slot van een andere computer: kort wachten, dan toch schrijven; zijn slot blijft
FileAppend "ANDERE-PC 20261019", Slot
Inst.MaxSlotWacht := 300
Begin := A_TickCount
Inst.Schrijf("c", "Test", "c")
T("Ini: na wachten toch geschreven", IniRead(Inst.Bestand, "Test", "c", "") = "c" && A_TickCount - Begin >= 300)
T("Ini: slot van de ander blijft staan", FileExist(Slot) != "")
FileDelete Slot
T("NieuwBestand: bestaat al = 80", NieuwBestand(Inst.Bestand, "x") = 80)

try DirDelete Basis, true
; Zonder melding (bijv. op GitHub): met /ci de uitkomst als exitcode
if A_Args.Length && A_Args[1] = "/ci"
    ExitApp Fouten ? 1 : 0
MsgBox Fouten ? Fouten " test(s) mislukt, zie " Uit : "Alle registertests geslaagd.", "Register", Fouten ? "Icon!" : "Iconi"
