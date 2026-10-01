; =====================================================================
; Planning: groepen (afdelingen) automatisch printen op vaste tijden.
;
; Per apotheek een lijst in de ini-sectie [Planning <code>], bijv.
; [Planning AN]; per regel: aan|naam|instelling|afdeling|dagen|tijd|weken|computer
;   dagen  = cijfers 1 (ma) t/m 7 (zo), bijv. "135" = ma, wo, vr
;   tijd   = uu:mm
;   weken  = alle / even / oneven (ISO-weeknummer)
;   computer = de computer die de ronde uitvoert (zo print nooit meer dan
;              één computer dezelfde groep)
; Een geplande ronde start binnen 15 minuten na de ingestelde tijd, één
; keer per dag, en alleen als Pharmacom open is. Eerst 30 seconden aftellen
; (met Annuleren), dan: groep zoeken in Pharmacom, lijst uitlezen, printen.
; =====================================================================

class Planning {
    static Bezig := false
    static MaxMinuten := 15     ; minuten na de ingestelde tijd dat hij nog start

    static Sectie => "Planning" (Inst.Apotheek != "" ? " " Inst.Apotheek : "")

    ; --- Opslag ----------------------------------------------------------------
    ; Lijst in de volgorde van de gebruiker (sleutel _volgorde = "3,1,2";
    ; regels die daar niet in staan komen erachter, op id).
    static Lees() {
        Items := []
        try Inhoud := IniRead(Inst.Bestand, this.Sectie)
        catch
            return Items
        Volgorde := ""
        Bekend := Groepen.Lees()
        loop parse Inhoud, "`n", "`r" {
            if RegExMatch(A_LoopField, "^_volgorde=(.*)$", &M) {
                Volgorde := M[1]
                continue
            }
            if !RegExMatch(A_LoopField, "^(\d+)=(.*)$", &M)
                continue
            d := StrSplit(M[2], "|")
            if d.Length < 8
                continue
            it := {id: M[1], aan: d[1] = "1" ? 1 : 0, naam: d[2], instelling: d[3], afdeling: d[4]
                , dagen: d[5], tijd: d[6], weken: d[7], computer: d[8], opmerking: d.Length >= 9 ? d[9] : ""}
            ; De naam is altijd de naam van de groep (omschrijving van de afdeling)
            it.naam := this.GroepNaam(it.instelling, it.afdeling, Bekend)
            Items.Push(it)
        }
        ; Sorteren op de opgeslagen volgorde
        Plek := Map()
        for i, Id in StrSplit(Volgorde, ",")
            Plek[Trim(Id)] := i
        Gesorteerd := [], Rest := []
        loop Plek.Count + 1 {
            n := A_Index
            for it in Items
                if Plek.Has(it.id) && Plek[it.id] = n
                    Gesorteerd.Push(it)
        }
        for it in Items
            if !Plek.Has(it.id)
                Gesorteerd.Push(it)
        return Gesorteerd
    }

    static SchrijfVolgorde(Items) {
        s := ""
        for it in Items
            s .= (A_Index > 1 ? "," : "") it.id
        Inst.Schrijf(s, this.Sectie, "_volgorde")
    }

    ; Regel Id een plek omhoog (-1) of omlaag (+1)
    static Verplaats(Id, Richting) {
        Items := this.Lees()
        for i, it in Items {
            if it.id != Id
                continue
            j := i + Richting
            if j < 1 || j > Items.Length
                return
            Tmp := Items[i], Items[i] := Items[j], Items[j] := Tmp
            return this.SchrijfVolgorde(Items)
        }
    }

    ; Regel Id naar plek Plek (0 = bovenaan) slepen
    static VerplaatsNaar(Id, Plek) {
        Items := this.Lees()
        for i, it in Items {
            if it.id != Id
                continue
            Items.RemoveAt(i)
            Items.InsertAt(Max(1, Min(Integer(Plek) + 1, Items.Length + 1)), it)
            return this.SchrijfVolgorde(Items)
        }
    }

    ; Op naam sorteren (A-Z, hoofdletterongevoelig)
    static SorteerOpNaam() {
        Items := this.Lees()
        loop Items.Length - 1 {
            loop Items.Length - A_Index {
                k := A_Index
                if StrCompare(Items[k].naam, Items[k + 1].naam, "Logical") > 0
                    Tmp := Items[k], Items[k] := Items[k + 1], Items[k + 1] := Tmp
            }
        }
        this.SchrijfVolgorde(Items)
    }

