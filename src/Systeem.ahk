; =====================================================================
; Systeem: vergrendeling, wakker blijven, waakhond en geheugen van Pharmacom
;
; - Sessie: is de computer vergrendeld? Dan bestaan er voor programma's
;   geen vensters en kan de app niets in Pharmacom doen. Bij ontgrendelen
;   kijkt de planning meteen of er een uitgestelde ronde klaarstaat.
; - Wakker: tijdens een ronde en rond een geplande tijd vraagt de app
;   Windows om niet in slaapstand te gaan (de aan/uit-knop en dichtklappen
;   werken gewoon).
; - Waakhond: een tweede, onzichtbaar proces (dezelfde .exe met /waakhond).
;   De app geeft elke seconde een levensteken. Blijft dat 20 s uit terwijl
;   toetsenbord en muis geblokkeerd zijn (de app hangt, bijv. in de
;   koppeling met Pharmacom), dan sluit de waakhond de app af. Daarmee is
;   de blokkade weg.
; - Geheugen: het geheugengebruik van Pharmacom gaat elk uur in het log, om
;   te zien of de bewaking Pharmacom in de loop van de dag zwaarder maakt.
; =====================================================================

class Sessie {
    ; Vergrendeld (of schermbeveiliging actief): het invoerbureaublad is dan
    ; niet het gewone bureaublad en kan niet geactiveerd worden.
    static Vergrendeld() {
        h := DllCall("OpenInputDesktop", "UInt", 0, "Int", 0, "UInt", 0x0100, "Ptr")   ; DESKTOP_SWITCHDESKTOP
        if !h
            return true
        Ok := DllCall("SwitchDesktop", "Ptr", h)
        DllCall("CloseDesktop", "Ptr", h)
        return !Ok
    }

    ; Meldingen van Windows bij vergrendelen en ontgrendelen
    static Volg() {
        try DllCall("wtsapi32\WTSRegisterSessionNotification", "Ptr", A_ScriptHwnd, "UInt", 0)   ; NOTIFY_FOR_THIS_SESSION
        OnMessage 0x02B1, SessieWijziging   ; WM_WTSSESSION_CHANGE
    }
}

SessieWijziging(wParam, *) {
    if wParam = 7          ; WTS_SESSION_LOCK
        Log("Computer vergrendeld")
    else if wParam = 8 {   ; WTS_SESSION_UNLOCK
        Log("Computer ontgrendeld")
        SetTimer PlanningTik, -3000
    }
}

class Wakker {
    static Redenen := Map()

    ; Reden = "ronde" of "planning"; zolang er een reden is, blijft Windows wakker
    static Zet(Reden, Aan) {
        Was := this.Redenen.Count > 0
        if Aan
            this.Redenen[Reden] := true
        else if this.Redenen.Has(Reden)
            this.Redenen.Delete(Reden)
        Nu := this.Redenen.Count > 0
        if Nu = Was
            return
        ; ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED, of alleen ES_CONTINUOUS (weer vrij)
        DllCall("SetThreadExecutionState", "UInt", Nu ? 0x80000003 : 0x80000000)
        Log(Nu ? "Slaapstand uitgesteld (" Reden ")" : "Slaapstand weer toegestaan")
    }
}

class Waakhond {
    static Hart := "EtikettenHartslag", Blok := "EtikettenBlok", Pat := "EtikettenPatnr"
    static Grens := 20000      ; ms zonder levensteken voordat de app afgesloten wordt
    static Pid := 0

    ; --- In de app ----------------------------------------------------------
    static Start() {
        this.Hartslag()
        SetTimer WaakhondHartslag, 1000
        Mijn := DllCall("GetCurrentProcessId")
        Cmd := (A_IsCompiled ? '"' A_ScriptFullPath '"' : '"' A_AhkPath '" "' A_ScriptFullPath '"')
            . " /waakhond " Mijn " " A_ScriptHwnd
        try {
            Run Cmd, A_ScriptDir, , &Pid
            this.Pid := Pid
            Log("Waakhond gestart (proces " Pid ")")
        } catch as e
            Log("Waakhond kon niet starten: " e.Message)
    }

    static Hartslag() => DllCall("SetProp", "Ptr", A_ScriptHwnd, "Str", this.Hart, "Ptr", A_TickCount & 0x7FFFFFFF)
    static Geblokkeerd(Aan) => DllCall("SetProp", "Ptr", A_ScriptHwnd, "Str", this.Blok, "Ptr", Aan ? 1 : 0)
    static Patient(Patnr) => DllCall("SetProp", "Ptr", A_ScriptHwnd, "Str", this.Pat, "Ptr", IsInteger(Patnr) ? Integer(Patnr) : 0)

