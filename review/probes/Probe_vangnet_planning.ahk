#Requires AutoHotkey v2.0
; Bootst de structuur na: Planning.Voer (try/catch/finally) -> Ronde.StartRun -> PrintPatient (throw)
Uit := A_ScriptDir "\probe3_uitvoer.txt"
try FileDelete Uit
P(t) => FileAppend(t "`n", Uit, "UTF-8")
OnError Vangnet
Vangnet(e, Modus) {
    P("Vangnet aangeroepen: " e.Message)
    global Bezig := false, Geblokkeerd := false
    return 1
}
global Bezig := false, Geblokkeerd := false
StartRun() {
    global Bezig := true, Geblokkeerd := true      ; Ronde.Bezig / Invoer.Blokkeer(true)
    PrintPatient()
    global Bezig := false, Geblokkeerd := false    ; afronden (wordt overgeslagen bij een fout)
}
PrintPatient() => (Fout())
Fout() {
    throw Error("testfout")
}
Voer() {
    try {
        StartRun()
    } catch as e {
        P("Planning.Voer catch: " e.Message)
    } finally {
        P("Planning.Voer finally")
    }
}
P("--- geplande ronde (via Voer) ---")
Voer()
P("Na Voer: Ronde.Bezig=" Bezig ", blokkade=" Geblokkeerd)
Bezig := false, Geblokkeerd := false
P("--- handmatige ronde (StartRun via timer, zonder try) ---")
SetTimer StartRun, -10
Sleep 300
P("Na handmatig: Ronde.Bezig=" Bezig ", blokkade=" Geblokkeerd)
ExitApp
