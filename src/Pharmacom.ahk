; =====================================================================
; Pharmacom: verbinding, uitlezen en de afzonderlijke stappen
;
; Elke stap controleert zelf of hij gelukt is (via de Java Access Bridge)
; en stuurt alleen toetsen als Pharmacom het actieve venster is. Er wordt
; nergens gegokt.
; =====================================================================

class Ph {
    static Win := "Pharmacom ahk_exe javaw.exe"
    static Hwnd := 0, Pid := 0, JreBin := "", Verbonden := false

    ; Kolommen waaraan de tabellen herkend worden (reguliere expressies op de
    ; kolomkop). Sleutel = naam die de app intern gebruikt.
    static BufferKoppen := Map("naam", "i)^Pati", "patnr", "i)^Pat\.?\s*nr", "ontslag", "i)^Ontslag", "gebdatum", "i)^Geb")
    ; De medicatiehistorie bestaat uit twee tabellen naast elkaar (zelfde
    ; regels): links Laatste V/A + Etiketnaam, rechts Labeler, CF, Ap, ...
    ; (Labeler is nodig om hem niet te verwarren met de tabel in
    ; Receptverwerking, die ook Ap, Th. einddatum en Herhaal info heeft.)
    static HistorieKoppen := Map("labeler", "i)^Labeler", "ap", "i)^Ap\W*$", "einddatum", "i)^Th\.?\s*einddatum", "herhaal", "i)^Herhaal")
    static EtiketKoppen := Map("etiket", "i)^Etiket")
    ; Waarde in Herhaal info waarop gefilterd wordt (als die optie aan staat)
    static DeelbaarPatroon := "i)^ASB:\s*Deelbaar"
    ; Label rechtsonder, bijv. "AN - RS - 183": eerste deel = ingelogde apotheek
    static ApotheekPatroon := "^\s*([A-Za-z0-9]{1,4})\s*-\s*\S+\s*-\s*\S+\s*$"

    ; Zoekt Pharmacom en maakt verbinding. Geeft de status terug:
    ; "ok", "jab" (koppeling uit), "64bit" of "geen".
    static Verbind() {
        Hwnd := WinExist(this.Win)
        if !Hwnd {
            this.Verbonden := false
            return "geen"
        }
        this.Hwnd := Hwnd
        try {
            this.Pid := WinGetPID(Hwnd)
            SplitPath WinGetProcessPath(Hwnd), , &Dir
            this.JreBin := Dir
        } catch {
            this.Verbonden := false
            return "geen"
        }
        if A_PtrSize = 8 {
            ; Pharmacom draait op 32-bit Java; de koppeling werkt alleen vanuit 32-bit
            this.Verbonden := false
            return "64bit"
        }
        this.Verbonden := Jab.Koppel(Hwnd, this.JreBin)
        return this.Verbonden ? "ok" : "jab"
    }

    static JabPropsAan() {
        try Inhoud := FileRead(EnvGet("USERPROFILE") "\.accessibility.properties")
        catch
            return false
        return RegExMatch(Inhoud, "m)^\s*assistive_technologies\s*=.*AccessBridge") > 0
    }

    ; Zet de Java Access Bridge aan (jabswitch, of het instellingenbestand zelf)
    static KoppelingInschakelen() {
        if this.JreBin = ""
            this.Verbind()
        if this.JreBin != "" && FileExist(this.JreBin "\jabswitch.exe")
            try RunWait '"' this.JreBin '\jabswitch.exe" -enable', , "Hide"
        if !this.JabPropsAan()
            try FileAppend "`nassistive_technologies=com.sun.java.accessibility.AccessBridge`nscreen_magnifier_present=true`n", EnvGet("USERPROFILE") "\.accessibility.properties"
        return this.JabPropsAan()
    }

    static Buffer() => Jab.ZoekTabel(this.Pid, this.BufferKoppen)

    ; --- Bewaking (elke 3 s) -------------------------------------------------
    ; De gevonden aanschrijfbuffer wordt onthouden, zodat hij niet elke keer
    ; opnieuw gezocht hoeft te worden (± 130 ms). Is hij niet meer zichtbaar
    ; (ander scherm, Pharmacom opnieuw gestart), dan wordt opnieuw gezocht.
    static BufferCache := "", CacheHwnd := 0