    static Schrijf(it) {
        Schoon := (s) => StrReplace(StrReplace(StrReplace(StrReplace(Trim(s), "|", "/"), "`r", ""), "`n", " "), "=", "-")
        Inst.Schrijf((it.aan ? 1 : 0) "|" Schoon(it.naam) "|" Schoon(it.instelling) "|" Schoon(it.afdeling) "|" it.dagen "|" it.tijd "|" it.weken "|" it.computer
            . "|" Schoon(it.HasProp("opmerking") ? it.opmerking : ""), this.Sectie, it.id)
    }

    ; Naam van een groep: omschrijving van de afdeling (bijv. "T2 Maandag
    ; Bezorgen"), anders de code
    static GroepNaam(Instelling, Afdeling, Bekend := "") {
        Bekend := Bekend ? Bekend : Groepen.Lees()
        if Bekend.afdelingen.Has(Instelling) && Bekend.afdelingen[Instelling].Has(Afdeling) && Bekend.afdelingen[Instelling][Afdeling] != ""
            return Bekend.afdelingen[Instelling][Afdeling]
        return Afdeling
    }

    ; Staat deze groep al in de planning (behalve regel Behalve)? Geeft die
    ; regel, of "".
    static Dubbel(Instelling, Afdeling, Behalve := "") {
        for it in this.Lees()
            if it.id != Behalve && it.instelling = Instelling && it.afdeling = Afdeling
                return it
        return ""
    }

    static Verwijder(Id) {
        if IsInteger(Id) && Integer(Id) > Inst.Getal(Inst.Lees1(this.Sectie, "_laatsteid", 0), 0)
            Inst.Schrijf(Integer(Id), this.Sectie, "_laatsteid")
        try IniDelete Inst.Bestand, this.Sectie, Id
        try IniDelete Inst.Bestand, "Planning gedraaid", A_ComputerName "-" Inst.Apotheek "-" Id
        try IniDelete Inst.Bestand, "Planning status", A_ComputerName "-" Inst.Apotheek "-" Id
    }

    ; Nummers worden nooit hergebruikt (anders zou een nieuwe planning het
    ; "laatst gedraaid" van een verwijderde erven)
    static NieuwId() {
        Hoogste := Inst.Getal(Inst.Lees1(this.Sectie, "_laatsteid", 0), 0)
        for it in this.Lees()
            Hoogste := Max(Hoogste, Integer(it.id))
        Inst.Schrijf(Hoogste + 1, this.Sectie, "_laatsteid")
        return Hoogste + 1
    }

    static LaatstGedraaid(it) => Inst.Lees1("Planning gedraaid", A_ComputerName "-" Inst.Apotheek "-" it.id, "")
    static ZetGedraaid(it) => Inst.Schrijf(FormatTime(, "yyyyMMddHHmm"), "Planning gedraaid", A_ComputerName "-" Inst.Apotheek "-" it.id)

    ; --- Tijd --------------------------------------------------------------------
    static WeekNr(Tijd := "") => Integer(SubStr(FormatTime(Tijd, "YWeek"), 5))
    ; 1 = maandag ... 7 = zondag
    static Weekdag(Tijd := "") => Mod(Integer(FormatTime(Tijd, "WDay")) + 5, 7) + 1

    static WeekKlopt(Weken, Tijd := "") {
        Even := Mod(this.WeekNr(Tijd), 2) = 0
        return Weken = "alle" || (Weken = "even" && Even) || (Weken = "oneven" && !Even)
    }

    ; Moet deze planning nu (of op tijdstip Nu, voor tests) starten?
    ; Laatst = wanneer hij voor het laatst gedraaid heeft (yyyyMMddHHmm).
    static NuAan(it, Nu := "", Laatst := "?") {
        Nu := Nu = "" ? A_Now : Nu
        if !it.aan || it.computer != A_ComputerName || !InStr(it.dagen, this.Weekdag(Nu)) || !this.WeekKlopt(it.weken, Nu)
            return false
        if !RegExMatch(it.tijd, "^(\d{1,2}):(\d{2})$", &T)
            return false
        Start := SubStr(Nu, 1, 8) Format("{:02}{:02}00", T[1], T[2])
        ; In seconden: DateDiff in minuten rondt af naar nul (dan zou hij tot
        ; 59 s te vroeg starten)
        Verschil := DateDiff(Nu, Start, "Seconds")
        if Verschil < 0 || Verschil >= this.MaxMinuten * 60
            return false
        Laatst := Laatst = "?" ? this.LaatstGedraaid(it) : Laatst
        return SubStr(Laatst, 1, 8) != SubStr(Nu, 1, 8)
    }

    ; Geplande momenten (yyyyMMddHHmm00) van planning it na Van tot en met Tot
    ; (dagen en even/oneven weken meegerekend; maximaal 31 dagen).
    static Momenten(it, Van, Tot) {
        Res := []
        if !RegExMatch(it.tijd, "^(\d{1,2}):(\d{2})$", &T)
            return Res
        Dag := SubStr(Van, 1, 8) "000000"
        loop 32 {
            Moment := SubStr(Dag, 1, 8) Format("{:02}{:02}00", T[1], T[2])
            if StrCompare(Moment, Van) > 0 && StrCompare(Moment, Tot) <= 0
                && InStr(it.dagen, this.Weekdag(Moment)) && this.WeekKlopt(it.weken, Moment)
                Res.Push(Moment)
            Dag := DateAdd(Dag, 1, "Days")
            if StrCompare(SubStr(Dag, 1, 8), SubStr(Tot, 1, 8)) > 0
                break
        }
        return Res
    }

    ; Gemiste momenten van planning it tussen de vorige controle (Vorige) en
    ; Tot: het moment is voorbij (incl. de 15 minuten waarin hij nog start) en
    ; de planning heeft die dag niet gedraaid (Laatst, yyyyMMddHHmm).
    static Gemist(it, Vorige, Tot, Laatst) {
        Res := []
        if !it.aan || it.computer != A_ComputerName
            return Res
        for m in this.Momenten(it, Vorige, Tot)
            if StrCompare(SubStr(Laatst, 1, 8), SubStr(m, 1, 8)) < 0
                Res.Push(m)
        return Res
    }

    ; --- Status per planning (laatste uitkomst) --------------------------------
    ; [Planning status] <computer>-<apotheek>-<id> = soort|yyyyMMddHHmm|tekst
    ; soort: ok / mislukt / geannuleerd / gemist
    static StatusSleutel(it) => A_ComputerName "-" Inst.Apotheek "-" it.id

    static ZetStatus(it, Soort, Tekst := "", Tijd := "") {
        Tijd := Tijd = "" ? A_Now : Tijd
        Tekst := StrReplace(StrReplace(StrReplace(Tekst, "|", "/"), "`n", " "), "`r", "")
        Inst.Schrijf(Soort "|" SubStr(Tijd, 1, 12) "|" Tekst, "Planning status", this.StatusSleutel(it))
    }

    static LeesStatus(it) {
        d := StrSplit(Inst.Lees1("Planning status", this.StatusSleutel(it), ""), "|", , 3)
        if d.Length < 2
            return ""
        return {soort: d[1], tijd: d[2], tekst: d.Length >= 3 ? d[3] : ""}
    }

    ; Elke 20 s: gemiste momenten melden, en starten wat nu aan de beurt is
    static Tik() {
        if Inst.Apotheek = ""
            return
        this.ControleerGemist()
        if this.Bezig || Ronde.Bezig
            return
        for it in this.Lees()
            if this.NuAan(it)
                return this.Voer(it)
    }

    ; Momenten die buiten het startvenster zijn geraakt zonder dat de planning
    ; draaide (pc uit, app dicht, slaapstand, of een lange ronde). Elk moment
    ; wordt één keer bekeken: tot en met Tot (= nu - 15 min) wordt onthouden.
    static ControleerGemist(Nu := "") {
        Nu := Nu = "" ? A_Now : Nu
        Tot := DateAdd(Nu, -this.MaxMinuten, "Minutes")
        Sleutel := A_ComputerName "-" Inst.Apotheek "-gecontroleerd"
        Vorige := Inst.Lees1("Planning gedraaid", Sleutel, "")
        Week := DateAdd(Nu, -7, "Days")
        if Vorige = "" || StrCompare(Vorige, Week) < 0
            Vorige := Vorige = "" ? Tot : Week
        if StrCompare(Vorige, Tot) >= 0
            return
        Inst.Schrijf(Tot, "Planning gedraaid", Sleutel)
        Regels := ""
        for it in this.Lees() {
            for m in this.Gemist(it, Vorige, Tot, this.LaatstGedraaid(it)) {
                this.ZetStatus(it, "gemist", "", m)
                Regels .= Teken.Punt " " it.naam ": " FormatTime(m, "ddd d-M HH:mm") "`n"
                Log("Planning gemist: '" it.naam "' van " FormatTime(m, "d-M HH:mm"))
            }
        }
        if Regels = ""
            return
        TrayTip "Er zijn geplande rondes niet uitgevoerd. Zie de planning.", AppTitel, 2
        Tekst := "Deze geplande rondes zijn niet uitgevoerd (de app draaide niet, de computer stond uit of sliep, of er liep al een ronde):`n`n" Regels "`nPrint deze groepen zo nodig met de hand, of gebruik in de planning het driehoekje (nu uitvoeren)."
        SetTimer () => Venster.Melding("Planning niet uitgevoerd", Tekst, "waarschuwing"), -300
    }

    ; --- Uitvoeren ------------------------------------------------------------
    static Voer(it, Handmatig := false, Proef := false) {
        this.Bezig := true
        try {
            if !Proef
                this.ZetGedraaid(it)
            Log("Geplande ronde '" it.naam "' (" it.instelling " / " it.afdeling ")" (Proef ? " als proefronde" : Handmatig ? " handmatig gestart" : ""))
            Status := (Soort, Tekst := "") => Proef ? 0 : this.ZetStatus(it, Soort, Tekst)
            if Venster.Verbind() != "ok" {
                Log("  Pharmacom niet bereikbaar, ronde overgeslagen")
                Status("mislukt", "Pharmacom was niet open")
                TrayTip "Geplande ronde '" it.naam "' overgeslagen: Pharmacom is niet open.", AppTitel, 2
                return
            }
            if !Handmatig {
                Keuze := Venster.Dialoog({soort: "planning", titel: "Geplande ronde: " it.naam
                    , tekst: "Over 30 seconden zoekt de app in Pharmacom de groep " it.afdeling " (" it.instelling ") en print de etiketten.`n`nToetsenbord en muis worden daarna even overgenomen. Wil je dat nu niet, klik dan op Annuleren."
                    , knoppen: [{t: "Annuleren", v: "0"}, {t: "Nu starten", v: "1", hoofd: 1}]}, 30000, "1")
                if Keuze != "1" {
                    Log("  geannuleerd door gebruiker")
                    Status("geannuleerd")
                    Venster.Status("idle", "Geplande ronde '" it.naam "' geannuleerd.")
                    return
                }
            }
            Venster.Status("bezig", "Geplande ronde '" it.naam "': groep " it.afdeling " zoeken in Pharmacom" Teken.Ellips)
            Res := Ph.ZetGroep(it.instelling, it.afdeling)
            if Res != "" {
                Log("  groep zoeken mislukt: " Res)
                Status("mislukt", Res)
                Venster.Status("fout", "Geplande ronde '" it.naam "' niet gestart: " Res)
                TrayTip "Geplande ronde '" it.naam "' niet gestart: " Res, AppTitel, 2
                Venster.Geluid("gestopt")
                return
            }
            Ronde.Vernieuw(false, true)
            if Ronde.StartRun(Proef, it.naam)
                Status("ok", Ronde.Geprint " geprint, " Ronde.Overgeslagen " overgeslagen")
            else
                Status("mislukt", Ronde.StopReden != "" ? Ronde.StopReden : "de ronde is niet afgerond")
        } catch as e {
            Log("  fout in geplande ronde: " e.Message " (" e.What ", regel " e.Line ")")
            if !Proef
                this.ZetStatus(it, "mislukt", "onverwachte fout: " e.Message)
        } finally
            this.Bezig := false
    }

    ; --- Pagina ------------------------------------------------------------------
    static Toon() {
        Items := []
        for it in this.Lees()
            Items.Push({id: it.id, aan: it.aan, naam: it.naam, instelling: it.instelling, afdeling: it.afdeling
                , dagen: it.dagen, tijd: it.tijd, weken: it.weken, computer: it.computer, opmerking: it.opmerking
                , hier: it.computer = A_ComputerName ? 1 : 0, laatst: this.LaatstTekst(it), status: this.StatusVoorPagina(it)})
        Wk := this.WeekNr()
        Venster.Ui("planning", {items: Items, apotheek: Inst.Apotheek, computer: A_ComputerName
            , week: Wk, even: Mod(Wk, 2) = 0 ? 1 : 0, groepen: Groepen.VoorPagina()})
    }

    ; {soort, tekst} voor de lijst, of "" als er nog niets bekend is
    static StatusVoorPagina(it) {
        s := this.LeesStatus(it)
        if !s || StrLen(s.tijd) < 12
            return ""
        Wanneer := FormatTime(s.tijd "00", "ddd d-M HH:mm")
        switch s.soort {
            case "ok": return {soort: "ok", tekst: "gelukt " Wanneer (s.tekst != "" ? " (" s.tekst ")" : "")}
            case "mislukt": return {soort: "mislukt", tekst: "mislukt " Wanneer (s.tekst != "" ? ": " s.tekst : "")}
            case "geannuleerd": return {soort: "geannuleerd", tekst: "geannuleerd " Wanneer}
            case "gemist": return {soort: "gemist", tekst: "niet uitgevoerd " Wanneer}
        }
        return ""
    }

    static LaatstTekst(it) {
        l := this.LaatstGedraaid(it)
        return StrLen(l) >= 12 ? FormatTime(SubStr(l, 1, 12) "00", "d-M HH:mm") : ""
    }

    ; Acties uit de pagina: "plan/<actie>?k=v&..."
    static Actie(A) {
        Actie := RegExReplace(SubStr(A, 6), "\?.*$")
        P := Map()
        if InStr(A, "?")
            for Paar in StrSplit(SubStr(A, InStr(A, "?") + 1), "&") {
                kv := StrSplit(Paar, "=", , 2)
                P[kv[1]] := kv.Length > 1 ? UriDecode(kv[2]) : ""
            }
        Id := P.Has("id") ? P["id"] : ""
        Zoek(Id) {
            for it in Planning.Lees()
                if it.id = Id
                    return it
            return ""
        }
        switch Actie {
            case "sluit":
                return Venster.Ui("dialoogdicht")
            case "opslaan":
                if Inst.Apotheek = ""
                    return Venster.Melding("Planning", "De ingelogde apotheek is nog niet bekend. Open Pharmacom op de aanschrijfbuffer en probeer het opnieuw.", "waarschuwing")
                Instelling := StrUpper(Trim(P["instelling"])), Afdeling := StrUpper(Trim(P["afdeling"]))
                ; Elke groep maar één keer in de planning
                if d := this.Dubbel(Instelling, Afdeling, Id)
                    return Venster.Ui("planfout", "Deze groep staat al in de planning ('" d.naam "'). Pas die planning aan, bijvoorbeeld met extra dagen.")
                it := {id: Id != "" ? Id : this.NieuwId(), aan: 1, instelling: Instelling, afdeling: Afdeling
                    , naam: this.GroepNaam(Instelling, Afdeling), opmerking: P.Has("opmerking") ? P["opmerking"] : ""
                    , dagen: RegExReplace(P["dagen"], "[^1-7]"), tijd: P["tijd"], weken: P["weken"], computer: A_ComputerName}
                if Id != "" && (oud := Zoek(Id))
                    it.aan := oud.aan
                this.Schrijf(it)
                Log("Planning opgeslagen: '" it.naam "' " it.afdeling " dagen " it.dagen " " it.tijd " " it.weken)
            case "verwijder":
                if (it := Zoek(Id)) && Venster.Vraag("Planning verwijderen", "'" it.naam "' verwijderen uit de planning?", "Verwijderen", "Annuleren", "waarschuwing") {
                    this.Verwijder(Id)
                    Log("Planning verwijderd: '" it.naam "'")
                }
            case "wissel":
                if it := Zoek(Id) {
                    it.aan := !it.aan
                    this.Schrijf(it)
                }
            case "hier":
                ; Deze computer laten uitvoeren
                if it := Zoek(Id) {
                    it.computer := A_ComputerName
                    this.Schrijf(it)
                }
            case "ophalen":
                if Ronde.Bezig
                    return
                this.Bezig := true      ; bewaking even stil
                try {
                    Venster.Ui("planinfo", "Groepen ophalen uit Pharmacom" Teken.Ellips)
                    G := Ph.HaalGroepen((t) => Venster.Ui("planinfo", t))
                } finally
                    this.Bezig := false
                if !IsObject(G)
                    return (Venster.Ui("planinfo", ""), Venster.Ui("planfout", "Ophalen mislukt: " G))
                Groepen.Bewaar(G)
                nA := 0
                for c, L in G.afdelingen
                    nA += L.Count
                Venster.Ui("plangroepen", Groepen.VoorPagina())
                Venster.Toon(true)
                return Venster.Ui("planinfo", G.instellingen.Count " instellingen en " nA " afdelingen opgehaald. Pharmacom staat weer op je eigen groep.")
            case "naar":
                if P.Has("plek") && IsInteger(P["plek"])
                    this.VerplaatsNaar(Id, P["plek"])
            case "omhoog":
                this.Verplaats(Id, -1)
            case "omlaag":
                this.Verplaats(Id, 1)
            case "sorteer":
                this.SorteerOpNaam()
            case "nu":
                if (it := Zoek(Id)) && Venster.Vraag("Nu uitvoeren", "'" it.naam "' nu uitvoeren? De app zoekt groep " it.afdeling " in Pharmacom en print de etiketten.", "Nu uitvoeren", "Annuleren") {
                    Venster.Ui("dialoogdicht")
                    return this.Voer(it, true)
                }
            case "proef":
                ; Groep kiezen en alles doorlopen, maar niet printen (en niet als
                ; "vandaag gedraaid" tellen)
                if (it := Zoek(Id)) && Venster.Vraag("Proefronde", "'" it.naam "' nu als proefronde uitvoeren? De app zoekt groep " it.afdeling " in Pharmacom en doorloopt alle pati" Teken.EUml "nten, maar print niets.", "Proefronde starten", "Annuleren") {
                    Venster.Ui("dialoogdicht")
                    return this.Voer(it, true, true)
                }
        }
        this.Toon()
    }
}

PlanningTik() => Planning.Tik()

; =====================================================================
; Bekende groepen per apotheek (voor de keuzelijsten bij de planning).
; [Groepen AN]
;   I    = T1=2 WEKELIJKS 1|T2=2 WEKELIJKS 2|...
;   A_T1 = T1DI=T1 Dinsdag Bezorgen|T1GUA=T1 GUA|...
; Wordt gevuld door "Alle groepen ophalen" en door elke groep die de app in
; Pharmacom tegenkomt (geplande rondes).
; =====================================================================
class Groepen {
    static Sectie => "Groepen" (Inst.Apotheek != "" ? " " Inst.Apotheek : "")