    ; --- In het waakhondproces (geen venster, geen icoon) -------------------
    static Bewaak(Pid, Hwnd) {
        A_IconHidden := true
        DetectHiddenWindows true
        ; Andere titel, zodat een nieuwe start van de app hem niet voor de app aanziet
        try WinSetTitle AppTitel " waakhond", "ahk_id " A_ScriptHwnd
        Inst.Lees()   ; voor de map van het log (gedeelde map)
        Opslag.LogMap := Opslag.Hoofdmap() "\Gegevens\Log"
        loop {
            Sleep 1000
            if !ProcessExist(Pid) || !WinExist("ahk_id " Hwnd)
                return
            if !DllCall("GetProp", "Ptr", Hwnd, "Str", this.Blok, "Ptr")
                continue
            Laatst := DllCall("GetProp", "Ptr", Hwnd, "Str", this.Hart, "Ptr")
            Stil := ((A_TickCount & 0x7FFFFFFF) - Laatst) & 0x7FFFFFFF
            if Stil < this.Grens
                continue
            ; De app hangt terwijl toetsenbord en muis geblokkeerd zijn
            Patnr := DllCall("GetProp", "Ptr", Hwnd, "Str", this.Pat, "Ptr")
            Log("WAAKHOND: de app reageert al " Round(Stil / 1000) " s niet terwijl toetsenbord en muis geblokkeerd zijn"
                . (Patnr ? " (bezig met Pat.nr " Patnr ")" : "") ". App afgesloten, blokkade weg.")
            ProcessClose Pid
            ProcessWaitClose Pid, 5
            Antw := MsgBox("Etiketten autoprinter reageerde " Round(Stil / 1000) " seconden niet meer tijdens het printen en is daarom afgesloten. Toetsenbord en muis zijn weer vrij."
                . (Patnr ? "`n`nDe app was bezig met Pat.nr " Patnr ". Kijk of die pati" Teken.EUml "nt al een etiket heeft; dat is mogelijk niet geregistreerd." : "")
                . "`n`nKijk in Pharmacom of er nog een dossier of afdrukmenu openstaat en sluit dat."
                . "`n`nDe app opnieuw starten?", AppTitel, "YesNo Icon! 0x40000")
            if Antw = "Yes"
                try Run(A_IsCompiled ? '"' A_ScriptFullPath '"' : '"' A_AhkPath '" "' A_ScriptFullPath '"', A_ScriptDir)
            return
        }
    }
}

WaakhondHartslag() => Waakhond.Hartslag()

; =====================================================================
; Meldingen bij de klok (TrayTip; in Windows 10/11 een melding rechtsonder)
; die je kunt aanklikken: de app opent dan de plek waar de melding over
; gaat (bijv. de planning). Windows meldt de klik met AHK_NOTIFYICON
; (0x404) en NIN_BALLOONUSERCLICK (0x405). Echte knoppen in een melding
; vragen een geregistreerde app-ID (winrt.ahk); dat is bewust niet gedaan.
; =====================================================================
class Melder {
    static Actie := "", Tot := 0

    ; Soort: 1 = info, 2 = waarschuwing, 3 = fout. Actie = functie bij een klik
    ; (standaard: het venster van de app tonen). Een klik telt tot 10 minuten.
    static Toon(Tekst, Titel := "", Soort := 1, Actie := "") {
        this.Actie := Actie, this.Tot := A_TickCount + 600000
        TrayTip Tekst, Titel != "" ? Titel : AppTitel, Soort
    }

    static Klik() {
        Fn := A_TickCount < this.Tot ? this.Actie : ""
        this.Actie := "", this.Tot := 0
        Venster.Toon(true)
        if Fn
            try Fn()
    }
}

MelderBericht(wParam, lParam, *) {
    if (lParam & 0xFFFF) = 0x405   ; NIN_BALLOONUSERCLICK
        SetTimer () => Melder.Klik(), -10
}

; Vervangt #SingleInstance Force (die zou ook de waakhond afsluiten): een
; eerder gestarte app vanuit dezelfde .exe wordt afgesloten.
EnkeleInstantie() {
    DetectHiddenWindows true
    ; Op bestandsnaam, niet op pad: via W:\ en via \\server\ (of een korte
    ; 8.3-naam) gestart is het pad anders, en dan draaiden er twee (die elkaar
    ; in de weg zitten). De titel van het verborgen venster is het volledige
    ; pad met de lange naam (ook bij een korte naam); het procespad niet
    ; (bij een netwerkmap \Device\Mup\...\ETIKET~1.EXE).
    Patroon := "i)(^|\\)\Q" A_ScriptName "\E( - AutoHotkey.*)?$"
    for h in WinGetList("ahk_class AutoHotkey") {
        if h = A_ScriptHwnd
            continue
        try {
            if !RegExMatch(WinGetTitle(h), Patroon)
                continue
            Pid := WinGetPID(h)
            PostMessage 0x0111, 65307, 0, , "ahk_id " h   ; WM_COMMAND: afsluiten
            if !WinWaitClose("ahk_id " h, , 3)
                ProcessClose Pid
        }
    }
    DetectHiddenWindows false
}

class Geheugen {
    ; Werkset en privégeheugen (MB) van een proces, of "" als het niet lukt
    static Van(Pid) {
        h := DllCall("OpenProcess", "UInt", 0x1000 | 0x0010, "Int", 0, "UInt", Pid, "Ptr")   ; QUERY_LIMITED_INFORMATION | VM_READ
        if !h
            return ""
        Grootte := 8 + 9 * A_PtrSize   ; PROCESS_MEMORY_COUNTERS_EX
        Buf := Buffer(Grootte, 0)
        NumPut "UInt", Grootte, Buf
        Ok := DllCall("psapi\GetProcessMemoryInfo", "Ptr", h, "Ptr", Buf, "UInt", Grootte)
        DllCall("CloseHandle", "Ptr", h)
        if !Ok
            return ""
        return {werkset: Round(NumGet(Buf, 8 + A_PtrSize, "UPtr") / 1048576), prive: Round(NumGet(Buf, 8 + 8 * A_PtrSize, "UPtr") / 1048576)}
    }

    static LogPharmacom() {
        if !Ph.Pid || !ProcessExist(Ph.Pid)
            return
        if g := this.Van(Ph.Pid)
            Log("Geheugen Pharmacom: " g.werkset " MB in gebruik, " g.prive " MB eigen geheugen")
    }
}