    static BufferBewaakt() {
        t := this.BufferCache
        if t && this.CacheHwnd = this.Hwnd {
            Info := Jab.Info(t.vm, t.ac)
            if Info && Jab.Heeft(Info, "showing")
                return t
        }
        this.BufferCache := this.Buffer()
        this.CacheHwnd := this.Hwnd
        return this.BufferCache
    }

    static VergeetBuffer() => this.BufferCache := ""

    ; Staat Pharmacom op het scherm met de aanschrijfbuffer? Afgelezen aan de
    ; venstertitel ("Pharmacom - Aanschrijfbuffer"); heeft de titel geen
    ; schermnaam, dan wordt aangenomen van wel.
    static OpBufferScherm() {
        try return TitelIsBuffer(WinGetTitle(this.Hwnd))
        return false
    }

    ; Kan de app nu in Pharmacom aan de slag (voor een geplande ronde)? Geeft
    ; "" of de reden waarom niet. Een melding of inlogvenster in Pharmacom
    ; schakelt het hoofdvenster uit (WS_DISABLED); de titels van open vensters
    ; komen in de reden.
    static Gereed(BufferNodig := true) {
        try {
            if WinGetStyle(this.Hwnd) & 0x08000000 {
                Titels := ""
                for h in WinGetList("ahk_pid " this.Pid)
                    if h != this.Hwnd && (WinGetStyle(h) & 0x10000000) && (t := Trim(WinGetTitle(h))) != ""
                        Titels .= (Titels != "" ? ", " : "") "'" t "'"
                return "in Pharmacom staat een melding of venster open" (Titels != "" ? " (" Titels ")" : "")
            }
            if BufferNodig && !this.OpBufferScherm()
                return "Pharmacom staat niet op de aanschrijfbuffer"
            if this.LeesApotheek() = ""
                return "er is niemand ingelogd in Pharmacom (geen apotheek te zien)"
        } catch as e
            return "Pharmacom kon niet gecontroleerd worden (" e.Message ")"
        return ""
    }

    ; Korte "vingerafdruk" van de aanschrijfbuffer, of "" als die niet
    ; zichtbaar is. Snel: aantal regels + eerste en laatste Pat.nr.
    ; Volledig: Pat.nr en ontslagdatum van alle regels.
    static Handtekening(Volledig := false) {
        t := Volledig ? this.Buffer() : this.BufferBewaakt()
        if !t
            return ""
        n := t.Rijen()
        if !Volledig
            return n ":" (n ? t.Cel(0, "patnr") "/" t.Cel(n - 1, "patnr") : "")
        s := n ":"
        loop n
            s .= t.Cel(A_Index - 1, "patnr") "/" t.Cel(A_Index - 1, "ontslag") ";"
        return s
    }

    ; --- Groep (zoekcriteria van de aanschrijfbuffer) -----------------------
    ; De velden zijn een paneel met de naam van het label ("Instelling:",
    ; "Afdeling:") met daarin een bewerkbaar tekstvak (de code) en een tekstvak
    ; met de omschrijving.

