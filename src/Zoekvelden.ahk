; =====================================================================
; Zoekvelden van de aanschrijfbuffer: Instelling en Afdeling invullen,
; Zoeken, de aanschrijfbuffer openen (Ctrl+F11) en alle groepen ophalen.
; Gebruikt door de planning. De verbinding met Pharmacom (Pid, Hwnd) staat
; in Ph (Pharmacom.ahk).
; =====================================================================

class PhZoek {
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
        if Ph.Verbind() != "ok"
            return "Pharmacom is niet bereikbaar"
        if WinGetMinMax(Ph.Hwnd) = -1
            WinRestore "ahk_id " Ph.Hwnd
        WinActivate "ahk_id " Ph.Hwnd
        if !WinWaitActive("ahk_id " Ph.Hwnd, , 3)
            return "Pharmacom kon niet naar voren gehaald worden (staat er een venster open?)"
        if !Ph.OpBufferScherm()
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
                if a && WinGetPID(a) = Ph.Pid && InStr(WinGetTitle(a), Titel)
                    Venster_ := a
        }
        if !Venster_
            return "het venster '" Titel "' verscheen niet"
        Sleep 300
        Res := Map()
        t := Jab.ZoekTabel(Ph.Pid, Koppen)
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

    ; {code, omschrijving, x, y, w, h} van een zoekveld, of "". Houd = ook
    ; het tekstvak zelf bewaren ({vm, el}; daarna vrijgeven met Jab.Release).
    static Veld(Label, Houd := false) {
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
                        if Houd {
                            Res.vm := Vm, Res.el := Kind
                            continue    ; niet vrijgeven
                        }
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
        return Jab.Doorzoek(Ph.Pid, Bezoek)
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
        return Jab.Doorzoek(Ph.Pid, Bezoek)
    }

    ; Klikt in het midden van een element (schermcoördinaten), alleen als
    ; Pharmacom het actieve venster is.
    static KlikOp(e) {
        if !WinActive("ahk_id " Ph.Hwnd)
            return false
        CoordMode "Mouse", "Screen"
        MouseGetPos &Mx, &My
        Click e.x + e.w // 2, e.y + e.h // 2
        MouseMove Mx, My, 0
        return true
    }

    ; Heeft dit element de toetsenbordfocus? (even wachten: de focus wordt
    ; door Java later verplaatst)
    static HeeftFocus(Vm, El) {
        loop 10 {
            if (i := Jab.Info(Vm, El)) && Jab.Heeft(i, "focused")
                return true
            Sleep 30
        }
        return false
    }

    ; Typt een code in een zoekveld en controleert dat Pharmacom hem
    ; accepteert (de code staat erin en er is een omschrijving). "" = gelukt.
    ; Eerst direct via de koppeling (focus op het tekstvak, tekst erin zetten;
    ; geen muisklik op een plek en geen typen), anders klikken en typen. Tab
    ; laat Pharmacom de code controleren, zoals bij de hand.
    static ZetVeld(Label, Waarde) {
        v := this.Veld(Label, true)
        if !v
            return "het veld " Label " is niet gevonden"
        Direct := false
        if v.HasProp("el") {
            if !(v.code = Waarde && v.omschrijving != "") && WinActive("ahk_id " Ph.Hwnd)
                && Jab.Focus(v.vm, v.el) && this.HeeftFocus(v.vm, v.el)
                Direct := Jab.ZetTekst(v.vm, v.el, Waarde) && Trim(Jab.Naam(v.vm, v.el)) = Waarde
            Jab.Release(v.vm, v.el)
        }
        if v.code = Waarde && v.omschrijving != ""
            return ""
        if !Direct {
            if !this.KlikOp(v)
                return "Pharmacom was niet het actieve venster"
            Sleep 150
            Send "^a"
            SendText Waarde
        }
        if !WinActive("ahk_id " Ph.Hwnd)
            return "Pharmacom was niet het actieve venster"
        Send "{Tab}"
        Log("  " Label " " Waarde " ingevuld" (Direct ? " (via de koppeling)" : ""))
        Eind := A_TickCount + 4000
        loop {
            Sleep 150
            ; Een (zoek)venster van Pharmacom = de code werd niet herkend
            a := WinExist("A")
            if a && a != Ph.Hwnd {
                try Pid := WinGetPID(a)
                catch
                    Pid := 0
                if Pid = Ph.Pid {
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

    ; Opent de aanschrijfbuffer met Ctrl+F11 (knop "Aanschrijfbuffer" in de
    ; werkbalk van Pharmacom) en wacht tot het scherm met de zoekvelden en de
    ; lijst er is. Geeft "" of de reden waarom het niet lukte.
    static OpenBuffer() {
        if !WinActive("ahk_id " Ph.Hwnd)
            return "Pharmacom was niet het actieve venster"
        Log("  aanschrijfbuffer openen (Ctrl+F11)")
        Ph.VergeetBuffer()
        Send "^{F11}"
        Eind := A_TickCount + Inst.Wt["MaxWachtScherm"]
        loop {
            Sleep 250
            if Ph.OpBufferScherm() && Ph.Buffer() && this.Veld("Afdeling:") {
                Log("  aanschrijfbuffer geopend")
                Sleep 300
                return ""
            }
            if A_TickCount > Eind
                return "de aanschrijfbuffer ging niet open (Ctrl+F11)"
            if !WinActive("ahk_pid " Ph.Pid)
                return "Pharmacom was niet meer het actieve venster"
        }
    }

    ; Vult Instelling en Afdeling in, klikt op Zoeken en wacht tot de lijst
    ; geladen is. Geeft "" als het gelukt is, anders de reden.
    static ZetGroep(Instelling, Afdeling) {
        if Ph.Verbind() != "ok"
            return "Pharmacom is niet bereikbaar"
        if WinGetMinMax(Ph.Hwnd) = -1
            WinRestore "ahk_id " Ph.Hwnd
        WinActivate "ahk_id " Ph.Hwnd
        if !WinWaitActive("ahk_id " Ph.Hwnd, , 3)
            return "Pharmacom kon niet naar voren gehaald worden (staat er een venster open?)"
        ; Niet alleen op de titel afgaan: een scherm zonder schermnaam in de
        ; titel telt als aanschrijfbuffer. Ontbreken de zoekvelden, dan openen.
        if (!Ph.OpBufferScherm() || !this.Veld("Afdeling:")) && (R := this.OpenBuffer()) != ""
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
            ; Lege groep: Pharmacom toont "Geen patiënten gevonden" (een venster
            ; dat op OK wacht). Sluiten, anders blijft het openstaan en wordt
            ; de volgende geplande ronde uitgesteld ("melding open").
            a := WinExist("A")
            try {
                if a && a != Ph.Hwnd && WinGetPID(a) = Ph.Pid && InStr(WinGetTitle(a), "Geen pati") {
                    Send "{Enter}"
                    WinWaitClose "ahk_id " a, , 3
                    Log("  Pharmacom: geen pati" Teken.EUml "nten gevonden (melding gesloten)")
                    Sleep 300
                    if WinExist("ahk_id " a)
                        return "de melding 'Geen pati" Teken.EUml "nten gevonden' ging niet dicht"
                    return ""
                }
            }
            Stop := this.Knop("Stoppen met zoeken")
            if !(Stop && Stop.aan) {
                H := Ph.Handtekening(true)
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
        t := Jab.ZoekTabel(Ph.Pid, Map("afd", "i)^Afd$"))
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
}
