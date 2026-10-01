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

    ; Korte "vingerafdruk" van de aanschrijfbuffer (Pat.nr's + ontslagdatums),
    ; of "" als die niet zichtbaar is.
    static Handtekening() {
        t := this.Buffer()
        if !t
            return ""
        s := t.rows ":"
        loop t.rows
            s .= t.Cel(A_Index - 1, "patnr") "/" t.Cel(A_Index - 1, "ontslag") ";"
        return s
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
        if !WinActive("ahk_pid " this.Pid)
            return Ronde.Fout("Pharmacom was niet meer het actieve venster", false)
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
        Item := Inst.PrintMenu
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
            MenuOpen := !!Jab.ZoekMenuItem(this.Pid, Inst.PrintMenu)
            Send "{Escape}"
            Log("  terugzetten: Escape" (MenuOpen ? " (afdrukmenu)" : ""))
            ; Een afdrukmenu sluiten laat het venster open; dan volgt de
            ; volgende Escape zodra het menu weg is.
            Eind := A_TickCount + 2000
            while WinExist("A") = a && A_TickCount < Eind && !(MenuOpen && !Jab.ZoekMenuItem(this.Pid, Inst.PrintMenu))
                Sleep 50
            Sleep 300
        }
        Log("  terugzetten mislukt")
        return false
    }
}