    ; --- Alle groepen ophalen ----------------------------------------------
    ; Leest alle instellingen (venster "Kies een instelling", sluiten met
    ; Annuleren - Escape zou "Alle toegestane instellingen" kiezen) en per
    ; instelling de afdelingen (keuzelijst "Kies een code", sluiten met
    ; Escape). Zet daarna de oorspronkelijke instelling en afdeling terug.
    ; Geeft {instellingen: Map code->naam, afdelingen: Map inst->Map}, of
    ; een tekst met de reden waarom het niet lukte.
    static HaalGroepen(Voortgang := "") {
        if this.Verbind() != "ok"
            return "Pharmacom is niet bereikbaar"
        if WinGetMinMax(this.Hwnd) = -1
            WinRestore "ahk_id " this.Hwnd
        WinActivate "ahk_id " this.Hwnd
        if !WinWaitActive("ahk_id " this.Hwnd, , 3)
            return "Pharmacom kon niet naar voren gehaald worden (staat er een venster open?)"
        if !this.OpBufferScherm()
            return "Pharmacom staat niet op de aanschrijfbuffer"
        OrigI := this.Veld("Instelling:"), OrigA := this.Veld("Afdeling:")
        if !OrigI || !OrigA
            return "de velden Instelling en Afdeling zijn niet gevonden"
        Fout := ""
        Inst_ := this.LeesKeuzevenster("Instelling:", "Kies een instelling", Map("code", "i)^Memo$", "naam", "i)^Ziekenhuis"), "Annuleren")
        if !IsObject(Inst_)
            Fout := Inst_
        Afd := Map()
        if !Fout {
            for Code, Naam in Inst_ {
                if Voortgang
                    Voortgang("Afdelingen van " Code " ophalen (" A_Index " van " Inst_.Count ")" Teken.Ellips)
                if (R := this.ZetVeld("Instelling:", Code)) != "" {
                    Fout := R
                    break
                }
                v := this.Veld("Afdeling:")
                if !v || !v.aan {
                    Afd[Code] := Map()      ; deze instelling heeft geen afdelingen
                    continue
                }
                L := this.LeesKeuzevenster("Afdeling:", "Kies een code", Map("code", "i)^Code$", "naam", "i)^Omschrijving$"), "")
                if !IsObject(L) {
                    Fout := L
                    break
                }
                Afd[Code] := L
            }
        }
        ; Altijd terugzetten
        if OrigI.code != ""
            this.ZetVeld("Instelling:", OrigI.code)
        if OrigA.code != ""
            this.ZetVeld("Afdeling:", OrigA.code)
        I2 := this.Veld("Instelling:"), A2 := this.Veld("Afdeling:")
        if !I2 || I2.code != OrigI.code || !A2 || A2.code != OrigA.code
            Fout := (Fout ? Fout ". " : "") "Let op: Instelling/Afdeling konden niet teruggezet worden naar " OrigI.code " / " OrigA.code
        Log("Groepen opgehaald: " (IsObject(Inst_) ? Inst_.Count : 0) " instellingen" (Fout ? " - " Fout : ""))
        return Fout ? Fout : {instellingen: Inst_, afdelingen: Afd}
    }

    ; Opent het keuzevenster naast een veld (vergrootglas, of het pijltje
    ; rechts van het tekstvak), leest de tabel (Map code->naam) en sluit het
    ; weer met de knop Sluitknop, of Escape als Sluitknop leeg is.
    static LeesKeuzevenster(Label, Titel, Koppen, Sluitknop) {
        v := this.Veld(Label)
        if !v
            return "het veld " Label " is niet gevonden"
        Plek := v.HasProp("knop") ? v.knop : {x: v.x + v.w, y: v.y, w: 18, h: v.h}
        if !this.KlikOp(Plek)
            return "Pharmacom was niet het actieve venster"
        Venster_ := 0, Eind := A_TickCount + 4000
        while !Venster_ && A_TickCount < Eind {
            Sleep 100
            a := WinExist("A")
            try
                if a && WinGetPID(a) = this.Pid && InStr(WinGetTitle(a), Titel)
                    Venster_ := a
        }
        if !Venster_
            return "het venster '" Titel "' verscheen niet"
        Sleep 300
        Res := Map()
        t := Jab.ZoekTabel(this.Pid, Koppen)
        if t
            loop t.Rijen() {
                c := t.Cel(A_Index - 1, "code")
                if c != ""
                    Res[c] := t.Cel(A_Index - 1, "naam")
            }
        t := ""
        ; Sluiten (alleen als het keuzevenster nog vooraan staat)
        if WinActive("ahk_id " Venster_) {
            k := Sluitknop != "" ? this.Knop(Sluitknop) : ""
            if k {
                CoordMode "Mouse", "Screen"
                MouseGetPos &Mx, &My
                Click k.x + k.w // 2, k.y + k.h // 2
                MouseMove Mx, My, 0
            } else
                Send "{Escape}"
        }
        WinWaitClose "ahk_id " Venster_, , 3
        if WinExist("ahk_id " Venster_)
            return "het venster '" Titel "' ging niet dicht"
        Sleep 200
        return Res
    }

