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
    static Lees() {
        Items := []
        try Inhoud := IniRead(Inst.Bestand, this.Sectie)
        catch
            return Items
        loop parse Inhoud, "`n", "`r" {
            if !RegExMatch(A_LoopField, "^(\d+)=(.*)$", &M)
                continue
            d := StrSplit(M[2], "|")
            if d.Length < 8
                continue
            Items.Push({id: M[1], aan: d[1] = "1" ? 1 : 0, naam: d[2], instelling: d[3], afdeling: d[4]
                , dagen: d[5], tijd: d[6], weken: d[7], computer: d[8]})
        }
        return Items
    }

    static Schrijf(it) {
        Schoon := (s) => StrReplace(StrReplace(Trim(s), "|", "/"), "=", "-")
        Inst.Schrijf((it.aan ? 1 : 0) "|" Schoon(it.naam) "|" Schoon(it.instelling) "|" Schoon(it.afdeling) "|" it.dagen "|" it.tijd "|" it.weken "|" it.computer, this.Sectie, it.id)
    }

    static Verwijder(Id) {
        try IniDelete Inst.Bestand, this.Sectie, Id
    }

    static NieuwId() {
        Hoogste := 0
        for it in this.Lees()
            Hoogste := Max(Hoogste, Integer(it.id))
        return Hoogste + 1
    }

    static LaatstGedraaid(it) => Inst.Lees1("Planning gedraaid", A_ComputerName "-" Inst.Apotheek "-" it.id, "")
    static ZetGedraaid(it) => Inst.Schrijf(FormatTime(, "yyyyMMddHHmm"), "Planning gedraaid", A_ComputerName "-" Inst.Apotheek "-" it.id)

    ; --- Tijd --------------------------------------------------------------------
    static WeekNr(Tijd := "") => Integer(SubStr(FormatTime(Tijd, "YWeek"), 5))
    static VandaagDag() => Mod(A_WDay + 5, 7) + 1        ; 1 = maandag ... 7 = zondag

    static WeekKlopt(Weken) {
        Even := Mod(this.WeekNr(), 2) = 0
        return Weken = "alle" || (Weken = "even" && Even) || (Weken = "oneven" && !Even)
    }

    ; Moet deze planning nu starten?
    static NuAan(it) {
        if !it.aan || it.computer != A_ComputerName || !InStr(it.dagen, this.VandaagDag()) || !this.WeekKlopt(it.weken)
            return false
        if !RegExMatch(it.tijd, "^(\d{1,2}):(\d{2})$", &T)
            return false
        Start := FormatTime(, "yyyyMMdd") Format("{:02}{:02}00", T[1], T[2])
        Verschil := DateDiff(A_Now, Start, "Minutes")
        if Verschil < 0 || Verschil >= this.MaxMinuten
            return false
        return SubStr(this.LaatstGedraaid(it), 1, 8) != FormatTime(, "yyyyMMdd")
    }

    ; Elke 20 s
    static Tik() {
        if this.Bezig || Ronde.Bezig || Inst.Apotheek = ""
            return
        for it in this.Lees()
            if this.NuAan(it)
                return this.Voer(it)
    }

    ; --- Uitvoeren ------------------------------------------------------------
    static Voer(it, Handmatig := false) {
        this.Bezig := true
        try {
            this.ZetGedraaid(it)
            Log("Geplande ronde '" it.naam "' (" it.instelling " / " it.afdeling ")" (Handmatig ? " handmatig gestart" : ""))
            if Venster.Verbind() != "ok" {
                Log("  Pharmacom niet bereikbaar, ronde overgeslagen")
                TrayTip "Geplande ronde '" it.naam "' overgeslagen: Pharmacom is niet open.", AppTitel, 2
                return
            }
            if !Handmatig {
                Keuze := Venster.Dialoog({soort: "planning", titel: "Geplande ronde: " it.naam
                    , tekst: "Over 30 seconden zoekt de app in Pharmacom de groep " it.afdeling " (" it.instelling ") en print de etiketten.`n`nToetsenbord en muis worden daarna even overgenomen. Wil je dat nu niet, klik dan op Annuleren."
                    , knoppen: [{t: "Annuleren", v: "0"}, {t: "Nu starten", v: "1", hoofd: 1}]}, 30000, "1")
                if Keuze != "1" {
                    Log("  geannuleerd door gebruiker")
                    Venster.Status("idle", "Geplande ronde '" it.naam "' geannuleerd.")
                    return
                }
            }
            Venster.Status("bezig", "Geplande ronde '" it.naam "': groep " it.afdeling " zoeken in Pharmacom" Teken.Ellips)
            Res := Ph.ZetGroep(it.instelling, it.afdeling)
            if Res != "" {
                Log("  groep zoeken mislukt: " Res)
                Venster.Status("fout", "Geplande ronde '" it.naam "' niet gestart: " Res)
                TrayTip "Geplande ronde '" it.naam "' niet gestart: " Res, AppTitel, 2
                Venster.Geluid("gestopt")
                return
            }
            Ronde.Vernieuw(false, true)
            Ronde.StartRun(false, it.naam)
        } catch as e {
            Log("  fout in geplande ronde: " e.Message " (" e.What ", regel " e.Line ")")
        } finally
            this.Bezig := false
    }

    ; --- Pagina ------------------------------------------------------------------
    static Toon() {
        Items := []
        for it in this.Lees()
            Items.Push({id: it.id, aan: it.aan, naam: it.naam, instelling: it.instelling, afdeling: it.afdeling
                , dagen: it.dagen, tijd: it.tijd, weken: it.weken, computer: it.computer
                , hier: it.computer = A_ComputerName ? 1 : 0, laatst: this.LaatstTekst(it)})
        Wk := this.WeekNr()
        Venster.Ui("planning", {items: Items, apotheek: Inst.Apotheek, computer: A_ComputerName
            , week: Wk, even: Mod(Wk, 2) = 0 ? 1 : 0})
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
                it := {id: Id != "" ? Id : this.NieuwId(), aan: 1, naam: P["naam"], instelling: P["instelling"], afdeling: P["afdeling"]
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
            case "overnemen":
                G := Ph.LeesGroep()
                if !IsObject(G)
                    return Venster.Ui("planfout", "De groep kon niet uit Pharmacom gelezen worden: " G)
                return Venster.Ui("planveld", G)
            case "nu":
                if (it := Zoek(Id)) && Venster.Vraag("Nu uitvoeren", "'" it.naam "' nu uitvoeren? De app zoekt groep " it.afdeling " in Pharmacom en print de etiketten.", "Nu uitvoeren", "Annuleren") {
                    Venster.Ui("dialoogdicht")
                    return this.Voer(it, true)
                }
        }
        this.Toon()
    }
}

PlanningTik() => Planning.Tik()
