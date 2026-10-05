#Requires AutoHotkey v2.0 32-bit
#SingleInstance Off      ; zie EnkeleInstantie (de waakhond is dezelfde .exe)
Persistent
SendMode "Input"
SetWorkingDir A_ScriptDir
SetTitleMatchMode 2
A_MaxHotkeysPerInterval := 1000

;@Ahk2Exe-SetName Etiketten autoprinter
;@Ahk2Exe-SetDescription Etiketten autoprinter voor Pharmacom
;@Ahk2Exe-SetMainIcon Etiketten_autoprinter.ico
;@Ahk2Exe-SetCopyright Ronald Steenkamp

; =====================================================================
; Etiketten autoprinter voor Pharmacom  (AutoHotkey v2, 32-bit)
;
; De app leest Pharmacom zelf uit via de Java Access Bridge (de
; toegankelijkheidskoppeling van Java). Er wordt nergens gegokt:
;
;   1. De aanschrijfbuffer wordt uitgelezen (en bijgewerkt als die in
;      Pharmacom verandert). Pati"enten zonder ontslagdatum staan
;      aangevinkt; wie vandaag al geprint is, staat uitgevinkt.
;   2. Per pati"ent:
;      - opzoeken op Pat.nr en selecteren (direct via de koppeling, anders
;        met pijltjestoetsen; daarna gecontroleerd);
;      - Ctrl+B -> dossier -> F4 -> medicatiehistorie -> pijl omhoog;
;      - controle dat het dossier van de juiste pati"ent is (Pat.nr);
;      - de BOVENSTE regel met Ap = de ingelogde apotheek (en evt. Herhaal
;        info = "ASB: Deelbaar") selecteren; geen passende regel -> overslaan;
;      - Ctrl+P -> afdrukmenu -> "Barcode etiket" (Alt+B) -> Escape ->
;        wachten tot de aanschrijfbuffer weer zichtbaar is.
;   3. Elke ronde krijgt een rapport (CSV) in de map Rapporten.
;
; VEILIGHEID: klopt een selectie niet, verschijnt een scherm niet, is het
; dossier niet van de juiste pati"ent of is Pharmacom niet meer het actieve
; venster, dan stopt de app (en zet Pharmacom terug op de aanschrijfbuffer).
; Tijdens het printen zijn toetsenbord en muis geblokkeerd (optie); Esc
; stopt direct.
;
; Opbouw: src\Jab.ahk (koppeling), src\Pharmacom.ahk (stappen),
; src\Ronde.ahk (lijst en printronde), src\Venster.ahk (WebView2-venster),
; src\Opslag.ahk, src\Instellingen.ahk, src\Invoer.ahk, src\Update.ahk.
; =====================================================================

global AppTitel := "Etiketten autoprinter"
global AppMaker := "Ronald Steenkamp"          ; credits (Over-venster)
global AppContact := "rsteenkamp@benu.nl"      ; vragen en verbetervoorstellen
global AppGitHub := "ronaldsteenkamp/etiketten-autoprinter"                        ; GitHub-repository voor updates ("eigenaar/naam"); leeg = alleen de updatemap
global AppVersie := "6.10.0"
;@Ahk2Exe-Let U_Versie = %A_PriorLine~U)^.*"(.+)".*$~$1%
;@Ahk2Exe-SetVersion %U_Versie%
; Ahk2Exe neemt het versienummer over uit de AppVersie-regel (de Let-regel
; moet daar DIRECT onder staan). De .exe-versie wordt gebruikt bij updates.

#Include src\Hulp.ahk
#Include src\Instellingen.ahk
#Include src\Opslag.ahk
#Include src\Jab.ahk
#Include src\Pharmacom.ahk
#Include src\Invoer.ahk
#Include src\Ronde.ahk
#Include src\Venster.ahk
#Include src\Update.ahk
#Include src\Planning.ahk
#Include src\Wijzigingen.ahk
#Include src\Systeem.ahk
#Include src\lib\WebView2
#Include WebView2.ahk

; Dezelfde .exe met /waakhond <pid> <venster> is de waakhond (zie src\Systeem.ahk)
if A_Args.Length >= 3 && A_Args[1] = "/waakhond" {
    Waakhond.Bewaak(Integer(A_Args[2]), Integer(A_Args[3]))
    ExitApp
}
; Testmodus (nep-Pharmacom): mag naast de echte app draaien
if Inst.Test
    AppTitel .= " - TEST"
else
    EnkeleInstantie()