    ; {code, omschrijving, x, y, w, h} van een zoekveld, of ""
    static Veld(Label) {
        Bezoek(Vm, Ac, Info, Diepte) {
            if Info.role = "panel" && Trim(Info.name) = Label {
                Res := {code: "", omschrijving: "", x: 0, y: 0, w: 0, h: 0}, Gevonden := 0
                Verzamel(Vm, Ac, 0)
                return Gevonden ? Res : "stop"
            }
            if RegExMatch(Info.role, "^(table|menu bar|menu|popup menu|list|tree)$")
                return "stop"
            return ""
        }
        ; Tekstvakken binnen het paneel (een paar niveaus diep): het eerste
        ; bewerkbare is de code, een niet-bewerkbaar is de omschrijving.
        Verzamel(Vm, Ac, Diepte) {
            loop Min(Jab.Info(Vm, Ac).children, 20) {
                Kind := Jab.Kind(Vm, Ac, A_Index - 1)
                if !Kind
                    continue
                Ki := Jab.Info(Vm, Kind)
                if Ki && Ki.role = "text" {
                    if Jab.Heeft(Ki, "editable") && !Gevonden {
                        Res.code := Trim(Jab.Naam(Vm, Kind)), Res.x := Ki.x, Res.y := Ki.y, Res.w := Ki.w, Res.h := Ki.h
                        Res.aan := Jab.Heeft(Ki, "enabled")
                        Gevonden := 1
                    } else if !Jab.Heeft(Ki, "editable")
                        Res.omschrijving := Trim(Jab.Naam(Vm, Kind))
                } else if Ki && Ki.role = "push button" && Ki.w > 0 && !Res.HasProp("knop") {
                    ; Zoekknop (vergrootglas) naast het veld
                    Res.knop := {x: Ki.x, y: Ki.y, w: Ki.w, h: Ki.h}
                } else if Ki && Diepte < 3
                    Verzamel(Vm, Kind, Diepte + 1)
                Jab.Release(Vm, Kind)
            }
        }
        Res := "", Gevonden := 0
        return Jab.Doorzoek(this.Pid, Bezoek)
    }

    ; {x, y, w, h, aan} van een knop met deze naam, of ""
    static Knop(Naam) {
        Bezoek(Vm, Ac, Info, Diepte) {
            if Info.role = "push button" && Trim(Info.name) = Naam
                return {x: Info.x, y: Info.y, w: Info.w, h: Info.h, aan: Jab.Heeft(Info, "enabled")}
            if RegExMatch(Info.role, "^(table|menu bar|menu|popup menu|list|tree)$")
                return "stop"
            return ""
        }
        return Jab.Doorzoek(this.Pid, Bezoek)
    }

    ; Klikt in het midden van een element (schermcoördinaten), alleen als
    ; Pharmacom het actieve venster is.
    static KlikOp(e) {
        if !WinActive("ahk_id " this.Hwnd)
            return false
        CoordMode "Mouse", "Screen"
        MouseGetPos &Mx, &My
        Click e.x + e.w // 2, e.y + e.h // 2
        MouseMove Mx, My, 0
        return true
    }

    ; Typt een code in een zoekveld en controleert dat Pharmacom hem
    ; accepteert (de code staat erin en er is een omschrijving). "" = gelukt.
    static ZetVeld(Label, Waarde) {
        v := this.Veld(Label)
        if !v
            return "het veld " Label " is niet gevonden"
        if v.code = Waarde && v.omschrijving != ""
            return ""
        if !this.KlikOp(v)
            return "Pharmacom was niet het actieve venster"
        Sleep 150
        Send "^a"
        SendText Waarde
        Send "{Tab}"
        Log("  " Label " " Waarde " ingevuld")
        Eind := A_TickCount + 4000
        loop {
            Sleep 150
            ; Een (zoek)venster van Pharmacom = de code werd niet herkend
            a := WinExist("A")
            if a && a != this.Hwnd {
                try Pid := WinGetPID(a)
                catch
                    Pid := 0
                if Pid = this.Pid {
                    Send "{Escape}"
                    return "Pharmacom kent " Label " " Waarde " niet"
                }
            }
            v := this.Veld(Label)
            if v && v.code = Waarde && v.omschrijving != ""
                return ""
            if A_TickCount > Eind
                return "Pharmacom accepteerde " Label " " Waarde " niet"
        }
    }

