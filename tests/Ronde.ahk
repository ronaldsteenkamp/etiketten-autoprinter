; Unit-tests voor het afbreken van een ronde na een onverwachte fout
; (Ronde.Noodstop). Pharmacom, het venster, de blokkade en de opslag zijn
; nagebootst: er wordt niets geblokkeerd en niets in Pharmacom gedaan.
; Draaien met:
;   AutoHotkey32.exe tests\Ronde.ahk
; Het resultaat komt in tests\uitvoer_ronde.txt (en in een melding).
#Requires AutoHotkey v2.0
#Warn All, Off
#Include ..\src\Hulp.ahk
#Include ..\src\Ronde.ahk
#Include ..\src\Planning.ahk

Uit := A_ScriptDir "\uitvoer_ronde.txt"
try FileDelete Uit
Fouten := 0
T(Naam, Ok) {
    global Fouten
    if !Ok
        Fouten++
    FileAppend (Ok ? "OK   " : "FOUT ") Naam "`n", Uit, "UTF-8"
}

; --- Nagebootst ------------------------------------------------------------
; Onbekende aanroepen doen niets (Venster.Status, Venster.Rij, ...)
class Nep {
    static __Call(Naam, Params) => ""
}
class Venster extends Nep {
    static Knoppen := Map(), GeenAct := false
    static Verbind() => "ok"
    static ZetKnop(Naam, Aan) => this.Knoppen[Naam] := Aan
    static GeenActivatie(Aan) => this.GeenAct := Aan
}
class Ph extends Nep {
    static Hwnd := 0, Pid := 0, Verbonden := true, Terug := 0
    static TerugNaarBuffer() => (this.Terug++, true)
}
class PhZoek extends Nep {
    static ZetGroep(Instelling, Afdeling) => ""
}
class Invoer {
    static Geblokkeerd := false
    static Blokkeer(Aan, Volledig := true) => this.Geblokkeerd := Aan
}
class Wakker {
    static Ronde := false
    static Zet(Reden, Aan) => Reden = "ronde" ? this.Ronde := Aan : ""
}
class Waakhond {
    static Pat := ""
    static Patient(Patnr) => this.Pat := Patnr
}
class Melder extends Nep {
}
class Inst {
    static Apotheek := "AN", Wachttijden := [], Wt := Map()
    static Optie(Naam) => Naam = "blokkeer"
    static Lees1(*) => ""
}
class Opslag extends Nep {
    static Geregistreerd := [], Rapport := []
    static Registreer(Patnr) => (this.Geregistreerd.Push(Patnr), "12:00")
    static Rapporteer(p, Etiket, Status, Apotheek) => this.Rapport.Push(p.patnr ": " Status)
}
Log(Msg) => ""

; De ronde zelf: twee patiënten; bij de eerste is het etiket al gekozen
; en gaat het daarna mis
Ronde.DefineProp("Vernieuw", {call: NepVernieuw})
NepVernieuw(this, *) {
    this.Apotheek := "AN"
    this.Patienten := [{rij: 0, naam: "Test, A", patnr: "101", soort: "print", aan: true, etiket: ""}
        , {rij: 1, naam: "Test, B", patnr: "102", soort: "print", aan: true, etiket: ""}]
    return true
}
Ronde.DefineProp("PrintPatient", {call: NepPrintPatient})
NepPrintPatient(this, p) {
    this.Gekozen := true
    throw Error("testfout")
}
; Planning: geen ini, geen vergrendeling
Statussen := []
Planning.DefineProp("Belemmering", {call: (*) => ""})
Planning.DefineProp("ZetGedraaid", {call: (*) => ""})
Planning.DefineProp("ZetStatus", {call: (this, it, Soort, Tekst := "", *) => Statussen.Push(Soort ": " Tekst)})

; StartRun haalt Pharmacom naar voren: een eigen venster als nep-Pharmacom
NepPh := Gui(, "Nep-Pharmacom (test)")
NepPh.Show("w200 h80")
Ph.Hwnd := NepPh.Hwnd, Ph.Pid := ProcessExist()