OnError Vangnet
OnExit Afsluiten
Inst.Lees()
Opslag.Init()
Inst.ZetApotheek(Inst.LaatsteApotheek)   ; tot Pharmacom hem laat zien
Jab.BijAfsluiten := ObjBindMethod(Ph, "JavaAfgesloten")
MaakTray()
Venster.Maak()
Log("App gestart (v" AppVersie ", AutoHotkey " A_AhkVersion ")")
Staat.Meld()
SetTimer () => Staat.Meld(true), 3600000
if Inst.Test {
    Log("TESTMODUS: nep-Pharmacom (jjs.exe), gegevens in " Inst.DataMap)
    ; Automatisch een ronde starten, bijv. ETIKETTEN_TEST_START=T1/T1GUA/proef
    ; (of /print): zoals een planning die met de hand gestart wordt
    if RegExMatch(EnvGet("ETIKETTEN_TEST_START"), "i)^(\w+)/(\w+)/(proef|print)$", &T)
        SetTimer () => Planning.Voer({id: "test", aan: 1, naam: "Test " T[1] "/" T[2], instelling: T[1], afdeling: T[2]
            , dagen: "1234567", tijd: "00:00", weken: "alle", computer: A_ComputerName, opmerking: ""}, true, T[3] = "proef"), -12000
}
if Inst.Bestand != Inst.Eigen && !Inst.Test
    Log("Instellingen uit de gedeelde map: " Inst.Bestand)
else if Inst.GedeeldWeg {
    Log("LET OP: gedeelde instellingen (" Inst.UpdateMap ") niet bereikbaar, eigen instellingen gebruikt")
    SetTimer () => Venster.Melding("Netwerkmap niet bereikbaar", "De netwerkmap " Inst.UpdateMap " is niet bereikbaar. De app gebruikt nu de instellingen op deze computer, zonder de gedeelde planning.`n`nStart de app opnieuw zodra de netwerkmap weer bereikbaar is.", "waarschuwing"), -2000
}
Sessie.Volg()
Waakhond.Start()
Bewaking()
SetTimer Bewaking, 3000
SetTimer () => Geheugen.LogPharmacom(), 3600000
SetTimer () => Update.Controleer(true), -1500
SetTimer () => Update.ControleerLokaal(), -2500
SetTimer () => Wijzigingen.BijStart(), -3500
SetTimer PlanningTik, 20000

; Draait elke 3 seconden (als er niet geprint wordt): zoekt Pharmacom,
; leest de aanschrijfbuffer in zodra er (opnieuw) verbinding is en werkt de
; lijst bij als de aanschrijfbuffer in Pharmacom verandert.
;
; Zuinig: elke keer alleen een snelle controle (aantal regels, eerste en
; laatste Pat.nr) en elke 30 s een volledige. Geen controle als de app of
; Pharmacom geminimaliseerd is, of als Pharmacom een ander scherm toont.
; (Meldingen van Pharmacom zelf zijn onderzocht: die geven geen nette
; "tabel veranderd" en wel ± 100 meldingen per seconde van een knop.)
Bewaking() {
    static Bezig := false, Teller := 0, Gepauzeerd := ""
    if Ronde.Bezig || Bezig || Planning.Bezig
        return
    Bezig := true
    try {
        WasVerbonden := Ph.Verbonden
        St := Venster.Verbind()
        if St != "ok" {
            Ph.VergeetBuffer()
            Inst.ApotheekBevestigd := false   ; na een herstart kan een andere apotheek inloggen
        } else if !WasVerbonden {
            Geheugen.LogPharmacom()
            Ronde.Vernieuw(false, true)
            Gepauzeerd := ""
        } else {
            ; Apotheek nog niet gelezen (Pharmacom stond bij het starten niet
            ; op de aanschrijfbuffer; tot dan geldt de laatst bekende):
            ; aflezen uit de statusbalk, die op elk scherm staat. Nodig voor de
            ; planning en de opties per apotheek.
            if !Inst.ApotheekBevestigd && (Ap := Ph.LeesApotheek()) != "" {
                Inst.ApotheekBevestigd := true
                if Ap != Inst.Apotheek {
                    Inst.ZetApotheek(Ap)
                    Venster.UiOpties()
                }
                Log("Ingelogde apotheek: " Ap)
            }
            Pauze := Venster.Geminimaliseerd() ? "app geminimaliseerd"
                : WinGetMinMax(Ph.Hwnd) = -1 ? "Pharmacom geminimaliseerd"
                : !Ph.OpBufferScherm() ? "ander scherm in Pharmacom" : ""
            if Pauze != Gepauzeerd
                Log(Pauze != "" ? "Bewaking gepauzeerd: " Pauze : "Bewaking hervat")
            if Pauze = "" && Gepauzeerd != "" {
                ; Terug: altijd even volledig bijwerken
                Ronde.Vernieuw(true, true)
            } else if Pauze = "" {
                Volledig := Mod(++Teller, 10) = 0
                H := Ph.Handtekening(Volledig)
                if H != "" && H != (Volledig ? Ronde.LaatsteHandtekening : Ronde.LaatsteSnel) {
                    Log("Aanschrijfbuffer is veranderd in Pharmacom")
                    Ronde.Vernieuw(true, true)
                } else if Volledig && Ronde.RegisterGewijzigd() {
                    ; Bijv. een andere computer heeft intussen geprint
                    Log("Register van vandaag is veranderd")
                    Ronde.Vernieuw(true, true)
                }
            }
            if Pauze = "ander scherm in Pharmacom" && Gepauzeerd != Pauze
                Venster.Verbinding("warn", "Verbonden " Teken.Mid " open de aanschrijfbuffer")
            Gepauzeerd := Pauze
        }
    } catch as e
        Log("Fout in bewaking: " e.Message " (" e.What ", regel " e.Line ")")
    Bezig := false
}