    ; Vult Instelling en Afdeling in, klikt op Zoeken en wacht tot de lijst
    ; geladen is. Geeft "" als het gelukt is, anders de reden.
    ; Opent de aanschrijfbuffer met Ctrl+F11 (knop "Aanschrijfbuffer" in de
    ; werkbalk van Pharmacom) en wacht tot het scherm met de zoekvelden en de
    ; lijst er is. Geeft "" of de reden waarom het niet lukte.
    static OpenBuffer() {
        if !WinActive("ahk_id " this.Hwnd)
            return "Pharmacom was niet het actieve venster"
        Log("  aanschrijfbuffer openen (Ctrl+F11)")
        this.VergeetBuffer()
        Send "^{F11}"
        Eind := A_TickCount + Inst.Wt["MaxWachtScherm"]
        loop {
            Sleep 250
            if this.OpBufferScherm() && this.Buffer() && this.Veld("Afdeling:") {
                Log("  aanschrijfbuffer geopend")
                Sleep 300
                return ""
            }
            if A_TickCount > Eind
                return "de aanschrijfbuffer ging niet open (Ctrl+F11)"
            if !WinActive("ahk_pid " this.Pid)
                return "Pharmacom was niet meer het actieve venster"
        }
    }

    static ZetGroep(Instelling, Afdeling) {
        if this.Verbind() != "ok"
            return "Pharmacom is niet bereikbaar"
        if WinGetMinMax(this.Hwnd) = -1
            WinRestore "ahk_id " this.Hwnd
        WinActivate "ahk_id " this.Hwnd
        if !WinWaitActive("ahk_id " this.Hwnd, , 3)
            return "Pharmacom kon niet naar voren gehaald worden (staat er een venster open?)"
        if !this.OpBufferScherm() && (R := this.OpenBuffer()) != ""
            return R
        Sleep 200
        if Instelling != "" && (R := this.ZetVeld("Instelling:", Instelling)) != ""
            return R
        if (R := this.ZetVeld("Afdeling:", Afdeling)) != ""
            return R
        Zoek := this.Knop("Zoeken")
        if !Zoek || !Zoek.aan
            return "de knop Zoeken is niet gevonden"
        if !this.KlikOp(Zoek)
            return "Pharmacom was niet het actieve venster"
        Log("  Zoeken geklikt")
        ; Wachten: eerst wordt "Stoppen met zoeken" actief, daarna weer niet,
        ; en de lijst moet stabiel zijn.
        Eind := A_TickCount + 60000
        Sleep 500
        Vorige := "", Gelijk := 0
        loop {
            Stop := this.Knop("Stoppen met zoeken")
            if !(Stop && Stop.aan) {
                H := this.Handtekening(true)
                Gelijk := H != "" && H = Vorige ? Gelijk + 1 : 0
                Vorige := H
                if Gelijk >= 2
                    break
            }
            if A_TickCount > Eind
                return "het zoeken in Pharmacom duurde te lang"
            Sleep 400
        }
        ; Controle: staat de gekozen afdeling in de lijst?
        t := Jab.ZoekTabel(this.Pid, Map("afd", "i)^Afd$"))
        if t && t.Rijen() > 0 {
            Andere := 0
            loop t.Rijen()
                if t.Cel(A_Index - 1, "afd") != Afdeling
                    Andere++
            if Andere
                return "de lijst bevat ook " Andere " pati" Teken.EUml "nt(en) van een andere afdeling"
        }
        i := this.Veld("Instelling:"), a := this.Veld("Afdeling:")
        if i && a
            Groepen.Leer(i.code, i.omschrijving, a.code, a.omschrijving)
        Log("  groep " Instelling " / " Afdeling " geladen (" StrSplit(Vorige, ":")[1] " regels)")
        return ""
    }

    ; Ingelogde apotheek (bijv. "AN"), of ""
    static LeesApotheek() {
        Tekst := Jab.ZoekLabel(this.Pid, this.ApotheekPatroon)
        return Tekst != "" && RegExMatch(Tekst, this.ApotheekPatroon, &M) ? M[1] : ""
    }