Herstel() {
    global Statussen := []
    Opslag.Geregistreerd := [], Opslag.Rapport := []
    Venster.Knoppen := Map(), Ph.Terug := 0
    Ronde.VandaagGeprint := Map(), Ronde.Uitgevinkt := Map(), Ronde.HerprintOk := Map()
    Ronde.Bezig := false, Planning.Bezig := false
}

; --- Geplande ronde: Planning.Voer -> Ronde.StartRun -> fout ----------------
Herstel()
It := {id: 1, aan: 1, naam: "Test T1/T1GUA", instelling: "T1", afdeling: "T1GUA", dagen: "1234567"
    , tijd: "00:00", weken: "alle", computer: A_ComputerName, opmerking: ""}
Planning.Voer(It, true)
T("Gepland: blokkade eraf", !Invoer.Geblokkeerd)
T("Gepland: GeenActivatie uit", !Venster.GeenAct)
T("Gepland: Ronde.Bezig uit", !Ronde.Bezig)
T("Gepland: Planning.Bezig uit", !Planning.Bezig)
T("Gepland: Wakker uit", !Wakker.Ronde)
T("Gepland: waakhond zonder patiënt", Waakhond.Pat = 0)
T("Gepland: gekozen etiket geregistreerd", Opslag.Geregistreerd.Length = 1 && Opslag.Geregistreerd[1] = "101")
T("Gepland: telt als vandaag geprint", Ronde.VandaagGeprint.Has("101"))
T("Gepland: rapportregel X99", Opslag.Rapport.Length = 1 && InStr(Opslag.Rapport[1], "101: Gestopt: onverwachte fout [X99]"))
T("Gepland: StopReden X99", FoutCode(Ronde.StopReden) = "X99")
T("Gepland: Pharmacom terug naar de buffer", Ph.Terug = 1)
T("Gepland: knoppen terug", Venster.Knoppen.Get("start", 0) && Venster.Knoppen.Get("proef", 0) && !Venster.Knoppen.Get("stop", 1))
T("Gepland: X99 niet herstartbaar", !Planning.Herstartbaar())
T("Gepland: status mislukt", Statussen.Length = 1 && InStr(Statussen[1], "mislukt: onverwachte fout: testfout"))
T("Gepland: Huidig leeg", Ronde.Huidig = "")

; --- Handmatige ronde: fout gaat naar het vangnet (OnError) -----------------
Herstel()
Vangnet(e, Modus) {
    global VangnetBezig := Ronde.Noodstop(e)
    return 1
}
VangnetBezig := ""
OnError Vangnet
SetTimer () => Ronde.StartRun(), -10
Sleep 500
OnError Vangnet, 0
T("Handmatig: vangnet zag een lopende ronde", VangnetBezig = true)
T("Handmatig: blokkade eraf", !Invoer.Geblokkeerd)
T("Handmatig: Ronde.Bezig uit", !Ronde.Bezig)
T("Handmatig: gekozen etiket geregistreerd", Opslag.Geregistreerd.Length = 1)
T("Handmatig: rapportregel X99", Opslag.Rapport.Length = 1 && InStr(Opslag.Rapport[1], "[X99]"))

; --- Noodstop zonder lopende ronde: alleen de blokkade eraf -----------------
Herstel()
Invoer.Geblokkeerd := true
T("Geen ronde: Noodstop geeft false", Ronde.Noodstop(Error("x")) = false)
T("Geen ronde: blokkade toch eraf", !Invoer.Geblokkeerd)
T("Geen ronde: niets geregistreerd of gerapporteerd", !Opslag.Geregistreerd.Length && !Opslag.Rapport.Length)

NepPh.Destroy()
; Zonder melding (bijv. op GitHub): met /ci de uitkomst als exitcode
if A_Args.Length && A_Args[1] = "/ci"
    ExitApp Fouten ? 1 : 0
MsgBox Fouten ? Fouten " test(s) mislukt, zie " Uit : "Alle rondetests geslaagd.", "Ronde", Fouten ? "Icon!" : "Iconi"
