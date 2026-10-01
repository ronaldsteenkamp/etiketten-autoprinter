#NoEnv
#SingleInstance Force
#Persistent
SendMode Input
SetWorkingDir %A_ScriptDir%
SetTitleMatchMode, 2

;@Ahk2Exe-SetName Etiketten autoprinter
;@Ahk2Exe-SetDescription Etiketten autoprinter voor Pharmacom
;@Ahk2Exe-SetVersion 4.0.0

; =====================================================================
; Etiketten autoprinter voor Pharmacom
;
; Gebruik:
;   1. Selecteer in Pharmacom de juiste groep en zet de selectie op de
;      EERSTE patient in de aanschrijfbuffer.
;   2. Druk op Ctrl+E (of klik op Start in het venster).
;   3. Het aantal wordt uit "Patienten in aanschrijfbuffer (N)" gelezen.
;   4. Per patient:
;      - de regel in de aanschrijfbuffer wordt gekopieerd (Ctrl+C);
;        staat er een ONTSLAGDATUM, dan wordt de patient overgeslagen;
;      - Ctrl+B -> F4 (medicatiehistorie) -> pijl omhoog;
;      - vanaf daar omlaag zoeken naar de BOVENSTE regel met Ap = AN
;        (elke regel wordt met Ctrl+C gekopieerd en gecontroleerd);
;        geen AN-regel gevonden -> Escape en patient overslaan;
;      - Ctrl+P -> Alt+B -> Escape -> pijl omlaag (volgende patient).
;
; VEILIGHEID: kan een regel niet gekopieerd/herkend worden, dan stopt de
; app (hij gokt nooit welke regel geprint moet worden). Met de knop
; "Kopieertest" kun je vooraf controleren of het kopieren werkt.
;
; Stoppen: knop Stop, Ctrl+Shift+E, of een ander venster aanklikken.
; Afsluiten: het kruisje rechtsboven in het venster.
; =====================================================================

PharmacomTitle := "Pharmacom"
AppTitel := "Etiketten autoprinter"
IniFile := A_ScriptDir . "\Etiketten_autoprinter.ini"
LogFile := A_ScriptDir . "\Etiketten_autoprinter_log.txt"
FileDelete, %LogFile%

MaxZoekRegels := 40    ; hoeveel regels er max. naar beneden gezocht wordt naar AN
ClipWachtSec  := 0.5   ; max. wachttijd op een kopie (Ctrl+C) uit Pharmacom

; --- Tekens (via Chr, altijd goed ook in een .exe) ---
EUml    := Chr(235)     ; e met trema
Bol     := Chr(0x25CF)  ; bolletje
Mid     := Chr(0xB7)    ; middenpunt
Omhoog  := Chr(0x2191)
Omlaag  := Chr(0x2193)
Play    := Chr(0x25B6)
Blok    := Chr(0x25A0)
PlusMin := Chr(0xB1)
Kruis   := Chr(0x2715)
Streep  := Chr(0x2013)

; --- Kleuren ---
KlrKop    := "1E293B"
KlrAchter := "F8FAFC"
KlrTekst  := "0F172A"
KlrGrijs  := "64748B"
KlrLicht  := "94A3B8"
KlrBlauw  := "2563EB"
KlrGroen  := "16A34A"
KlrOranje := "EA580C"
KlrRood   := "DC2626"

; --- Wachttijden: [naam, standaard (ms), omschrijving] ---
Wachttijden := [ ["SleepNaKopie",    150,  "Na kopi" . EUml . "ren van een regel"]
    , ["SleepNaCtrlB",    500,  "Na Ctrl+B"]
    , ["SleepNaF4",       1200, "Na F4"]
    , ["SleepNaOmhoog",   300,  "Na pijl omhoog"]
    , ["SleepZoekOmlaag", 200,  "Zoeken naar AN: na pijl omlaag"]
    , ["SleepNaCtrlP",    25,   "Na Ctrl+P (printvenster)"]
    , ["SleepNaAltB",     25,   "Na Alt+B (afdrukken)"]
    , ["SleepNaEscape",   500,  "Na Escape"]
    , ["SleepNaOmlaag",   600,  "Na pijl omlaag (volgende)"] ]

Wt := {}
For i, w in Wachttijden
{
    k := w[1]
    d := w[2]
    IniRead, v, %IniFile%, Wachttijden, %k%, %d%
    If v is not integer
        v := d
    Wt[k] := v
}

IniRead, IniBevestigen, %IniFile%, Opties, Bevestigen, 1
IniRead, IniOntslag,    %IniFile%, Opties, OntslagOverslaan, 1
IniRead, IniZoekAN,     %IniFile%, Opties, ZoekAN, 1
IniRead, IniBovenop,    %IniFile%, Opties, Bovenop, 1

Bezig := false
Stoppen := false
StopReden := ""
PhPID := ""
Aantal := 0
Verwerkt := 0
Geprint := 0
Overgeslagen := 0
RunStart := 0

Gosub, MaakTray
Gosub, MaakGui
OnMessage(0x201, "KopSlepen")  ; venster verslepen via de kopbalk
Status("idle")
ZetStap(0)
Log("App gestart")
return  ; ===== einde auto-execute =====