    ; --- Wachten en toetsen ----------------------------------------------
    ; Wacht in kleine stukjes, zodat Stop direct reageert.
    static Wacht(Ms) {
        Eind := A_TickCount + (IsInteger(Ms) ? Ms : 1000)
        while A_TickCount < Eind && !Ronde.Stoppen
            Sleep 20
    }

    ; Verstuurt een toets, maar alleen als er niet gestopt is en Pharmacom
    ; (of een venster van Pharmacom zelf) actief is.
    static Stap(Toets, Ms, Label) {
        if Ronde.Stoppen
            return Ronde.Fout("gestopt door gebruiker", false)
        if !WinActive("ahk_pid " this.Pid) {
            ; Op het venster van de app geklikt (bijv. Stop) = stoppen
            if Venster.Hwnd && WinActive("ahk_id " Venster.Hwnd)
                return Ronde.Fout("gestopt door gebruiker", false)
            return Ronde.Fout("Pharmacom was niet meer het actieve venster", false)
        }
        Send Toets
        Log("  " Label)
        this.Wacht(Ms)
        return true
    }

    static WachtOpTabel(Koppen, Timeout) {
        Eind := A_TickCount + Timeout
        loop {
            if Ronde.Stoppen
                return Ronde.Fout("gestopt door gebruiker", 0)
            if t := Jab.ZoekTabel(this.Pid, Koppen)
                return t
            if A_TickCount > Eind
                return ""
            this.Wacht(60)
        }
    }

    ; Wacht tot een ander venster van Pharmacom actief is dan Voor.
    static WachtOpNieuwVenster(Voor, Timeout) {
        Eind := A_TickCount + Timeout
        loop {
            if Ronde.Stoppen
                return Ronde.Fout("gestopt door gebruiker", 0)
            a := WinExist("A")
            try
                if a && a != Voor && WinGetPID(a) = this.Pid
                    return a
            if A_TickCount > Eind
                return 0
            Sleep 20
        }
    }

    ; --- Selecteren ----------------------------------------------------------
    ; Zet de selectie in tabel t op regel Doel: direct via de koppeling (zoals
    ; een klik) en anders met pijltjestoetsen. t2 = optionele tweede tabel met
    ; dezelfde regels (linkerdeel van de medicatiehistorie). Controleert
    ; daarna of de selectie echt op Doel staat.
    static Selecteer(t, Doel, t2 := "") {
        if t.Selecteer(Doel) {
            this.Wacht(Inst.Wt["SleepNavigatie"])
            if t.Geselecteerd() = Doel && (!t2 || t2.Geselecteerd() = Doel)
                return true
            Log("  selectie via de koppeling klopte niet, verder met pijltjestoetsen")
        } else
            Log("  selecteren via de koppeling lukte niet, verder met pijltjestoetsen")
        return this.Navigeer(t, Doel, t2)
    }

    ; Pijltjestoetsen; controleert na elke toets of de selectie verschoof.
    static Navigeer(t, Doel, t2 := "") {
        Act := t, Ander := t2
        Sel := t.Geselecteerd()
        if t2 && Sel < 0 {
            s2 := t2.Geselecteerd()
            if s2 >= 0
                Act := t2, Ander := t, Sel := s2
        }
        loop Abs(Doel - Sel) + 5 {
            if Sel = Doel
                return true
            SelAnder := Ander ? Ander.Geselecteerd() : ""
            if !this.Stap(Sel < Doel ? "{Down}" : "{Up}", 0, "Pijltjestoets (regel " (Sel + 1) " -> " (Doel + 1) ")")
                return false
            Nieuw := Sel
            Eind := A_TickCount + 1500
            while Nieuw = Sel && A_TickCount < Eind && !Ronde.Stoppen {
                Sleep 20
                Nieuw := Act.Geselecteerd()
                if Nieuw = Sel && Ander {
                    ; Misschien heeft de andere tabel de focus
                    s2 := Ander.Geselecteerd()
                    if s2 != SelAnder
                        Tmp := Act, Act := Ander, Ander := Tmp, Nieuw := s2
                }
            }
            if Nieuw = Sel {
                Log("  selectie veranderde niet na pijltjestoets")
                return false
            }
            Sel := Nieuw
            this.Wacht(Inst.Wt["SleepNavigatie"])
        }
        return Sel = Doel
    }

