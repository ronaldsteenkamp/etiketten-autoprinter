; =====================================================================
; Het venster: ui\venster.html in WebView2 (Edge), rechtsonder op het
; scherm zonder Pharmacom de focus af te pakken.
;
; De pagina stuurt klikken met window.chrome.webview.postMessage("...");
; de app werkt de pagina bij met api(opdracht, json).
; =====================================================================

class Venster {
    static Gui := "", Hwnd := 0, Wvc := "", Wv := "", Klaar := false
    static Registraties := []
    static Knoppen := Map()
    static VerbStatus := ""
    static Wachtrij := []
    static DialoogAntwoord := Map(), DialoogTeller := 0
    static Breedte := 540, Hoogte := 702

    static Maak() {
        Map_ := EnvGet("LOCALAPPDATA") "\Etiketten autoprinter"
        UiMap := Map_ "\ui"
        try DirCreate UiMap
        FileInstall "ui\venster.html", UiMap "\venster.html", 1
        FileInstall "ui\icoon.png", UiMap "\icoon.png", 1
        FileInstall "src\lib\WebView2\32bit\WebView2Loader.dll", Map_ "\WebView2Loader.dll", 1

        g := Gui("-Caption", AppTitel)
        g.BackColor := "EEF2F7"
        g.MarginX := g.MarginY := 0
        g.OnEvent("Close", (*) => Venster.Sluit())
        g.OnEvent("Size", VensterGrootte)
        this.Gui := g, this.Hwnd := g.Hwnd
        g.Show("Hide w" this.Breedte " h" this.Hoogte)

        ; Afgeronde hoeken en schaduw (Windows 11)
        try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", g.Hwnd, "UInt", 33, "Int*", 2, "UInt", 4)
        Marge := Buffer(16, 0), NumPut("Int", 1, Marge)
        try DllCall("dwmapi\DwmExtendFrameIntoClientArea", "Ptr", g.Hwnd, "Ptr", Marge)

        this.Wvc := WebView2.CreateControllerAsync(g.Hwnd, 0, Map_ "\WebView2", "", Map_ "\WebView2Loader.dll").await2()
        this.Wv := this.Wvc.CoreWebView2
        s := this.Wv.Settings
        s.AreDefaultContextMenusEnabled := false
        s.AreDevToolsEnabled := false
        s.IsZoomControlEnabled := false
        s.IsStatusBarEnabled := false
        try s.AreBrowserAcceleratorKeysEnabled := false
        this.Registraties.Push(this.Wv.WebMessageReceived(VensterBericht))
        this.Registraties.Push(this.Wv.NavigationCompleted((*) => Venster.Klaar := true))
        ; De pagina rechtstreeks uit het geheugen laden, met het icoon erin
        ; (geen bestandstoegang door WebView2: die werd op sommige mappen
        ; geweigerd, en een file:///-adres werkt niet met spaties in het pad)
        Html := FileRead(UiMap "\venster.html", "UTF-8")
        Png := FileRead(UiMap "\icoon.png", "RAW")
        Html := StrReplace(Html, 'src="icoon.png"', 'src="data:image/png;base64,' Base64(Png) '"')
        this.Wv.NavigateToString(Html)
        Eind := A_TickCount + 15000
        while !this.Klaar && A_TickCount < Eind
            Sleep 20
        if !this.Klaar
            Log("Venster: pagina niet binnen 15 s geladen")

        ; Rechtsonder op het scherm, zonder Pharmacom de focus af te pakken
        WinGetPos , , &VW, &VH, g.Hwnd
        MonitorGetWorkArea(, &L, &T, &R, &B)
        g.Show("x" (R - VW - 12) " y" Max(T, B - VH - 12) " NoActivate")
        this.Wvc.IsVisible := true
        this.Wvc.Fill()
        this.ZetBovenop()

        for Naam, k in Map("start", {aan: 1, zichtbaar: 1}, "proef", {aan: 1, zichtbaar: 1}, "stop", {aan: 0, zichtbaar: 1}, "vernieuwen", {aan: 0, zichtbaar: 1}, "koppel", {aan: 1, zichtbaar: 0})
            this.Knoppen[Naam] := k
        this.Ui("versie", AppVersie)
        for Naam in this.Knoppen
            this.UiKnop(Naam)
        this.UiOpties()
        this.Hint()
        this.Status("idle")
        this.Tellers()
    }

    static Geminimaliseerd() {
        try return WinGetMinMax(this.Hwnd) = -1 || !DllCall("IsWindowVisible", "Ptr", this.Hwnd)
        return false
    }

    ; Tijdens een ronde: klikken op het venster (bijv. Stop) maken het niet
    ; actief, zodat Pharmacom op de voorgrond blijft (WS_EX_NOACTIVATE).
    static GeenActivatie(Aan) {
        try this.Gui.Opt(Aan ? "+E0x08000000" : "-E0x08000000")
    }

    ; Bovenop: altijd (optie "altijdbovenop", standaard uit), of alleen zolang
    ; er geprint wordt of een geplande ronde bezig is (optie "bovenop"), zodat
    ; het venster niet voor Pharmacom blijft hangen als de app niets doet
    static ZetBovenop() {
        Aan := Inst.Optie("altijdbovenop") || (Inst.Optie("bovenop") && (Ronde.Bezig || Planning.Bezig))
        try this.Gui.Opt(Aan ? "+AlwaysOnTop" : "-AlwaysOnTop")
    }

    static Toon(Activeren := false) {
        if this.Gui
            this.Gui.Show(Activeren ? "" : "NoActivate")
    }

    ; --- Van de app naar de pagina ---------------------------------------
    static Ui(Opdracht, Data := "") {
        if !this.Wv
            return
        try this.Wv.ExecuteScriptAsync("api(" Json(Opdracht) "," Json(Json(IsObject(Data) ? Data : String(Data))) ")")
    }

    static UiKnop(Naam) {
        k := this.Knoppen[Naam]
        this.Ui("knop", {naam: Naam, aan: k.aan ? 1 : 0, zichtbaar: k.zichtbaar ? 1 : 0, tekst: k.HasProp("tekst") ? k.tekst : ""})
    }
    static ZetKnop(Naam, Aan) => (this.Knoppen[Naam].aan := Aan, this.UiKnop(Naam))
    static ToonKnop(Naam, Zichtbaar) => (this.Knoppen[Naam].zichtbaar := Zichtbaar, this.UiKnop(Naam))
    static KnopTekst(Naam, Tekst) => (this.Knoppen[Naam].tekst := Tekst, this.UiKnop(Naam))

    static UiOpties() {
        o := {}
        for Naam in Inst.OptieSleutels
            o.%Naam% := Inst.Optie(Naam)
        o.autostart := Opstart.Aan() ? 1 : 0
        this.Ui("opties", o)
    }

    static Hint() => this.Ui("hint", (Inst.Optie("blokkeer") ? "Toetsenbord en muis zijn geblokkeerd tijdens het printen" : "Klik tijdens het printen niet in Pharmacom") " &middot; <kbd>Esc</kbd> of <b>Stop</b> stopt")

    static Status(Fase, Sub := "") {
        Koppen := Map("idle", "Klaar voor start", "bezig", "Bezig met printen" Teken.Ellips, "gestopt", "Gestopt", "klaar", "Klaar!", "fout", "Let op")
        if Sub = "" && Fase = "idle"
            Sub := "Klik op Start printen."
        this.Ui("status", {fase: Fase, titel: Koppen[Fase], sub: Sub})
        A_IconTip := AppTitel " - " Koppen[Fase]
    }

    static Sub(Tekst) => this.Ui("sub", Tekst)
    static Verbinding(Soort, Tekst) => this.Ui("verbinding", {soort: Soort, tekst: Tekst})

    ; Kleur: blauw / groen / oranje
    static Voortgang(Kleur) => this.Ui("voortgang", {klaar: Ronde.Verwerkt, totaal: Ronde.Aantal, kleur: Kleur = "blauw" ? "" : Kleur, links: Ronde.Verwerkt " van " Ronde.Aantal " verwerkt"})

    static Tellers() {
        ; Geprint = vandaag al geprint ("Al geprint") + net in deze ronde geprint
        this.Ui("tellers", {totaal: Ronde.Patienten.Length, print: Ronde.TelAan(), ontslag: Ronde.TelSoort("ontslag"), geprint: Ronde.TelSoort("al") + Ronde.TelSoort("ok")})
    }

    static Lijst() {
        L := []
        for p in Ronde.Patienten
            L.Push({naam: p.naam, patnr: p.patnr, ontslag: p.ontslag, soort: p.soort, detail: p.status, aan: p.aan ? 1 : 0})
        this.Ui("lijst", L)
    }

    ; i = 1-based
    static Rij(i, Soort, Tekst) {
        p := Ronde.Patienten[i]
        p.status := Tekst
        this.Ui("rij", {i: i - 1, soort: Soort, detail: Tekst, aan: p.aan ? 1 : 0, focus: Soort = "bezig" ? 1 : 0})
    }

    ; --- Verbinding ----------------------------------------------------------
    ; Zoekt Pharmacom, maakt verbinding en toont de status. Geeft de status.
    static Verbind() {
        St := Ph.Verbind()
        if St = this.VerbStatus
            return St
        this.VerbStatus := St
        Tx := Map("ok", "Verbonden met Pharmacom", "jab", "Koppeling staat uit", "64bit", "Verkeerde versie (64-bit)", "geen", "Pharmacom niet gevonden")[St]
        this.Verbinding(Map("ok", "ok", "jab", "warn", "64bit", "err", "geen", "off")[St], Tx)
        this.ToonKnop("start", St != "jab")
        this.ToonKnop("proef", St != "jab")
        this.ToonKnop("koppel", St = "jab")
        this.ZetKnop("vernieuwen", St = "ok" && !Ronde.Bezig)
        if St = "ok"
            this.Status("idle", "Verbonden. De aanschrijfbuffer wordt uitgelezen" Teken.Ellips)
        else if St = "jab"
            this.Status("fout", Ph.JabPropsAan()
                ? "De koppeling is ingeschakeld, maar Pharmacom moet nog opnieuw gestart worden. Sluit Pharmacom helemaal af en open het opnieuw."
                : "De koppeling met Pharmacom (Java Access Bridge) staat nog uit. Klik op 'Koppeling inschakelen' en start Pharmacom daarna opnieuw.")
        else if St = "64bit"
            this.Status("fout", "Deze app moet als 32-bit programma gecompileerd worden (Ahk2Exe: base AutoHotkey32.exe).")
        else
            this.Status("fout", "Pharmacom is niet geopend. Open Pharmacom met het scherm Aanschrijfbuffer.")
        Log("Verbinding: " Tx)
        return St
    }

    static KoppelingInschakelen() {
        if Ph.KoppelingInschakelen() {
            Log("Java Access Bridge ingeschakeld")
            this.VerbStatus := ""
            this.Verbind()
            this.Melding("Koppeling ingeschakeld", "Sluit Pharmacom helemaal af en start het opnieuw. Deze app maakt daarna vanzelf verbinding.")
        } else
            this.Melding("Koppeling mislukt", "De koppeling kon niet ingeschakeld worden.`n`nVoer eventueel handmatig uit:`n" Ph.JreBin "\jabswitch.exe -enable", "fout")
    }

    ; --- Dialoogvensters in de stijl van de app ------------------------------
    ; Soort: vraag / info / waarschuwing / fout / code. Vraag() wacht op het
    ; antwoord en geeft true (Ja) of false (Nee).
    static Vraag(Titel, Tekst, Ja := "Ja", Nee := "Nee", Soort := "vraag") => this.Dialoog({soort: Soort, titel: Titel, tekst: Tekst, ja: Ja, nee: Nee}) = "1"

    static Melding(Titel, Tekst, Soort := "info") => this.Vraag(Titel, Tekst, "OK", "", Soort)

    ; Dialoog met eigen knoppen: Knoppen = [{t: tekst, v: antwoord, i: icoon,
    ; hoofd: 1}, ...]. Geeft het antwoord (v) van de gekozen knop.
    static Keuze(Titel, Tekst, Knoppen, Soort := "vraag") => this.Dialoog({soort: Soort, titel: Titel, tekst: Tekst, knoppen: Knoppen})

    ; Timeout (ms) > 0: na die tijd geldt Standaard als antwoord.
    static Dialoog(Gegevens, Timeout := 0, Standaard := "1") {
        Id := ++this.DialoogTeller
        Sleutel := "d" Id
        this.DialoogAntwoord[Sleutel] := ""
        Gegevens.id := Id
        this.Ui("dialoog", Gegevens)
        this.Toon(true)
        Eind := A_TickCount + Timeout
        while this.DialoogAntwoord[Sleutel] = "" {
            if Timeout && A_TickCount > Eind {
                this.DialoogAntwoord[Sleutel] := Standaard
                break
            }
            Sleep 30
        }
        Antwoord := this.DialoogAntwoord[Sleutel]
        this.DialoogAntwoord.Delete(Sleutel)
        this.Ui("dialoogdicht")
        return Antwoord
    }

    ; --- Feedback en credits -------------------------------------------------
    static FeedbackKnoppen(Annuleer := "Annuleren") => [{t: Annuleer, v: "0"}, {t: "Teams", v: "teams", i: "message-circle"}, {t: "Outlook", v: "mail", i: "mail", hoofd: 1}]

    static Feedback() {
        Keuze := this.Keuze("Vraag of idee?", "Heb je een vraag, loop je ergens tegenaan of heb je een idee om de app beter te maken? Stuur " AppMaker " een bericht via Outlook of Teams.`n`nDe app vult alleen de versie, de computernaam en de apotheek in, geen pati" Teken.EUml "ntgegevens.", this.FeedbackKnoppen(), "feedback")
        this.StuurFeedback(Keuze)
    }

    ; Verborgen: drie keer snel op het logo klikken
    static Over() {
        Tekst := AppTitel " " AppVersie "`n`n"
            . "Bedacht en gebouwd door " AppMaker ".`n`n"
            . "Met dank aan:`n"
            . Teken.Punt " AutoHotkey`n"
            . Teken.Punt " Lucide (iconen, ISC-licentie)`n"
            . Teken.Punt " thqby, WebView2 voor AutoHotkey (MIT-licentie)`n`n"
            . "Vragen of idee" Teken.EUml "n? Stuur gerust een bericht."
        Log("Over-venster geopend")
        Knoppen := this.FeedbackKnoppen("Sluiten")
        Knoppen.InsertAt(2, {t: "Wat is er nieuw", v: "nieuw", i: "party-popper"})
        Keuze := this.Keuze("Over deze app", Tekst, Knoppen, "over")
        if Keuze = "nieuw"
            return Wijzigingen.Toon()
        this.StuurFeedback(Keuze)
    }

    static Sneltoetsen() {
        this.Melding("Sneltoetsen"
            , "F5`tOpnieuw uitlezen en vinkjes terugzetten`n"
            . "Ctrl+Enter`tStart printen`n"
            . "Ctrl+Shift+Enter`tProefronde (niets printen)`n"
            . "Esc`tStoppen, of dialoog sluiten`n"
            . "Ctrl+G`tPlanning`n"
            . "Ctrl+I`tInstellingen`n"
            . "F1`tDit overzicht`n`n"
            . "Tijdens het printen werkt Esc altijd, ook als Pharmacom op de voorgrond staat.", "sneltoets")
    }

    static StuurFeedback(Keuze) {
        if Keuze != "mail" && Keuze != "teams"
            return
        Info := "App: " AppTitel " " AppVersie "`nComputer: " A_ComputerName "`nApotheek: " (Ronde.Apotheek != "" ? Ronde.Apotheek : "onbekend") "`nWindows: " A_OSVersion
        if Keuze = "mail" {
            Url := "mailto:" AppContact "?subject=" UriEncode(AppTitel ": vraag of idee") "&body=" UriEncode("Hoi " StrSplit(AppMaker, " ")[1] ",`n`n`n`n---`n" Info)
            try Run Url
            catch
                return this.Melding("Outlook niet gevonden", "Er kon geen mailprogramma geopend worden. Mail je vraag of idee naar:`n`n" AppContact, "waarschuwing")
            Log("Feedback: mail geopend")
        } else {
            Bericht := UriEncode("Hoi " StrSplit(AppMaker, " ")[1] ", een vraag/idee over de " AppTitel " (" AppVersie "): ")
            ; Eerst de Teams-app zelf, anders via de browser (die opent Teams)
            try Run "msteams:/l/chat/0/0?users=" AppContact "&message=" Bericht
            catch {
                try Run "https://teams.microsoft.com/l/chat/0/0?users=" AppContact "&message=" Bericht
                catch
                    return this.Melding("Teams niet gevonden", "Teams kon niet geopend worden. Stuur je bericht in Teams aan:`n`n" AppContact, "waarschuwing")
            }
            Log("Feedback: Teams-chat geopend")
        }
    }

    ; Geluid en knipperen als een ronde klaar of gestopt is
    static Geluid(Soort) {
        this.Toon()
        DllCall("FlashWindow", "Ptr", this.Hwnd, "Int", 1)
        if !Inst.Optie("geluid")
            return
        Bestand := A_WinDir "\Media\" (Soort = "klaar" ? "Windows Notify System Generic.wav" : "Windows Exclamation.wav")
        try SoundPlay FileExist(Bestand) ? Bestand : (Soort = "klaar" ? "*64" : "*48")
    }

    ; --- Van de pagina naar de app -------------------------------------------
    static Actie(A) {
        Delen := StrSplit(A, "/")
        Soort := Delen[1]
        if A = "knop/stop"
            return Ronde.Stop()
        if Soort = "dialoog" && Delen.Length >= 3
            return this.DialoogAntwoord["d" Delen[2]] := Delen[3]
        if Soort = "toggle"
            return Ronde.WisselVinkje(Integer(Delen[2]) + 1)
        if Soort = "alles"
            return Ronde.AllesWisselen()
        if Soort = "opt" && Delen.Length >= 3
            return this.ZetOptie(Delen[2], Delen[3] = "1")
        ; Langere acties (en slepen) niet binnen het bericht zelf uitvoeren
        this.Wachtrij.Push(A)
        SetTimer VensterVerwerk, -10
    }

    static Verwerk() {
        while this.Wachtrij.Length {
            A := this.Wachtrij.RemoveAt(1)
            switch A {
                case "knop/start": Ronde.StartRun()
                case "knop/proef": Ronde.StartRun(true)
                case "link/planning": Planning.Toon()
                case "link/sneltoetsen": this.Sneltoetsen()
                case "link/nieuw": Wijzigingen.Toon()
                case "knop/vernieuwen": Ronde.Vernieuw(false)
                case "knop/koppel": this.KoppelingInschakelen()
                case "link/instellingen": this.Instellingen()
                case "link/rapporten": try Run Opslag.RapportMap
                case "link/log": try Run Opslag.LogBestand
                case "link/diagnose": this.Diagnose()
                case "link/feedback": this.Feedback()
                case "link/over": this.Over()
                case "venster/slepen": this.Sleep_()
                case "venster/min": this.Gui.Minimize()
                case "venster/sluit": this.Sluit()
                default:
                    if SubStr(A, 1, 5) = "plan/"
                        Planning.Actie(A)
                    else if SubStr(A, 1, 5) = "inst/"
                        this.InstellingActie(A)
            }
        }
    }

    ; Venster verslepen zolang de linkermuisknop ingedrukt is
    static Sleep_() {
        CoordMode "Mouse", "Screen"
        MouseGetPos &Sx, &Sy
        WinGetPos &X, &Y, , , this.Hwnd
        while GetKeyState("LButton") {
            MouseGetPos &Mx, &My
            WinMove X + Mx - Sx, Y + My - Sy, , , this.Hwnd
            Sleep 10
        }
    }

    static ZetOptie(Naam, Aan) {
        if Naam = "autostart"
            Opstart.Zet(Aan)
        else
            Inst.ZetOptie(Naam, Aan)
        this.ZetBovenop()
        this.UiOpties()
        this.Hint()
    }

    static Sluit() {
        if Ronde.Bezig {
            if !this.Vraag("Afsluiten?", "Er wordt nog geprint. Wil je de app toch afsluiten?", "Afsluiten", "Doorgaan", "waarschuwing")
                return
            Ronde.Stoppen := true
        }
        Invoer.Blokkeer(false)
        ExitApp
    }

    ; --- Instellingen (wachttijden en updates) als dialoog in de pagina ------
    static Instellingen() {
        Items := []
        for w in Inst.Wachttijden
            Items.Push({k: w[1], label: w[3], v: Inst.Wt[w[1]], d: w[2]})
        ; Overzicht van de computers (Gegevens\Computers in de gedeelde map)
        Pcs := []
        for c in Staat.Computers()
            Pcs.Push({naam: c.naam, hier: c.hier, versie: c.versie, soort: c.soort, apotheek: c.apotheek
                , oud: VersieNummer(c.versie) < VersieNummer(AppVersie) ? 1 : 0
                , gezien: StrLen(c.gezien) >= 12 ? FormatTime(c.gezien, "ddd d-M HH:mm") : ""})
        this.UiOpties()
        this.Ui("instellingen", {items: Items, map: Inst.UpdateMap, apotheek: Inst.Apotheek, printmenu: Inst.PrintItem, computers: Pcs})
    }

    ; Acties uit de instellingen-dialoog: "inst/<actie>?k=v&..."
    static InstellingActie(A) {
        Actie := RegExReplace(SubStr(A, 6), "\?.*$")
        Params := Map()
        if InStr(A, "?")
            for Paar in StrSplit(SubStr(A, InStr(A, "?") + 1), "&") {
                kv := StrSplit(Paar, "=", , 2)
                Params[kv[1]] := kv.Length > 1 ? UriDecode(kv[2]) : ""
            }
        switch Actie {
            case "annuleer":
                return this.Ui("dialoogdicht")
            case "installeer":
                this.Ui("dialoogdicht")
                return Update.InstalleerLokaal(true)
            case "bladeren":
                this.Gui.Opt("+OwnDialogs")
                Gekozen := DirSelect(, 3, "Kies de map met de nieuwste Etiketten_autoprinter.exe")
                if Gekozen != ""
                    this.Ui("instmap", Gekozen)
                return
        }
        ; opslaan / controleer / publiceer: eerst de waarden bewaren
        for w in Inst.Wachttijden
            if Params.Has(w[1])
                Inst.ZetWachttijd(w[1], Params[w[1]])
        if Params.Has("printmenu")
            Inst.ZetPrintItem(Params["printmenu"])
        Inst.UpdateMap := Trim(Params.Has("map") ? Params["map"] : Inst.UpdateMap)
        try IniWrite Inst.UpdateMap, Inst.Eigen, "Update", "Map"   ; hoort bij deze computer
        Log("Instellingen opgeslagen")
        switch Actie {
            case "opslaan":
                this.Ui("dialoogdicht")
            case "controleer":
                Update.Controleer(false)
                this.Instellingen()
            case "publiceer":
                Update.Publiceer()
                this.Instellingen()
        }
    }

    ; --- Diagnose: wat ziet de app in Pharmacom? (alleen kolomkoppen) -------
    static Diagnose() {
        if Ronde.Bezig
            return
        this.Verbind()
        D := AppTitel " v" AppVersie " - diagnose`n`n"
        D .= "Pharmacom: " (Ph.Hwnd ? "gevonden (proces " Ph.Pid ")" : "niet gevonden") "`n"
        D .= "Java-map: " Ph.JreBin "`n"
        D .= "App: " (A_PtrSize = 8 ? "64-bit" : "32-bit") ", AutoHotkey " A_AhkVersion "`n"
        D .= "Koppeling ingesteld: " (Ph.JabPropsAan() ? "ja" : "nee") "`n"
        D .= "Koppeling actief: " (Ph.Verbonden ? "ja (" Jab.dll ")" : "nee") "`n"
        D .= "Instellingen: " Inst.Bestand "`n"
        D .= "Updates: " (Inst.UpdateMap != "" ? "map " Inst.UpdateMap : "geen map") ", " (Update.GitHub != "" ? "GitHub " Update.GitHub : "geen GitHub") "`n"
        D .= "`n" Opslag.FoutOverzicht(30)
        if Ph.Verbonden {
            Ap := Ph.LeesApotheek()
            D .= "Ingelogde apotheek: " (Ap != "" ? Ap : "niet gevonden") "`n"
            D .= "Afdrukmenu-item: " Inst.PrintItem (Inst.Apotheek != "" ? " (apotheek " Inst.Apotheek ")" : "") "`n"
            Alle := []
            Jab.ZoekTabel(Ph.Pid, Map(), Alle)
            D .= "`nZichtbare tabellen: " Alle.Length "`n"
            for i, t in Alle {
                Soort := JabTabel.PasKoppen(t.koppen, Ph.BufferKoppen) ? "  = AANSCHRIJFBUFFER"
                    : JabTabel.PasKoppen(t.koppen, Ph.HistorieKoppen) ? "  = MEDICATIEHISTORIE" : ""
                Kolommen := ""
                for c, k in t.koppen
                    Kolommen .= (c > 1 ? " | " : "") (k = "" ? "(leeg)" : k)
                D .= "`nTabel " i Soort "`n  " t.rows " regels, " t.cols " kolommen, geselecteerde regel: " (t.Geselecteerd() + 1) "`n  Kolommen: " Kolommen "`n"
            }
            Alle := ""
        }
        Log("`n" D)
        this.Melding("Diagnose", D "`n(Dit staat ook in het logbestand.)", "code")
    }
}

VensterBericht(Wv, Args) {
    try Bericht := Args.TryGetWebMessageAsString()
    catch
        return
    Venster.Actie(Bericht)
}

VensterVerwerk() => Venster.Verwerk()

; Venster hersteld na minimaliseren: meteen bijwerken (de bewaking pauzeert
; zolang het venster geminimaliseerd is)
VensterGrootte(g, MinMax, *) {
    if MinMax = -1 || !Venster.Wvc
        return
    Venster.Wvc.Fill()
    SetTimer () => Bewaking(), -50   ; eigen timer: de vaste 3 s-timer blijft
}