; Vangnet voor onverwachte fouten. Zonder dit verschijnt het foutvenster van
; AutoHotkey terwijl toetsenbord en muis misschien nog geblokkeerd zijn. Nu:
; blokkade eraf, ronde netjes stoppen (een al gekozen etiket wordt als
; geprint geregistreerd), Pharmacom terug naar de aanschrijfbuffer, fout in
; het log en een duidelijke melding. De app blijft draaien.
Vangnet(e, Modus) {
    static BezigMetFout := false
    if BezigMetFout
        return 1
    BezigMetFout := true
    try Log("ONVERWACHTE FOUT [X99]: " e.Message " | " e.What " | regel " e.Line " | " e.Extra " | " e.File)
    WasBezig := Ronde.Bezig
    try Invoer.Blokkeer(false)
    try Venster.GeenActivatie(false)
    if WasBezig {
        try SetTimer RondeTijd, 0
        p := Ronde.Huidig
        try {
            if IsObject(p) && Ronde.Gekozen && !p.geprintNu {
                ; Het item in het afdrukmenu was al gekozen: telt als geprint
                Ronde.VandaagGeprint[p.patnr] := Opslag.Registreer(p.patnr)
                p.geprintNu := true
                Log("  Pat.nr " p.patnr ": etiket was al gekozen, als geprint geregistreerd")
            }
            if IsObject(p)
                Opslag.Rapporteer(p, "", "Gestopt: onverwachte fout [X99] (" e.Message ")", Ronde.Apotheek)
        }
        Ronde.Bezig := false, Ronde.Stoppen := false, Ronde.Huidig := ""
        try Wakker.Zet("ronde", false)
        try Waakhond.Patient(0)
        Ronde.StopReden := MetCode("onverwachte fout")
        try Ph.TerugNaarBuffer()
        try {
            Venster.Ui("bezig", 0)
            Venster.ZetKnop("start", true)
            Venster.ZetKnop("proef", true)
            Venster.ZetKnop("vernieuwen", Ph.Verbonden)
            Venster.ZetKnop("stop", false)
            Venster.Voortgang("oranje")
            Venster.KnopTekst("start", "Doorgaan")
        }
    }
    Planning.Bezig := false
    Tekst := "Er ging iets onverwachts mis" (WasBezig ? " tijdens het printen. De ronde is gestopt en toetsenbord en muis zijn weer vrij. Met Doorgaan ga je verder; wie al geprint is, wordt overgeslagen." : ".")
        . "`n`nFout: " e.Message "`n(" e.What ", regel " e.Line ")"
        . "`n`nDe app werkt gewoon verder. Gebeurt dit vaker, stuur dan het logbestand naar " AppMaker " (knop rechtsboven)."
    try Venster.Status("fout", "Onverwachte fout [X99]: " e.Message)
    try Venster.Geluid("gestopt")
    try SetTimer () => Venster.Melding("Onverwachte fout", Tekst, "fout"), -100
    catch
        MsgBox Tekst, AppTitel, "Iconx"
    BezigMetFout := false
    return 1    ; geen standaard foutvenster; alleen deze taak stopt
}

; Bij afsluiten: blokkade eraf, slaapstand weer toestaan, onthouden
; Java-objecten vrijgeven en de waakhond stoppen (die houdt anders de .exe
; vast, wat een update in de weg zit).
Afsluiten(*) {
    try Invoer.Blokkeer(false)
    try Wakker.Zet("ronde", false), Wakker.Zet("planning", false)
    try Ph.VergeetBuffer()
    try {
        if Waakhond.Pid
            ProcessClose Waakhond.Pid
    }
    try Log("App afgesloten")
}

; Systeemvak (icoon rechtsonder bij de klok)
MaakTray() {
    if !A_IsCompiled && FileExist(A_ScriptDir "\Etiketten_autoprinter.ico")
        TraySetIcon A_ScriptDir "\Etiketten_autoprinter.ico"
    m := A_TrayMenu
    m.Delete()
    m.Add("Venster tonen", (*) => Venster.Toon(true))
    m.Add("Start printen", (*) => Ronde.StartRun())
    m.Add("Stoppen", (*) => Ronde.Stop())
    m.Add()
    m.Add("Afsluiten", (*) => Venster.Sluit())
    m.Default := "Venster tonen"
    A_IconTip := AppTitel
}