    static ZoekRij(t, Sleutel, Waarde, Hint) {
        Rijen := t.Rijen()
        if Hint >= 0 && Hint < Rijen && t.Cel(Hint, Sleutel) = Waarde
            return Hint
        loop Rijen
            if t.Cel(A_Index - 1, Sleutel) = Waarde
                return A_Index - 1
        return -1
    }

    ; --- Controles -------------------------------------------------------------
    ; Zoekt in het dossiervenster naar het Pat.nr, of (als de optie "alleen
    ; Pat.nr" uit staat) naar achternaam + geboortedatum. Probeert het een
    ; paar seconden (het dossier kan nog laden).
    static BevestigDossier(p, Hwnd) {
        Achternaam := Trim(StrSplit(p.naam, ",")[1])
        GebPatroon := ""
        if RegExMatch(p.gebdatum, "^(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})$", &G)
            GebPatroon := "(?<!\d)0?" Integer(G[1]) "[-/.]0?" Integer(G[2]) "[-/.](" G[3] "|" SubStr(G[3], -2) ")(?!\d)"
        Eind := A_TickCount + 3000
        loop {
            Tekst := Jab.VensterTekst(Hwnd)
            HeeftPatnr := p.patnr != "" && RegExMatch(Tekst, "(?<!\d)\Q" p.patnr "\E(?!\d)")
            HeeftNaam := Achternaam != "" && InStr(Tekst, Achternaam)
            HeeftGeb := GebPatroon != "" && RegExMatch(Tekst, GebPatroon)
            if HeeftPatnr || (!Inst.Optie("patnr") && HeeftNaam && HeeftGeb) {
                Log("  dossier bevestigd (" (HeeftPatnr ? "Pat.nr" : "naam + geboortedatum") ")")
                return true
            }
            if A_TickCount > Eind || Ronde.Stoppen
                break
            this.Wacht(200)
        }
        Log("  dossier NIET bevestigd: Pat.nr " (HeeftPatnr ? "ja" : "nee") ", naam " (HeeftNaam ? "ja" : "nee") ", geboortedatum " (HeeftGeb ? "ja" : "nee") " (" StrLen(Tekst) " tekens tekst in dossier)")
        return false
    }

    ; Kolomkoppen van alle zichtbare tabellen naar het log (geen pati"entgegevens)
    static LogZichtbareTabellen() {
        Alle := []
        Jab.ZoekTabel(this.Pid, Map(), Alle)
        Log("  Zichtbare tabellen: " Alle.Length)
        for i, t in Alle {
            Kolommen := ""
            for c, k in t.koppen
                Kolommen .= (c > 1 ? " | " : "") (k = "" ? "(leeg)" : k)
            Log("    tabel " i ": " t.rows " regels, kolommen: " Kolommen)
        }
    }

    ; --- Printen -------------------------------------------------------------
    ; Ctrl+P opent in het dossier een afdrukmenu (geen apart venster). Wacht
    ; tot het menu met het juiste item zichtbaar is, kiest het met de
    ; sneltoets die Pharmacom opgeeft, wacht tot het menu dicht is, Escape.
    ; Zet Ronde.Gekozen zodra het item gekozen is (vanaf dan telt het etiket
    ; als geprint).
    static PrintEtiket() {
        Item := Inst.PrintItem
        Voor := WinExist("A")
        if !this.Stap("^p", Inst.Wt["SleepNaCtrlP"], "Ctrl+P")
            return false
        Gevonden := ""
        Eind := A_TickCount + Inst.Wt["MaxWachtPrint"]
        loop {
            if Ronde.Stoppen
                return Ronde.Fout("gestopt door gebruiker", false)
            Gevonden := Jab.ZoekMenuItem(this.Pid, Item)
            if Gevonden || A_TickCount > Eind
                break
            this.Wacht(30)
        }
        ; Geen menu = niet gokken: de sneltoets zou ergens anders terechtkomen
        ; en de Escape hierna zou een te laat geopend menu weer sluiten.
        if !Gevonden {
            Log("  afdrukmenu met '" Item "' verscheen niet binnen " Inst.Wt["MaxWachtPrint"] " ms")
            return Ronde.Fout("het afdrukmenu met '" Item "' verscheen niet (er is niets geprint)", false)
        }
        if !Gevonden.aan || Gevonden.toets = "" {
            Log("  '" Item "' staat uit of heeft geen sneltoets")
            return Ronde.Fout("'" Item "' kon niet gekozen worden in het afdrukmenu (er is niets geprint)", false)
        }
        Log("  afdrukmenu verschenen")
        if !WinActive("ahk_id " Voor)
            return Ronde.Fout("het dossier was niet meer het actieve venster", false)
        Toets := StrLower(Gevonden.toets)
        if !this.Stap("!" Toets, 0, "Alt+" StrUpper(Toets) " - " Item)
            return false
        Ronde.Gekozen := true
        ; Wachten tot het menu dicht is (anders zou Escape het printen annuleren)
        Eind := A_TickCount + 10000
        while Jab.ZoekMenuItem(this.Pid, Item) {
            if Ronde.Stoppen
                return Ronde.Fout("gestopt door gebruiker", false)
            if A_TickCount > Eind
                return Ronde.Fout("het afdrukmenu sloot niet", false)
            this.Wacht(50)
        }
        this.Wacht(Inst.Wt["SleepNaAltB"])
        return this.Stap("{Escape}", Inst.Wt["SleepNaEscape"], "Escape")
    }

    ; Wacht tot de medicatiehistorie weg is en de aanschrijfbuffer weer
    ; zichtbaar. Staat het dossier na 3 s nog open (Escape kwam niet aan),
    ; dan nog een Escape - alleen als het dossier het actieve venster is.
    static WachtTerug(Dossier := 0) {
        Eind := A_TickCount + Inst.Wt["MaxWachtScherm"]
        Opnieuw := A_TickCount + 3000
        loop {
            if Ronde.Stoppen
                return Ronde.Fout("gestopt door gebruiker", false)
            if Jab.ZoekTabel(this.Pid, this.HistorieKoppen) {
                if Dossier && Opnieuw && A_TickCount > Opnieuw && WinActive("ahk_id " Dossier) {
                    Opnieuw := 0
                    Log("  dossier nog open na 3 s")
                    if !this.Stap("{Escape}", Inst.Wt["SleepNaEscape"], "Escape opnieuw")
                        return false
                }
            } else if this.Buffer() {
                this.Wacht(Inst.Wt["SleepNaScherm"])
                return true
            }
            if A_TickCount > Eind
                return false
            this.Wacht(60)
        }
    }

    ; Na een fout: met Escape (afdrukmenu, dossier) terug naar het hoofdvenster
    ; met de aanschrijfbuffer. Stuurt alleen toetsen als een venster van
    ; Pharmacom actief is; true als de aanschrijfbuffer weer zichtbaar is.
    static TerugNaarBuffer() {
        loop 5 {
            a := WinExist("A")
            try Apid := WinGetPID(a)
            catch
                Apid := 0
            if Apid != this.Pid {
                Log("  terugzetten: Pharmacom is niet het actieve venster, niets gedaan")
                return false
            }
            if a = this.Hwnd {
                ok := !Jab.ZoekTabel(this.Pid, this.HistorieKoppen) && this.Buffer()
                Log(ok ? "  terugzetten: aanschrijfbuffer zichtbaar" : "  terugzetten: aanschrijfbuffer niet herkend")
                return !!ok
            }
            if A_Index = 5
                break
            MenuOpen := !!Jab.ZoekMenuItem(this.Pid, Inst.PrintItem)
            Send "{Escape}"
            Log("  terugzetten: Escape" (MenuOpen ? " (afdrukmenu)" : ""))
            ; Een afdrukmenu sluiten laat het venster open; dan volgt de
            ; volgende Escape zodra het menu weg is.
            Eind := A_TickCount + 2000
            while WinExist("A") = a && A_TickCount < Eind && !(MenuOpen && !Jab.ZoekMenuItem(this.Pid, Inst.PrintItem))
                Sleep 50
            Sleep 300
        }
        Log("  terugzetten mislukt")
        return false
    }
}