    static Schoon(s) => StrReplace(StrReplace(StrReplace(Trim(s), "|", "/"), "=", "-"), "`n", " ")

    static LeesLijst(Sleutel) {
        M := Map()
        for Paar in StrSplit(Inst.Lees1(this.Sectie, Sleutel, ""), "|") {
            kv := StrSplit(Paar, "=", , 2)
            if kv.Length = 2 && kv[1] != ""
                M[kv[1]] := kv[2]
        }
        return M
    }

    static SchrijfLijst(Sleutel, M) {
        s := ""
        for k, v in M
            s .= (s = "" ? "" : "|") this.Schoon(k) "=" this.Schoon(v)
        Inst.Schrijf(s, this.Sectie, Sleutel)
    }

    ; {instellingen: Map, afdelingen: Map inst -> Map}
    static Lees() {
        I := this.LeesLijst("I"), A := Map()
        for Code in I
            A[Code] := this.LeesLijst("A_" Code)
        return {instellingen: I, afdelingen: A}
    }

    ; Eén groep onthouden (als die nog niet bekend is)
    static Leer(InstCode, InstNaam, AfdCode, AfdNaam) {
        if InstCode = "" || Inst.Apotheek = "" || InStr(InstCode, "*") || InStr(InstCode, "$")
            return
        I := this.LeesLijst("I")
        if !I.Has(InstCode) || (I[InstCode] = "" && InstNaam != "") {
            I[InstCode] := InstNaam
            this.SchrijfLijst("I", I)
        }
        if AfdCode = ""
            return
        A := this.LeesLijst("A_" InstCode)
        if !A.Has(AfdCode) || (A[AfdCode] = "" && AfdNaam != "") {
            A[AfdCode] := AfdNaam
            this.SchrijfLijst("A_" InstCode, A)
        }
    }

    ; Volledige lijst opslaan (na "Alle groepen ophalen")
    static Bewaar(G) {
        this.SchrijfLijst("I", G.instellingen)
        for Code, Afd in G.afdelingen
            this.SchrijfLijst("A_" Code, Afd)
    }

    ; Voor de pagina: {inst: [{c, n}], afd: {T1: [{c, n}], ...}}
    static VoorPagina() {
        G := this.Lees(), Ins := [], Afd := Map()
        for Code, Naam in G.instellingen {
            Ins.Push({c: Code, n: Naam})
            L := []
            for c, n in G.afdelingen[Code]
                L.Push({c: c, n: n})
            Afd[Code] := L
        }
        return {inst: Ins, afd: Afd}
    }
}