; =====================================================================
; Sneltoetsen
; =====================================================================
#IfWinActive Pharmacom
^e::
    If (Bezig)
        return
    ; Wachten tot Ctrl en E los zijn, anders wordt F4 als Ctrl+F4 verstuurd
    ; (en dat sluit het venster!).
    KeyWait, Control
    KeyWait, e
    StartRun()
return
#IfWinActive

^+e::
    Gosub, StopKnop
return


; =====================================================================
; Het printen zelf
; =====================================================================
StartRun() {
    global
    Gui, 1:Submit, NoHide

    Gelezen := LeesAantal()
    If (Gelezen != "")
    {
        Aantal := Gelezen
        GuiControl, 1:, AantalEdit, %Aantal%
    }
    Else
        Aantal := AantalEdit

    If Aantal is not integer
        Aantal := 0
    If (Aantal < 1)
    {
        Status("fout", "Aantal niet gevonden. Vul het aantal zelf in en klik op Start.")
        Gui, 1:Show
        return
    }

    If (OptBevestigen)
    {
        MsgBox, 0x40024, %AppTitel%, % "Etiketten printen voor " . Aantal . " pati" . EUml . "nten?`n`nZorg dat de EERSTE pati" . EUml . "nt geselecteerd is."
        IfMsgBox, No
            return
    }

    WinActivate, %PharmacomTitle%
    WinWaitActive, %PharmacomTitle%,, 2
    If (ErrorLevel)
    {
        Status("fout", "Pharmacom kon niet geactiveerd worden. Staat het programma open?")
        Log("Pharmacom niet gevonden")
        return
    }
    WinGet, PhPID, PID, A
    Sleep, 300

    ; Klembord bewaren, na afloop terugzetten
    KlembordBewaard := ClipboardAll

    Bezig := true
    Stoppen := false
    StopReden := ""
    Verwerkt := 0
    Geprint := 0
    Overgeslagen := 0
    OverslaanLijst := ""
    RunStart := A_TickCount
    GuiControl, 1:Disable, StartBtn
    GuiControl, 1:Disable, AantalEdit
    GuiControl, 1:Disable, UitleesBtn
    GuiControl, 1:Disable, TestBtn
    GuiControl, 1:Enable, StopBtn
    GuiControl, 1:+Range0-%Aantal%, Voortgang
    ZetVoortgang(KlrBlauw)
    GuiControl, 1:, Teller, 0 / %Aantal%
    SetTimer, TijdTimer, 500
    Gosub, TijdTimer

    Log("Start: " . Aantal . " pati" . EUml . "nten (ontslag overslaan: " . (OptOntslag ? "ja" : "nee") . ", zoek AN: " . (OptZoekAN ? "ja" : "nee") . ")")
    Instel := "Wachttijden (ms):"
    For i, w in Wachttijden
        Instel .= " " . w[1] . "=" . Wt[w[1]]
    LogBestand(Instel)

    Afgebroken := false
    Loop, %Aantal%
    {
        Nr := A_Index
        Status("bezig", "Pati" . EUml . "nt " . Nr . " van " . Aantal . "  " . Mid . "  " . Geprint . " geprint, " . Overgeslagen . " overgeslagen")
        ZetStap(0)

        ; --- 1. Aanschrijfbuffer-regel controleren op ontslagdatum ---
        PatLabel := "Pati" . EUml . "nt " . Nr
        If (OptOntslag)
        {
            ZetStap(1)
            Tekst := KopieerRij()
            If (Stoppen || StopReden != "")
            {
                Afgebroken := true
                break
            }
            Rij := LeesBufferRij(Tekst)
            If (!Rij.ok)
            {
                StopReden := "de regel in de aanschrijfbuffer kon niet gelezen worden (zie Kopieertest)"
                LogBestand("  Bufferregel niet herkend - vorm: " . VormVanRij(Tekst))
                Afgebroken := true
                break
            }
            PatLabel := "Pat.nr " . Rij.patnr
            If (Rij.ontslag != "")
            {
                Overgeslagen++
                OverslaanLijst .= "- " . PatLabel . ": ontslagdatum " . Rij.ontslag . "`n"
                Log(PatLabel . " overgeslagen (ontslagdatum)")
                Gosub, NaarVolgende
                If (Afgebroken)
                    break
                continue
            }
        }

        ; --- 2. Dossier en medicatiehistorie openen ---
        If !Stap("^b",   Wt.SleepNaCtrlB,  "Ctrl+B", 2)
        {
            Afgebroken := true
            break
        }
        If !Stap("{F4}", Wt.SleepNaF4,     "F4", 3)
        {
            Afgebroken := true
            break
        }
        If !Stap("{Up}", Wt.SleepNaOmhoog, "Pijl omhoog", 4)
        {
            Afgebroken := true
            break
        }

        ; --- 3. Bovenste regel met Ap = AN zoeken ---
        If (OptZoekAN)
        {
            ZetStap(5)
            Gevonden := ZoekAN()
            If (Stoppen || StopReden != "")
            {
                Afgebroken := true
                break
            }
            If (!Gevonden)
            {
                ; Geen AN-regel: dossier sluiten en patient overslaan
                If !Stap("{Escape}", Wt.SleepNaEscape, "Escape (geen AN)", 8)
                {
                    Afgebroken := true
                    break
                }
                Overgeslagen++
                OverslaanLijst .= "- " . PatLabel . ": geen regel met Ap = AN gevonden`n"
                Log(PatLabel . " overgeslagen (geen AN-regel)")
                Gosub, NaarVolgende
                If (Afgebroken)
                    break
                continue
            }
        }

        ; --- 4. Printen ---
        If !Stap("^p",       Wt.SleepNaCtrlP,  "Ctrl+P", 6)
        {
            Afgebroken := true
            break
        }
        If !Stap("!b",       Wt.SleepNaAltB,   "Alt+B - afdrukken", 7)
        {
            Afgebroken := true
            break
        }
        If !Stap("{Escape}", Wt.SleepNaEscape, "Escape", 8)
        {
            Afgebroken := true
            break
        }

        Geprint++
        Log(PatLabel . " geprint")
        Gosub, NaarVolgende
        If (Afgebroken)
            break
    }

    ; --- Afronden ---
    Bezig := false
    SetTimer, TijdTimer, Off
    Duur := FmtTijd((A_TickCount - RunStart) // 1000)
    ZetStap(0)
    GuiControl, 1:Enable, StartBtn
    GuiControl, 1:Enable, AantalEdit
    GuiControl, 1:Enable, UitleesBtn
    GuiControl, 1:Enable, TestBtn
    GuiControl, 1:Disable, StopBtn
    Clipboard := KlembordBewaard
    KlembordBewaard := ""

    Samenvatting := Geprint . " geprint, " . Overgeslagen . " overgeslagen"

    If (Afgebroken)
    {
        If (StopReden = "")
            StopReden := "gestopt door gebruiker"
        ZetVoortgang(KlrOranje)
        GuiControl, 1:, TijdTekst, Gestopt na %Duur%
        Status("gestopt", "Gestopt bij pati" . EUml . "nt " . (Verwerkt + 1) . " van " . Aantal . " - " . StopReden . ". (" . Samenvatting . ")")
        Log("Gestopt: " . StopReden . " (" . Samenvatting . ")")
        If (OverslaanLijst != "")
            MsgBox, 0x40030, %AppTitel%, % "Gestopt: " . StopReden . ".`n`n" . Samenvatting . ".`n`nOvergeslagen - handmatig controleren:`n" . OverslaanLijst
        return
    }

    ZetVoortgang(KlrGroen)
    GuiControl, 1:, TijdTekst, Klaar in %Duur%
    Status("klaar", Samenvatting . ".")
    Log("Klaar: " . Samenvatting . " in " . Duur)
    If (OverslaanLijst != "")
        MsgBox, 0x40040, %AppTitel%, % "Klaar! " . Samenvatting . ".`n`nOvergeslagen - handmatig controleren:`n" . OverslaanLijst
    Else
        TrayTip, %AppTitel%, Klaar! %Samenvatting%., 5, 1
}

; Telt de patient als verwerkt en gaat (als er nog een volgende is) met
; pijl omlaag naar de volgende regel in de aanschrijfbuffer.
NaarVolgende:
    Verwerkt++
    ZetVoortgang(KlrBlauw)
    GuiControl, 1:, Teller, %Verwerkt% / %Aantal%
    If (Verwerkt < Aantal)
    {
        If !Stap("{Down}", Wt.SleepNaOmlaag, "Volgende pati" . EUml . "nt", 9)
            Afgebroken := true
    }
return

; Zoekt vanaf de huidige regel omlaag naar de bovenste regel met Ap = AN.
; Geeft true als die geselecteerd staat, false als er geen is. Bij een
; fout (kopieren mislukt, regel niet herkend) wordt StopReden gezet.
ZoekAN() {
    global
    local Vorige, Tekst, Ap
    Vorige := ""
    Loop, %MaxZoekRegels%
    {
        Tekst := KopieerRij()
        If (Stoppen || StopReden != "")
            return false
        Ap := LeesHistorieAp(Tekst)
        If (Ap = "?")
        {
            StopReden := "een regel in de medicatiehistorie kon niet gelezen worden (zie Kopieertest)"
            LogBestand("  Historieregel niet herkend - vorm: " . VormVanRij(Tekst))
            return false
        }
        LogBestand("  Regel " . A_Index . ": Ap = '" . Ap . "'")
        If (Ap = "AN")
            return true
        ; Onderaan de lijst: pijl omlaag verandert niets meer
        If (Tekst = Vorige)
            return false
        Vorige := Tekst
        If !Stap("{Down}", Wt.SleepZoekOmlaag, "Zoek AN: omlaag", 5)
            return false
    }
    return false
}

; Kopieert de geselecteerde regel in Pharmacom. Geeft "" terug (en zet
; StopReden) als dat niet lukt.
KopieerRij() {
    global Stoppen, StopReden, PhPID, ClipWachtSec, Wt
    If (Stoppen)
    {
        StopReden := "gestopt door gebruiker"
        return ""
    }
    If !WinActive("ahk_pid " . PhPID)
    {
        StopReden := "Pharmacom was niet meer het actieve venster"
        return ""
    }
    Clipboard := ""
    Send, ^c
    ClipWait, %ClipWachtSec%
    If (ErrorLevel)
    {
        StopReden := "kopi" . Chr(235) . "ren (Ctrl+C) uit Pharmacom leverde niets op (zie Kopieertest)"
        LogBestand("  Ctrl+C leverde niets op")
        return ""
    }
    Tekst := Clipboard
    Wacht(Wt.SleepNaKopie)
    return Tekst
}

; Splitst gekopieerde tekst in velden. Als Pharmacom een kopregel meestuurt,
; wordt die apart teruggegeven (Kop), anders is Kop leeg.
SplitsRij(Tekst) {
    Res := {Kop: "", Velden: [], Scheiding: "", Regels: 0}
    Tekst := Trim(Tekst, "`r`n")
    Regels := StrSplit(Tekst, "`n", "`r")
    Res.Regels := Regels.Length()

    ; Scheidingsteken bepalen: tab, puntkomma of (minstens 2) spaties
    If InStr(Tekst, "`t")
        Res.Scheiding := "tab"
    Else If InStr(Tekst, ";")
        Res.Scheiding := "puntkomma"
    Else
        Res.Scheiding := "spaties"

    ; Is de eerste regel een kopregel (met kolomnamen)?
    EersteVelden := SplitsVelden(Regels[1], Res.Scheiding)
    IsKop := false
    For i, v in EersteVelden
        If (v = "Pat.nr" || v = "Ontslagdatum" || v = "Etiketnaam")
            IsKop := true

    If (IsKop && Regels.Length() >= 2)
    {
        Res.Kop := EersteVelden
        Res.Velden := SplitsVelden(Regels[2], Res.Scheiding)
    }
    Else
        Res.Velden := EersteVelden
    return Res
}

SplitsVelden(Regel, Scheiding) {
    If (Scheiding = "tab")
        Velden := StrSplit(Regel, "`t")
    Else If (Scheiding = "puntkomma")
        Velden := StrSplit(Regel, ";")
    Else
        Velden := StrSplit(RegExReplace(Trim(Regel), " {2,}", "`t"), "`t")
    For i, v in Velden
        Velden[i] := Trim(v, " `t""")
    return Velden
}

; Beschrijft de VORM van gekopieerde tekst zonder de inhoud (dus zonder
; patientgegevens), voor in het logbestand: per veld leeg/datum/getal/tekst.
VormVanRij(Tekst) {
    R := SplitsRij(Tekst)
    Vorm := StrLen(Tekst) . " tekens, " . R.Regels . " regel(s), scheiding=" . R.Scheiding . ", kopregel=" . (IsObject(R.Kop) ? "ja" : "nee") . ", velden:"
    For i, v in R.Velden
    {
        If (v = "")
            t := "leeg"
        Else If (IsDatum(v))
            t := "datum"
        Else If (RegExMatch(v, "^\d+$"))
            t := "getal"
        Else
            t := "tekst(" . StrLen(v) . ")"
        Vorm .= " " . i . "=" . t
    }
    return Vorm
}

; Datum in de vorm 25-08-1963, 25/08/1963, 25.08.1963, 5-8-63 of 1963-08-25
IsDatum(v) {
    return RegExMatch(v, "^(\d{1,2}[-/.]\d{1,2}[-/.](\d{2}|\d{4})|\d{4}-\d{2}-\d{2})$") > 0
}

KolomIndex(Kop, Naam) {
    If (!IsObject(Kop))
        return 0
    For i, v in Kop
        If (v = Naam)
            return i
    return 0
}

; Aanschrijfbuffer-regel: {ok, patnr, ontslag}.
; Met kopregel: op kolomnaam. Zonder kopregel: Startdatum is de eerste
; datum die direct na het (numerieke) Pat.nr staat, Ontslagdatum is het
; veld daarna.
LeesBufferRij(Tekst) {
    Res := {ok: false, patnr: "", ontslag: ""}
    If (Tekst = "")
        return Res
    R := SplitsRij(Tekst)
    F := R.Velden
    iO := KolomIndex(R.Kop, "Ontslagdatum")
    iP := KolomIndex(R.Kop, "Pat.nr")
    If (iO && iP)
    {
        Res.ok := true
        Res.patnr := F[iP]
        Res.ontslag := F[iO]
        return Res
    }
    Loop, % F.Length() - 1
    {
        i := A_Index + 1
        If (IsDatum(F[i]) && RegExMatch(F[i-1], "^\d{3,10}$"))
        {
            Ontslag := F[i+1]
            If (Ontslag != "" && !IsDatum(Ontslag))
                return Res  ; veld na Startdatum is geen datum -> niet zeker, niet gokken
            Res.ok := true
            Res.patnr := F[i-1]
            Res.ontslag := Ontslag
            return Res
        }
    }
    return Res
}

; Medicatiehistorie-regel: geeft de waarde van kolom Ap, of "?" als de
; regel niet herkend wordt.
; Met kopregel: kolom "Ap". Zonder kopregel: het eerste veld met een datum
; is "Laatste V/A"; daarna volgen Etiketnaam, Labeler, CF, Ap en
; Th. einddatum (datum of leeg) - dat laatste wordt als controle gebruikt.
LeesHistorieAp(Tekst) {
    If (Tekst = "")
        return "?"
    R := SplitsRij(Tekst)
    F := R.Velden
    iA := KolomIndex(R.Kop, "Ap")
    If (iA && KolomIndex(R.Kop, "Etiketnaam"))
        return F[iA]
    For i, v in F
    {
        If (IsDatum(v))
        {
            Ap := F[i+4]
            Eind := F[i+5]
            If (StrLen(Ap) <= 3 && (Eind = "" || IsDatum(Eind)))
                return Ap
            return "?"
        }
    }
    return "?"
}

; Verstuurt een toets, maar alleen als er niet gestopt is en Pharmacom
; (of een venster van Pharmacom zelf, zoals het printvenster) actief is.
Stap(Toets, Ms, Label, Idx) {
    global Stoppen, StopReden, PhPID
    If (Stoppen)
    {
        StopReden := "gestopt door gebruiker"
        return false
    }
    If !WinActive("ahk_pid " . PhPID)
    {
        StopReden := "Pharmacom was niet meer het actieve venster"
        return false
    }
    ZetStap(Idx)
    Send, %Toets%
    LogBestand("  " . Label . " verstuurd, wacht " . Ms . " ms")
    Wacht(Ms)
    return true
}

; Wacht in kleine stukjes, zodat Stop direct reageert.
Wacht(Ms) {
    global Stoppen
    If Ms is not integer
        Ms := 1000
    Eind := A_TickCount + Ms
    While (A_TickCount < Eind && !Stoppen)
        Sleep, 25
}

LeesAantal() {
    global PharmacomTitle
    WinGetText, T, %PharmacomTitle%
    If (RegExMatch(T, "i)aanschrijfbuffer\s*\((\d+)\)", M))
        return M1
    return ""
}

FmtTijd(Sec) {
    Min := Sec // 60
    Rest := Mod(Sec, 60)
    return Min . ":" . SubStr("0" . Rest, -1)
}

TijdTimer:
    Verstreken := (A_TickCount - RunStart) // 1000
    If (Verwerkt > 0)
        Resterend := Round((A_TickCount - RunStart) / Verwerkt * (Aantal - Verwerkt) / 1000)
    Else
    {
        SomWacht := 0
        For i, w in Wachttijden
            SomWacht += Wt[w[1]]
        Resterend := Round(SomWacht * Aantal / 1000) - Verstreken
        If (Resterend < 0)
            Resterend := 0
    }
    GuiControl, 1:, TijdTekst, % FmtTijd(Verstreken) . " verstreken`nnog " . PlusMin . " " . FmtTijd(Resterend)
return


; =====================================================================
; Kopieertest: controleert of Pharmacom de geselecteerde regel met
; Ctrl+C kopieert en of de app die regel herkent. Er wordt niets geprint.
; =====================================================================
Kopieertest:
    If (Bezig)
        return
    WinActivate, %PharmacomTitle%
    WinWaitActive, %PharmacomTitle%,, 2
    If (ErrorLevel)
    {
        Status("fout", "Pharmacom kon niet geactiveerd worden.")
        return
    }
    WinGet, PhPID, PID, A
    Sleep, 300
    KlembordBewaard := ClipboardAll
    StopReden := ""
    Stoppen := false
    Tekst := KopieerRij()
    Clipboard := KlembordBewaard
    KlembordBewaard := ""

    If (Tekst = "")
    {
        Status("fout", "Kopieertest: Ctrl+C leverde niets op.")
        MsgBox, 0x40030, Kopieertest, % "Ctrl+C in Pharmacom leverde niets op het klembord op.`n`nKlik eerst een regel aan in de aanschrijfbuffer of de medicatiehistorie en probeer het opnieuw. Werkt het dan nog niet, zet dan de vinkjes 'Ontslagdatum overslaan' en 'Ap = AN printen' uit."
        return
    }

    Ap := LeesHistorieAp(Tekst)
    Rij := LeesBufferRij(Tekst)
    If (Ap != "?")
    {
        Uitleg := "Medicatiehistorie-regel herkend.`n`nAp = '" . Ap . "'  ->  " . (Ap = "AN" ? "deze regel zou geprint worden." : "deze regel wordt overgeslagen bij het zoeken.")
        Status("idle", "Kopieertest geslaagd (medicatiehistorie).")
    }
    Else If (Rij.ok)
    {
        Uitleg := "Aanschrijfbuffer-regel herkend.`n`nPat.nr: " . Rij.patnr . "`nOntslagdatum: " . (Rij.ontslag = "" ? "(leeg)  ->  wordt geprint." : Rij.ontslag . "  ->  wordt overgeslagen.")
        Status("idle", "Kopieertest geslaagd (aanschrijfbuffer).")
    }
    Else
    {
        R := SplitsRij(Tekst)
        Uitleg := "De regel werd gekopieerd, maar NIET herkend.`n`n"
        Uitleg .= "Aantal regels gekopieerd: " . R.Regels . "`nScheidingsteken: " . R.Scheiding . "`nAantal velden: " . R.Velden.Length() . "`n`nGekopieerde velden:`n"
        For i, v in R.Velden
            Uitleg .= i . ": " . v . "`n"
        If (StrLen(Uitleg) > 1500)
            Uitleg := SubStr(Uitleg, 1, 1500) . "`n..."
        Status("fout", "Kopieertest: regel niet herkend.")
    }
    MsgBox, 0x40040, Kopieertest, %Uitleg%
return


; =====================================================================
; Venster
; =====================================================================
MaakGui:
    Gui, 1:+HwndGuiHwnd -Caption +Border
    Gui, 1:Color, %KlrAchter%, FFFFFF
    Gui, 1:Margin, 20, 20

    ; --- Kopbalk (eerst smal, na het bepalen van de venstergrootte wordt
    ; hij over de volle breedte getrokken) ---
    Gui, 1:Add, Progress, x0 y0 w10 h74 Background%KlrKop% Disabled vKopBalk, 0
    Gui, 1:Font, s15 bold cFFFFFF, Segoe UI
    Gui, 1:Add, Text, x20 y14 w290 BackgroundTrans, Etiketten autoprinter
    Gui, 1:Font, s9 norm cCBD5E1, Segoe UI
    Gui, 1:Add, Text, x20 y+2 w290 BackgroundTrans, Pharmacom %Mid% aanschrijfbuffer %Mid% v4.0
    ; Minimaliseren en afsluiten
    Gui, 1:Font, s12 norm cCBD5E1, Segoe UI
    Gui, 1:Add, Text, x326 y8 w26 h26 Center BackgroundTrans gMinimaliseer, %Streep%
    Gui, 1:Font, s12 norm cFFFFFF, Segoe UI
    Gui, 1:Add, Text, x356 y8 w26 h26 Center BackgroundTrans gGuiClose, %Kruis%

    ; --- Status ---
    Gui, 1:Font, s16 c%KlrBlauw%, Segoe UI
    Gui, 1:Add, Text, x20 y92 w24 vDot, %Bol%
    Gui, 1:Font, s12 bold c%KlrTekst%, Segoe UI
    Gui, 1:Add, Text, x46 y96 w334 vStatusTekst, Klaar voor start
    Gui, 1:Font, s9 norm c%KlrGrijs%, Segoe UI
    Gui, 1:Add, Text, x46 y+2 w334 h48 vStatusSub,

    ; --- Teller + tijd ---
    Gui, 1:Font, s26 bold c%KlrTekst%, Segoe UI
    Gui, 1:Add, Text, x20 y+8 w200 vTeller, 0 / 0
    Gui, 1:Font, s9 norm c%KlrGrijs%, Segoe UI
    Gui, 1:Add, Text, x220 yp+12 w160 h34 Right vTijdTekst,

    ; --- Voortgangsbalk ---
    Gui, 1:Add, Progress, x20 y+10 w360 h8 -Theme vVoortgang c%KlrBlauw% BackgroundE2E8F0 Range0-1, 0

    ; --- Stappen van de huidige patient ---
    StapNamen := ["Ontslag?", "Ctrl+B", "F4", Omhoog, "AN", "Ctrl+P", "Alt+B", "Esc", Omlaag]
    Gui, 1:Font, s8 norm c%KlrLicht%, Segoe UI
    For i, naam in StapNamen
    {
        If (i = 1)
            Gui, 1:Add, Text, x20 y+10 w52 Center vStap%i%, %naam%
        Else
            Gui, 1:Add, Text, x+0 yp w38 Center vStap%i%, %naam%
    }

    ; --- Aantal ---
    Gui, 1:Font, s9 norm c%KlrTekst%, Segoe UI
    Gui, 1:Add, Text, x20 y+20, Aantal pati%EUml%nten
    Gui, 1:Add, Edit, x+10 yp-3 w60 Number vAantalEdit, 0
    Gui, 1:Add, UpDown, Range0-999, 0
    Gui, 1:Add, Button, x+10 yp-1 w150 h26 gUitlezen vUitleesBtn, Uit Pharmacom lezen

    ; --- Grote knoppen ---
    Gui, 1:Font, s11 bold, Segoe UI
    Gui, 1:Add, Button, x20 y+16 w226 h44 gStartKnop vStartBtn, %Play%   Start
    Gui, 1:Add, Button, x+10 yp w124 h44 gStopKnop vStopBtn Disabled, %Blok%   Stop
    Gui, 1:Font, s8 norm c%KlrLicht%, Segoe UI
    Gui, 1:Add, Text, x20 y+6 w360 Center, Ctrl+E  starten   %Mid%   Ctrl+Shift+E  stoppen

    Gui, 1:Add, Text, x20 y+14 w360 h1 0x10

    ; --- Opties ---
    Gui, 1:Font, s9 norm c%KlrTekst%, Segoe UI
    Gui, 1:Add, Checkbox, x20 y+14 vOptOntslag gOptWijzig Checked%IniOntslag%, Pati%EUml%nten met een ontslagdatum overslaan
    Gui, 1:Add, Checkbox, x20 y+6 vOptZoekAN gOptWijzig Checked%IniZoekAN%, Bovenste regel met Ap = AN printen
    Gui, 1:Add, Checkbox, x20 y+6 vOptBevestigen gOptWijzig Checked%IniBevestigen%, Eerst om bevestiging vragen
    Gui, 1:Add, Checkbox, x20 y+6 vOptBovenop gOptWijzig Checked%IniBovenop%, Venster altijd bovenop
    Gui, 1:Add, Button, x20 y+12 w110 h26 gKopieertest vTestBtn, Kopieertest
    Gui, 1:Add, Link, x+16 yp+5 gInstellingen, <a>Wachttijden aanpassen</a>
    Gui, 1:Add, Link, x+16 yp gOpenLog, <a>Logbestand openen</a>

    ; --- Logboek ---
    Gui, 1:Font, s9 bold c%KlrTekst%, Segoe UI
    Gui, 1:Add, Text, x20 y+18, Logboek
    Gui, 1:Font, s9 norm c334155, Segoe UI
    Gui, 1:Add, ListView, x20 y+6 w360 r6 vLogLV -Hdr -Multi NoSort BackgroundFFFFFF, Tijd|Melding
    LV_ModifyCol(1, 64)
    LV_ModifyCol(2, 272)

    ; --- Rechtsonder op het scherm, zonder Pharmacom de focus af te pakken ---
    Gui, 1:Show, Hide AutoSize, %AppTitel%
    GuiControl, 1:Move, KopBalk, w400
    DetectHiddenWindows, On
    WinGetPos,,, GW, GH, ahk_id %GuiHwnd%
    DetectHiddenWindows, Off
    SysGet, WA, MonitorWorkArea
    PosX := WARight - GW - 12
    PosY := WABottom - GH - 12
    If (PosY < WATop)
        PosY := WATop
    If PosX is integer
    {
        If PosY is integer
            Gui, 1:Show, x%PosX% y%PosY% NoActivate
        Else
            Gui, 1:Show, NoActivate
    }
    Else
        Gui, 1:Show, NoActivate
    If (IniBovenop)
        Gui, 1:+AlwaysOnTop
return

; Venster verslepen door in de donkere kopbalk te klikken (het venster
; heeft geen gewone titelbalk meer).
KopSlepen(wParam, lParam, Msg, Hwnd) {
    global GuiHwnd
    CoordMode, Mouse, Screen
    MouseGetPos, MX, MY, MWin
    If (MWin != GuiHwnd)
        return
    WinGetPos, WX, WY,,, ahk_id %GuiHwnd%
    ; Alleen in de kopbalk, en niet op de knopjes rechtsboven
    If (MY - WY < 74 && MX - WX < 320)
        PostMessage, 0xA1, 2,,, ahk_id %GuiHwnd%
}

Status(Fase, Sub := "") {
    global
    local Kleuren, Koppen, Kleur, Kop
    Kleuren := {idle: KlrBlauw, bezig: KlrGroen, gestopt: KlrOranje, klaar: KlrGroen, fout: KlrRood}
    Koppen  := {idle: "Klaar voor start", bezig: "Bezig met printen...", gestopt: "Gestopt", klaar: "Klaar!", fout: "Let op"}
    If (Sub = "" && Fase = "idle")
        Sub := "Selecteer de eerste pati" . EUml . "nt in Pharmacom en druk op Ctrl+E."
    Kleur := Kleuren[Fase]
    Kop := Koppen[Fase]
    GuiControl, 1:+c%Kleur%, Dot
    GuiControl, 1:, Dot, %Bol%
    GuiControl, 1:, StatusTekst, %Kop%
    GuiControl, 1:, StatusSub, %Sub%
    Menu, Tray, Tip, %AppTitel% - %Kop%
}

; Markeert de stap die nu bezig is: eerdere stappen groen, huidige blauw
; en vet, latere grijs. Idx 0 = alles grijs.
ZetStap(Idx) {
    global KlrGroen, KlrBlauw, KlrLicht, KlrTekst
    Loop, 9
    {
        If (Idx > 0 && A_Index < Idx)
            Gui, 1:Font, s8 norm c%KlrGroen%, Segoe UI
        Else If (A_Index = Idx)
            Gui, 1:Font, s8 bold c%KlrBlauw%, Segoe UI
        Else
            Gui, 1:Font, s8 norm c%KlrLicht%, Segoe UI
        GuiControl, 1:Font, Stap%A_Index%
    }
    Gui, 1:Font, s9 norm c%KlrTekst%, Segoe UI
}

ZetVoortgang(Kleur) {
    global Verwerkt
    GuiControl, 1:+c%Kleur%, Voortgang
    GuiControl, 1:, Voortgang, % Verwerkt + 0
}

; Schrijft een regel naar het logbestand, met tijd tot op de milliseconde.
LogBestand(Msg) {
    global LogFile
    FormatTime, ts,, HH:mm:ss
    FileAppend, %ts%.%A_MSec% - %Msg%`n, %LogFile%, UTF-8
}

Log(Msg) {
    LogBestand(Msg)
    Gui, 1:Default
    Gui, 1:ListView, LogLV
    FormatTime, ts,, HH:mm:ss
    LV_Insert(1, "", ts, Msg)
    If (LV_GetCount() > 200)
        LV_Delete(201)
}

StartKnop:
    If (Bezig)
        return
    StartRun()
return

StopKnop:
    If (Bezig)
    {
        Stoppen := true
        Status("gestopt", "Wordt gestopt...")
    }
return

Uitlezen:
    n := LeesAantal()
    If (n = "")
        Status("fout", "Kon het aantal niet uit Pharmacom lezen. Staat de aanschrijfbuffer open? Vul het anders zelf in.")
    Else
    {
        GuiControl, 1:, AantalEdit, %n%
        GuiControl, 1:, Teller, 0 / %n%
        Status("idle", n . " pati" . EUml . "nten gevonden. Selecteer de eerste en druk op Ctrl+E.")
        Log("Aantal uitgelezen: " . n)
    }
return

OptWijzig:
    Gui, 1:Submit, NoHide
    IniWrite, %OptBevestigen%, %IniFile%, Opties, Bevestigen
    IniWrite, %OptOntslag%,    %IniFile%, Opties, OntslagOverslaan
    IniWrite, %OptZoekAN%,     %IniFile%, Opties, ZoekAN
    IniWrite, %OptBovenop%,    %IniFile%, Opties, Bovenop
    If (OptBovenop)
        Gui, 1:+AlwaysOnTop
    Else
        Gui, 1:-AlwaysOnTop
return

OpenLog:
    If FileExist(LogFile)
        Run, %LogFile%
return

Minimaliseer:
    Gui, 1:Minimize
return

ToonVenster:
    Gui, 1:Show
return

GuiClose:
    If (Bezig)
    {
        MsgBox, 0x40034, %AppTitel%, Er wordt nog geprint. Toch afsluiten?
        IfMsgBox, No
            return
        Stoppen := true
    }
    ExitApp
return


; =====================================================================
; Wachttijden-venster
; =====================================================================
Instellingen:
    Gui, 2:Destroy
    Gui, 2:+Owner1 +AlwaysOnTop -MinimizeBox
    Gui, 2:Color, %KlrAchter%, FFFFFF
    Gui, 2:Margin, 20, 18
    Gui, 2:Font, s12 bold c%KlrTekst%, Segoe UI
    Gui, 2:Add, Text, xm w320, Wachttijden
    Gui, 2:Font, s9 norm c%KlrGrijs%, Segoe UI
    Gui, 2:Add, Text, xm y+4 w320, In milliseconden (1000 = 1 seconde). Verhoog een waarde als Pharmacom een stap niet bijbeent.
    Gui, 2:Font, s9 norm c%KlrTekst%, Segoe UI
    For i, w in Wachttijden
    {
        k := w[1]
        v := Wt[k]
        lbl := w[3]
        If (i = 1)
            Gui, 2:Add, Text, xm y+16 w220, %lbl%
        Else
            Gui, 2:Add, Text, xm y+12 w220, %lbl%
        Gui, 2:Add, Edit, x+10 yp-3 w70 Number Right vIn_%k%, %v%
        Gui, 2:Add, Text, x+6 yp+3 c%KlrGrijs%, ms
    }
    Gui, 2:Add, Button, xm y+22 w100 h30 Default gInstOpslaan, Opslaan
    Gui, 2:Add, Button, x+10 yp w100 h30 gInstStandaard, Standaard
    Gui, 2:Add, Button, x+10 yp w100 h30 g2GuiClose, Annuleren
    Gui, 2:Show,, Wachttijden
return

InstOpslaan:
    Gui, 2:Submit
    For i, w in Wachttijden
    {
        k := w[1]
        v := In_%k%
        If v is not integer
            continue
        Wt[k] := v
        IniWrite, %v%, %IniFile%, Wachttijden, %k%
    }
    Gui, 2:Destroy
    Log("Wachttijden opgeslagen")
return

InstStandaard:
    For i, w in Wachttijden
    {
        k := w[1]
        d := w[2]
        GuiControl, 2:, In_%k%, %d%
    }
return

2GuiClose:
2GuiEscape:
    Gui, 2:Destroy
return


; =====================================================================
; Systeemvak (icoon rechtsonder bij de klok)
; =====================================================================
MaakTray:
    If (!A_IsCompiled)
        Menu, Tray, Icon, shell32.dll, 17
    Menu, Tray, NoStandard
    Menu, Tray, Add, Venster tonen, ToonVenster
    Menu, Tray, Add, Start  (Ctrl+E), StartKnop
    Menu, Tray, Add, Stop  (Ctrl+Shift+E), StopKnop
    Menu, Tray, Add
    Menu, Tray, Add, Afsluiten, GuiClose
    Menu, Tray, Default, Venster tonen
    Menu, Tray, Tip, %AppTitel%
return
