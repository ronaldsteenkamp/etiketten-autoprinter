; =====================================================================
; De pati"entenlijst en de printronde
;
; Soorten pati"ent in de lijst: print = te printen, al = vandaag al
; geprint, ontslag, controle, en tijdens/na een ronde: bezig, ok, skip,
; fout. (De kleuren daarvan staan in ui\venster.html.)
; =====================================================================

class Ronde {
    static Patienten := []
    static Uitgevinkt := Map()       ; Pat.nr's die de gebruiker heeft uitgevinkt
    static HerprintOk := Map()       ; al geprint, maar toch aangevinkt
    static VandaagGeprint := Map()   ; Pat.nr -> tijd
    static Apotheek := ""
    static LaatsteHandtekening := "", LaatsteSnel := ""

    static Bezig := false, Stoppen := false, StopReden := ""
    static Gekozen := false          ; item in het afdrukmenu gekozen (telt als geprint)
    static Huidig := ""              ; patiënt die nu aan de beurt is (voor het vangnet)
    static FocusTerug := 0           ; zo vaak de focus teruggehaald deze ronde (Ph.HaalFocusTerug)
    static TerugGezet := false       ; na een stop staat Pharmacom weer netjes op de aanschrijfbuffer
    static StopPatnr := ""           ; bij welke patiënt de ronde stopte (niet geprint)
    static Aantal := 0, Verwerkt := 0, Geprint := 0, Overgeslagen := 0, Start := 0

    ; Legt de reden van een stop vast met een vaste foutcode (de eerste reden
    ; telt), bijv. Fout("P11", "Pharmacom keerde niet terug ..."). Zonder
    ; reden (Fout()) alleen stoppen: een eerdere stap heeft de reden al gezet.
    ; Geeft {stop: true} terug, of Terug als die is opgegeven (bijv. false
    ; voor een mislukte stap). De code staat altijd expliciet achter de tekst,
    ; dus de tekst kan veranderen zonder dat het gedrag verandert.
    static Fout(Code := "", Reden := "", Terug := "stop") {
        if this.StopReden = "" && Reden != ""
            this.StopReden := Code != "" ? Reden " [" Code "]" : MetCode(Reden)
        return Terug == "stop" ? {stop: true} : Terug
    }

    static Stop() {
        if this.Bezig {
            this.Stoppen := true
            Venster.Status("gestopt", "Wordt gestopt" Teken.Ellips)
        }
    }

    static Printbaar(Soort) => Soort = "print" || Soort = "al"

    static TelSoort(Soort) {
        n := 0
        for p in this.Patienten
            if p.soort = Soort
                n++
        return n
    }

    static TelAan() {
        n := 0
        for p in this.Patienten
            if p.aan && this.Printbaar(p.soort)
                n++
        return n
    }

    ; --- De lijst ------------------------------------------------------------
    ; Leest de aanschrijfbuffer in. Behoud = de vinkjes die de gebruiker zelf
    ; heeft gezet/weggehaald aanhouden (anders: terug naar de standaard).
    static Vernieuw(Behoud := false, Stil := false) {
        if this.Bezig
            return false
        if !Ph.Verbonden && Venster.Verbind() != "ok"
            return false
        if !Stil
            Venster.Status("idle", "De aanschrijfbuffer wordt uitgelezen" Teken.Ellips)
        t := Ph.Buffer()
        if !t {
            Venster.Status("fout", "De aanschrijfbuffer is niet gevonden. Open in Pharmacom het scherm Aanschrijfbuffer en klik op Vernieuwen.")
            return false
        }
        ; Zonder register weet de app niet wie vandaag al geprint is: dan
        ; geen lijst en geen ronde (anders zou iedereen opnieuw aangevinkt staan)
        R := Opslag.LeesRegister()
        if !IsObject(R) {
            this.Fout("P12", "het register van geprinte pati" Teken.EUml "nten is niet bereikbaar")
            Venster.Status("fout", "Het register van geprinte pati" Teken.EUml "nten (" Opslag.GeprintMap ") is niet bereikbaar. Zonder register kan de app niet zien wie vandaag al geprint is, dus er wordt niets geprint. Controleer of de netwerkmap bereikbaar is.")
            Log("Register van geprinte pati" Teken.EUml "nten niet bereikbaar (" Opslag.GeprintMap "): lijst niet bijgewerkt")
            return false
        }
        if !Behoud
            this.Uitgevinkt := Map(), this.HerprintOk := Map()
        this.VandaagGeprint := R
        ; Claims van andere rondes/computers (of van een vastgelopen app): die
        ; patiënten niet printen maar laten controleren
        Bezig := Opslag.Bezig()

        Lijst := []
        Handtekening := t.rows ":"
        loop t.rows {
            r := A_Index - 1
            p := {rij: r, naam: t.Cel(r, "naam"), patnr: t.Cel(r, "patnr"), ontslag: t.Cel(r, "ontslag"), gebdatum: t.Cel(r, "gebdatum"), etiket: ""}
            Handtekening .= p.patnr "/" p.ontslag ";"
            S := Regels.Soort(p.patnr, p.ontslag, this.VandaagGeprint, Bezig)
            p.soort := S[1]
            p.status := S[2] != "" ? S[2]
                : p.soort = "ontslag" ? (p.gebdatum != "" ? "Geboren " p.gebdatum : "Ontslagdatum " p.ontslag)
                : (p.gebdatum != "" ? "Geboren " p.gebdatum : "Klaar om te printen")
            p.aan := p.soort = "print" ? !this.Uitgevinkt.Has(p.patnr)
                : p.soort = "al" ? this.HerprintOk.Has(p.patnr) : false
            Lijst.Push(p)
        }
        t := ""
        this.LaatsteHandtekening := Handtekening
        n := Lijst.Length
        this.LaatsteSnel := n ":" (n ? Lijst[1].patnr "/" Lijst[n].patnr : "")

        this.Apotheek := Ph.LeesApotheek()
        Inst.ApotheekBevestigd := this.Apotheek != ""
        if this.Apotheek != Inst.Apotheek {
            ; Instellingen van deze apotheek gebruiken
            Inst.ZetApotheek(this.Apotheek)
            Venster.UiOpties()
            Venster.Hint()
        }
        Venster.Verbinding("ok", "Verbonden" (this.Apotheek != "" ? "  " Teken.Mid "  apotheek " this.Apotheek : ""))

        this.Patienten := Lijst
        this.Geprint := 0
        Venster.Lijst()
        Venster.Tellers()
        Venster.Ui("voortgang", {klaar: 0, totaal: 0, kleur: "", links: "Nog niet gestart", rechts: ""})
        Venster.KnopTekst("start", "Start printen")

        n := Lijst.Length, nOntslag := this.TelSoort("ontslag"), nControle := this.TelSoort("controle"), nAl := this.TelSoort("al")
        Venster.Status("idle", n " pati" Teken.EUml "nten in de aanschrijfbuffer, " nOntslag " met ontslagdatum" (nAl ? ", " nAl " vandaag al geprint" : "") (nControle ? ", " nControle " te controleren" : "") ". Klik op Start printen.")
        if this.Apotheek = ""
            Venster.Status("fout", "De ingelogde apotheek (rechtsonder in Pharmacom, bijv. 'AN - RS - 183') kon niet gelezen worden.")
        Log("Aanschrijfbuffer uitgelezen: " n " pati" Teken.EUml "nten, " nOntslag " met ontslagdatum, " nAl " vandaag al geprint, " nControle " te controleren, apotheek '" this.Apotheek "'")
        return true
    }

    ; Is het register van vandaag veranderd (bijv. een andere computer heeft
    ; geprint) sinds de lijst is ingelezen?
    static RegisterGewijzigd() {
        R := Opslag.LeesRegister()
        if !IsObject(R)
            return false   ; niet bereikbaar: de lijst houden zoals hij is (Vernieuw meldt het)
        if R.Count != this.VandaagGeprint.Count
            return true
        for Patnr in R
            if !this.VandaagGeprint.Has(Patnr)
                return true
        return false
    }

    static WisselVinkje(i) {
        if this.Bezig || i < 1 || i > this.Patienten.Length
            return
        p := this.Patienten[i]
        if !this.Printbaar(p.soort)
            return
        p.aan := !p.aan
        if p.soort = "al" {
            if p.aan
                this.HerprintOk[p.patnr] := true
            else if this.HerprintOk.Has(p.patnr)
                this.HerprintOk.Delete(p.patnr)
        } else if p.aan {
            if this.Uitgevinkt.Has(p.patnr)
                this.Uitgevinkt.Delete(p.patnr)
        } else
            this.Uitgevinkt[p.patnr] := true
        Venster.Rij(i, p.soort, p.status)
        Venster.Tellers()
    }

    ; Kop-vinkje: alles wat nog niet geprint is aan, of (als alles al aan
    ; staat) alles uit. Vandaag al geprinte pati"enten worden niet aangezet.
    static AllesWisselen() {
        if this.Bezig
            return
        AllesAan := true
        for p in this.Patienten
            if p.soort = "print" && !p.aan
                AllesAan := false
        for i, p in this.Patienten {
            if p.soort = "print" && p.aan = AllesAan
                this.WisselVinkje(i)
            else if AllesAan && p.soort = "al" && p.aan
                this.WisselVinkje(i)
        }
    }

    ; --- De ronde ------------------------------------------------------------
    ; Proef = alles doorlopen (dossier, controle, regel zoeken en selecteren)
    ; maar NIET printen. Auto = naam van een geplande ronde (geen vragen; al
    ; geprinte pati"enten worden dan nooit opnieuw geprint).
    ; Geeft true als de ronde volledig is afgerond.
    static Proef := false, Auto := ""
    ; Gereserveerd: vanaf de klik op Start (dus ook terwijl een vraag als
    ; "Opnieuw printen?" openstaat) tot het einde van de ronde. Zolang werkt de
    ; bewaking de lijst niet bij en start geen geplande ronde (die wordt
    ; uitgesteld), zodat de lijst onder de vraag niet kan veranderen.
    static Gereserveerd := false

    static StartRun(Proef := false, Auto := "") {
        if this.Bezig || this.Gereserveerd
            return false
        ; Geen handmatige ronde tijdens een geplande (bijv. tijdens het aftellen)
        if Auto = "" && Planning.Bezig {
            Venster.Status("fout", "Er loopt een geplande ronde. Wacht tot die klaar is.")
            return false
        }
        this.Gereserveerd := true
        try return this._StartRun(Proef, Auto)
        finally this.Gereserveerd := false
    }

    static _StartRun(Proef, Auto) {
        this.StopReden := ""   ; Vernieuw kan hieronder een reden zetten (register)
        if Venster.Verbind() != "ok" {
            Venster.Toon()
            return false
        }
        if !this.Vernieuw(true) || this.Apotheek = ""
            return false

        Doelen := [], nAl := 0
        for i, p in this.Patienten {
            if p.aan && this.Printbaar(p.soort) {
                if Auto != "" && p.soort = "al"
                    continue
                Doelen.Push(i)
                if p.soort = "al"
                    nAl++
            }
        }
        n := Doelen.Length
        if !n {
            Venster.Status(Auto != "" ? "klaar" : "fout", Auto != "" ? "Geplande ronde '" Auto "': niets te printen." : "Er is geen pati" Teken.EUml "nt aangevinkt om te printen.")
            if Auto != ""
                Log("Geplande ronde '" Auto "': niets te printen")
            return Auto != ""
        }
        ; Vandaag al geprint en toch aangevinkt: altijd even vragen
        if !Proef && nAl && !Venster.Vraag("Opnieuw printen?", nAl " aangevinkte pati" Teken.EUml "nt(en) zijn vandaag al geprint.`n`nWil je die echt opnieuw printen?", "Opnieuw printen", "Annuleren", "waarschuwing")
            return false
        if Proef && Auto = "" {
            if !Venster.Vraag("Proefronde", "De app doorloopt " n " pati" Teken.EUml "nt" (n = 1 ? "" : "en") " precies zoals bij printen (dossier openen, controleren, regel zoeken en selecteren), maar drukt niet op printen. Er wordt niets geprint en niets als geprint geregistreerd.`n`nNa afloop zie je per pati" Teken.EUml "nt welk etiket geprint zou worden.", "Proefronde starten", "Annuleren", "vraag")
                return false
        } else if Auto = "" && Inst.Optie("bevestigen") {
            nOntslag := this.TelSoort("ontslag")
            if !Venster.Vraag("Etiketten printen", n " pati" Teken.EUml "nt" (n = 1 ? "" : "en") " " Teken.Mid " apotheek " this.Apotheek
                . (Inst.Optie("deelbaar") ? " " Teken.Mid " alleen ASB: Deelbaar" : "")
                . (nOntslag ? "`n`n" nOntslag " pati" Teken.EUml "nt(en) met een ontslagdatum worden overgeslagen." : "")
                . (Inst.Optie("blokkeer") ? "`n`nToetsenbord en muis worden geblokkeerd tijdens het printen. Druk op Esc om te stoppen." : "`n`nDruk op Esc om te stoppen."), "Start printen", "Annuleren")
                return false
        }

        WinActivate "ahk_id " Ph.Hwnd
        if !WinWaitActive("ahk_pid " Ph.Pid, , 3) {
            Venster.Status("fout", "Pharmacom kon niet naar voren gehaald worden.")
            return false
        }
        Sleep 200

        this.Proef := Proef, this.Auto := Auto
        Wat := Proef ? "Proefronde" : Auto != "" ? "Geplande ronde '" Auto "'" : "Ronde"
        this.Bezig := true, this.Stoppen := false, this.StopReden := "", this.FocusTerug := 0, this.TerugGezet := false, this.StopPatnr := ""
        Venster.ZetBovenop()   ; tijdens het printen bovenop (optie)
        this.Aantal := n, this.Verwerkt := 0, this.Geprint := 0, this.Overgeslagen := 0
        OverslaanLijst := ""
        this.Start := A_TickCount
        Venster.ZetKnop("start", false)
        Venster.ZetKnop("proef", false)
        Venster.ZetKnop("vernieuwen", false)
        Venster.ZetKnop("stop", true)
        Venster.Ui("bezig", 1)
        Venster.Voortgang("blauw")
        SetTimer RondeTijd, 500
        RondeTijd()

        Instel := Wat " start: " n " pati" Teken.EUml "nten. Wachttijden (ms):"
        for w in Inst.Wachttijden
            Instel .= " " w[1] "=" Inst.Wt[w[1]]
        Log(Instel)
        Opslag.StartRapport(Proef)
        Wakker.Zet("ronde", true)
        Invoer.Blokkeer(true, Inst.Optie("blokkeer"))
        Venster.GeenActivatie(true)

        Afgebroken := false
        for i, r in Doelen {
            p := this.Patienten[r]
            p.geprintNu := false, p.geregistreerd := false
            this.Huidig := p, this.Gekozen := false
            Waakhond.Patient(p.patnr)
            Venster.Rij(r, "bezig", "Bezig" Teken.Ellips)
            Venster.Status("bezig", (Proef ? "Proef " Teken.Mid " " : "") "Pati" Teken.EUml "nt " i " van " n ": " p.naam "  " Teken.Mid "  Esc = stoppen")
            Log("Pat.nr " p.patnr ":")
            Res := this.PrintPatient(p)
            ; Claim vrijgeven (alleen een eigen claim). Geprint maar niet in het
            ; register gekomen: claim laten staan, dan slaan andere computers
            ; hem ook over.
            if !Proef && (!p.geprintNu || p.geregistreerd)
                Opslag.GeefVrij(p.patnr)

            if Res.HasProp("stop") {
                if this.StopReden = ""
                    this.StopReden := MetCode("onbekende fout")
                if p.geprintNu {
                    ; Het etiket is wel geprint, daarna ging er iets mis
                    this.Geprint++
                    p.soort := "ok"
                    Venster.Rij(r, "ok", "Geprint, daarna gestopt: " this.StopReden)
                    Opslag.Rapporteer(p, p.etiket, "Geprint (daarna gestopt: " this.StopReden ")", this.Apotheek)
                } else {
                    Venster.Rij(r, "fout", "Gestopt: " this.StopReden)
                    Opslag.Rapporteer(p, "", "Gestopt: " this.StopReden, this.Apotheek)
                }
                Afgebroken := true
                this.StopPatnr := p.geprintNu ? "" : p.patnr
                break
            }
            if Res.HasProp("proef") {
                this.Geprint++
                Venster.Rij(r, "proef", "Zou printen" (Res.tekst != "" ? ":  " Res.tekst : ""))
                Opslag.Rapporteer(p, Res.tekst, "Proef: zou printen", this.Apotheek)
                Log("Pat.nr " p.patnr " proef: zou printen")
            } else if Res.HasProp("ok") {
                this.Geprint++
                p.soort := "ok"
                Venster.Rij(r, "ok", "Geprint" (Res.tekst != "" ? "  " Teken.Mid "  " Res.tekst : ""))
                Opslag.Rapporteer(p, Res.tekst, "Geprint", this.Apotheek)
                Log("Pat.nr " p.patnr " geprint")
            } else {
                this.Overgeslagen++
                if !Proef {
                    p.soort := "skip"
                    this.Uitgevinkt[p.patnr] := true   ; bij Doorgaan niet opnieuw proberen
                }
                Venster.Rij(r, "skip", "Overgeslagen: " Res.tekst)
                Opslag.Rapporteer(p, "", "Overgeslagen: " Res.tekst, this.Apotheek)
                OverslaanLijst .= "- " p.naam " (" p.patnr "): " Res.tekst "`n"
                Log("Pat.nr " p.patnr " overgeslagen (" Res.tekst ")")
            }
            this.Verwerkt := i
            Venster.Voortgang("blauw")
            Venster.Tellers()
        }

        this.Huidig := ""
        ; --- Afronden ---
        ; Na een stop of fout: Pharmacom netjes terugzetten op de
        ; aanschrijfbuffer (dossier dicht), zodat Doorgaan meteen werkt. Niet
        ; als de gebruiker in een ander venster bezig is.
        if Afgebroken && !RegExMatch(FoutCode(this.StopReden), "^P0[12]$") {
            this.Stoppen := false   ; anders weigert Stap de Escape
            Venster.Sub("Pharmacom terugzetten op de aanschrijfbuffer" Teken.Ellips)
            if this.TerugGezet := Ph.TerugNaarBuffer()   ; tekst vóór de foutcode
                this.StopReden := RegExReplace(this.StopReden, "( \[\w+\])?$", " (Pharmacom staat weer op de aanschrijfbuffer)$1", , 1)
        }
        Venster.GeenActivatie(false)
        Invoer.Blokkeer(false)
        Wakker.Zet("ronde", false)
        Waakhond.Patient(0)
        this.Bezig := false
        Venster.ZetBovenop()
        Venster.Ui("bezig", 0)
        SetTimer RondeTijd, 0
        Duur := FmtTijd((A_TickCount - this.Start) // 1000)
        Venster.ZetKnop("start", true)
        Venster.ZetKnop("proef", true)
        Venster.ZetKnop("vernieuwen", Ph.Verbonden)
        Venster.ZetKnop("stop", false)
        Venster.Tellers()
        this.Proef := false, this.Auto := ""

        Samenvatting := this.Geprint (Proef ? " zou" (this.Geprint = 1 ? "" : "den") " geprint worden" : " geprint") ", " this.Overgeslagen " overgeslagen"
        if StrLen(OverslaanLijst) > 1500
            OverslaanLijst := SubStr(OverslaanLijst, 1, 1500) Teken.Ellips "`n"
        ; Bij een geplande ronde geen meldingen die op een klik wachten
        Melden := (Titel, Tekst, Soort := "info") => Auto != "" ? Melder.Toon(Tekst, AppTitel " - " Titel, Soort = "info" ? 1 : 2) : Venster.Melding(Titel, Tekst, Soort)

        if Afgebroken {
            Venster.Voortgang("oranje")
            Venster.Ui("tijd", "Gestopt na " Duur)
            if !Proef
                Venster.KnopTekst("start", "Doorgaan")
            Venster.Status("gestopt", Wat " gestopt bij pati" Teken.EUml "nt " (this.Verwerkt + 1) " van " this.Aantal ": " this.StopReden ". (" Samenvatting ")" (Proef ? "" : " Klik op Doorgaan om verder te gaan; wie al geprint is, wordt overgeslagen."))
            Log(Wat " gestopt: " this.StopReden " (" Samenvatting ")")
            Venster.Geluid("gestopt")
            Melden("Gestopt", this.StopReden ".`n`n" Samenvatting "." (OverslaanLijst != "" ? "`n`nOvergeslagen, handmatig controleren:`n" OverslaanLijst : "") (Proef ? "" : "`n`nMet Doorgaan ga je verder; wie al geprint is, staat uitgevinkt."), "waarschuwing")
            return false
        }
        Venster.Voortgang("groen")
        Venster.Ui("tijd", "Klaar in " Duur)
        Venster.Status("klaar", (Proef ? "Proefronde klaar: " : Auto != "" ? "Geplande ronde '" Auto "' klaar: " : "") Samenvatting "." (Proef ? " Er is niets geprint." : " Het rapport staat in de map Rapporten."))
        Log(Wat " klaar: " Samenvatting " in " Duur)
        Venster.Geluid("klaar")
        if OverslaanLijst != ""
            Melden(Proef ? "Proefronde klaar" : "Klaar!", Samenvatting ".`n`nOvergeslagen, handmatig controleren:`n" OverslaanLijst)
        else
            Melder.Toon((Proef ? "Proefronde klaar: " : "Klaar! ") Samenvatting ".", , 1)
        return true
    }

    ; Print het etiket voor een pati"ent. Geeft terug:
    ;   {ok: true, tekst: etiketnaam}   geprint
    ;   {tekst: reden}                  overgeslagen
    ;   {stop: true}                    afbreken (reden staat in StopReden)
    static PrintPatient(p) {
        ; --- 0. Register: intussen (op een andere computer) al geprint? ---
        ; Eerst de patiënt "claimen" (Opslag.Claim), daarna het register
        ; lezen: een andere computer schrijft het register vóór hij zijn claim
        ; weer vrijgeeft, dus wie de claim krijgt, ziet ook zijn registratie.
        if !this.Proef {
            c := Opslag.Claim(p.patnr)
            if c.HasProp("fout")
                return this.Fout("P12", "het register van geprinte pati" Teken.EUml "nten is niet bereikbaar (" c.fout ")")
            if c.HasProp("bezet")
                return {tekst: "staat op 'bezig' bij " c.bezet " (een andere ronde, of daar vastgelopen): controleer of er een etiket is"}
        }
        R := Opslag.LeesRegister()
        if !IsObject(R)
            return this.Fout("P12", "het register van geprinte pati" Teken.EUml "nten is niet bereikbaar")
        if R.Has(p.patnr) && !this.HerprintOk.Has(p.patnr)
            return {tekst: "intussen al geprint om " R[p.patnr]}

        ; --- 1. Pati"ent in de aanschrijfbuffer opzoeken en selecteren ---
        Venster.Sub("Pati" Teken.EUml "nt opzoeken in de aanschrijfbuffer" Teken.Ellips)
        ; De aanschrijfbuffer van de vorige pati"ent hergebruiken als die nog
        ; zichtbaar is (scheelt opnieuw zoeken en alle kolomkoppen lezen)
        t := Ph.BufferBewaakt()
        if !t
            t := Ph.WachtOpTabel(Ph.BufferKoppen, Inst.Wt["MaxWachtScherm"])
        if !t
            return this.Fout("P04", "de aanschrijfbuffer is niet zichtbaar in Pharmacom")
        Rij := Ph.ZoekRij(t, "patnr", p.patnr, p.rij)
        if Rij < 0
            return {tekst: "niet meer in de aanschrijfbuffer"}
        Ontslag := t.Cel(Rij, "ontslag")
        if Ontslag != ""
            return {tekst: "ontslagdatum " Ontslag}
        ok := Ph.Selecteer(t, Rij)
        t := ""
        if !ok
            return this.Fout("P05", "de pati" Teken.EUml "nt kon niet geselecteerd worden in de aanschrijfbuffer (sluit een eventueel open dossier en klik op Doorgaan)")
        Log("  geselecteerd in aanschrijfbuffer (regel " (Rij + 1) ")")

        ; --- 2. Dossier en medicatiehistorie openen ---
        Venster.Sub("Dossier openen" Teken.Ellips)
        Voor := WinExist("A")
        if !Ph.Stap("^b", 0, "Ctrl+B")
            return this.Fout()
        ; Het dossier is een apart venster: wachten tot dat actief is
        Dossier := Ph.WachtOpNieuwVenster(Voor, Inst.Wt["MaxWachtScherm"])
        if !Dossier
            return this.Fout("P06", "het pati" Teken.EUml "ntdossier verscheen niet")
        Log("  dossier geopend")
        ; Alleen voor tests van het vangnet: [Test] Fout=dossier in de ini laat
        ; een proefronde hier een fout gooien (nooit bij echt printen)
        if this.Proef && Inst.Lees1("Test", "Fout", "") = "dossier"
            throw Error("testfout voor het vangnet (alleen in een proefronde)")
        Ph.Wacht(Inst.Wt["SleepNaCtrlB"])

        Venster.Sub("Medicatiehistorie openen" Teken.Ellips)
        ; Vanaf hier gaan alle toetsen alleen naar het dossiervenster
        if !Ph.Stap("{F4}", 0, "F4", Dossier)
            return this.Fout()
        ; Beide helften in één keer zoeken: rechts (Ap, Herhaal info) en
        ; links (Etiketnaam, voor de naam en om de selectie te controleren).
        ; Alleen in het dossiervenster: nooit een tabel uit een ander venster.
        HE := Ph.WachtOpTabellen([Ph.HistorieKoppen, Ph.EtiketKoppen], Inst.Wt["MaxWachtScherm"], Dossier)
        h := HE ? HE[1] : "", e := HE ? HE[2] : "", HE := ""
        if !h {
            Log("  medicatiehistorie niet gevonden in het dossiervenster")
            Ph.LogZichtbareTabellen()
            return this.Fout("P07", "de medicatiehistorie werd niet herkend in het dossier (zie logbestand)")
        }
        Log("  medicatiehistorie zichtbaar")
        Ph.Wacht(Inst.Wt["SleepNaF4"])
        ; Pijl omhoog: zet de focus in de tabel (zoals altijd)
        if !Ph.Stap("{Up}", Inst.Wt["SleepNaOmhoog"], "Pijl omhoog", Dossier)
            return this.Fout()

        ; Wachten tot de inhoud geladen en stabiel is. Een lege tabel telt als
        ; "nog aan het laden", tot MaxWachtLeeg verstreken is.
        Vorige := "", Gelijk := 0, Stabiel := false
        LeegTot := A_TickCount + Inst.Wt["MaxWachtLeeg"]
        Eind := A_TickCount + Inst.Wt["MaxWachtScherm"]
        loop {
            if this.Stoppen
                return this.Fout("G01", "gestopt door gebruiker")
            if h.Rijen() = 0 && A_TickCount < LeegTot
                Vorige := "", Gelijk := 0
            else {
                Snap := h.Momentopname("ap", "einddatum")
                Gelijk := Snap = Vorige ? Gelijk + 1 : 0
                if Gelijk >= 2 {
                    Stabiel := true
                    break
                }
                Vorige := Snap
            }
            if A_TickCount > Eind
                break
            Ph.Wacht(120)
        }
        if !Stabiel
            return this.Fout("P07", "de medicatiehistorie bleef veranderen")
        if h.Rijen() = 0 {
            h := ""
            Log("  medicatiehistorie bleef leeg")
            if !Ph.Stap("{Escape}", Inst.Wt["SleepNaEscape"], "Escape (lege historie)", Dossier)
                return this.Fout()
            if !Ph.WachtTerug(Dossier)
                return this.Fout("P11", "Pharmacom keerde niet terug naar de aanschrijfbuffer")
            return {tekst: "medicatiehistorie is leeg"}
        }

        ; --- Controle: is dit dossier van de juiste pati"ent? (altijd) ---
        ; (Geen naam in de reden: die komt in het log, het rapport en de
        ; planningstatus; het Pat.nr is genoeg.)
        Venster.Sub("Controleren of het dossier van " p.naam " is" Teken.Ellips)
        if !Ph.BevestigDossier(p, Dossier)
            return this.Fout("P08", "kon niet bevestigen dat het geopende dossier van Pat.nr " p.patnr " is")

        ; --- 3. Bovenste regel van de eigen apotheek (en evt. ASB: Deelbaar) ---
        Omschrijving := "Ap = " this.Apotheek (Inst.Optie("deelbaar") ? " en ASB: Deelbaar" : "")
        Venster.Sub("Regel met " Omschrijving " zoeken" Teken.Ellips)
        Rijen := h.Rijen()
        AnRij := Regels.KiesRegel(Rijen, (r, k) => h.Cel(r, k), this.Apotheek, Inst.Optie("deelbaar"))
        if AnRij < 0 {
            h := ""
            Log("  geen regel met " Omschrijving " (" Rijen " regels)")
            if !Ph.Stap("{Escape}", Inst.Wt["SleepNaEscape"], "Escape (geen passende regel)", Dossier)
                return this.Fout()
            if !Ph.WachtTerug(Dossier)
                return this.Fout("P11", "Pharmacom keerde niet terug naar de aanschrijfbuffer")
            return {tekst: "geen regel met " Omschrijving}
        }
        ; Linker tabel (Etiketnaam): al gevonden met de medicatiehistorie; zo
        ; niet (nog niet zichtbaar toen), nu zoeken
        if !e
            e := Jab.ZoekTabel(Ph.Pid, Ph.EtiketKoppen, "", Dossier)
        Etiket := e ? e.Cel(AnRij, "etiket") : ""
        this.SchaduwSortering(e, Rijen)
        ok := Ph.Selecteer(h, AnRij, e)
        if !ok {
            h := "", e := ""
            return this.Fout("P09", "de regel met " Omschrijving " kon niet geselecteerd worden")
        }
        ; Laatste controle vlak voor het printen: staat de selectie nog goed
        ; en staat op die regel nog wat er gekozen is?
        Ph.Wacht(Inst.Wt["SleepNavigatie"])
        Reden := this.RegelKlopt(h, e, AnRij, Etiket, Vorige)
        h := "", e := ""
        if Reden != "" {
            Log("  regel klopt niet meer vlak voor het printen: " Reden)
            return this.Fout("P09", "de regel met " Omschrijving " klopte vlak voor het printen niet meer (" Reden ")")
        }
        Log("  regel met " Omschrijving " geselecteerd en gecontroleerd (regel " (AnRij + 1) ")")

        ; --- Proefronde: hier stoppen, niet printen ---
        if this.Proef {
            if !Ph.Stap("{Escape}", Inst.Wt["SleepNaEscape"], "Escape (proef, niet geprint)", Dossier)
                return this.Fout()
            if !Ph.WachtTerug(Dossier)
                return this.Fout("P11", "Pharmacom keerde niet terug naar de aanschrijfbuffer")
            return {proef: true, tekst: Etiket}
        }

        ; --- 4. Printen ---
        Venster.Sub("Etiket printen" Teken.Ellips)
        this.Gekozen := false
        ok := Ph.PrintEtiket(Dossier)
        if this.Gekozen {
            ; Vanaf het kiezen in het afdrukmenu telt het etiket als geprint
            ; (ook als er daarna iets misgaat), zodat het bij Doorgaan niet nog
            ; eens geprint wordt. Lukt het register niet, dan blijft het in het
            ; geheugen (Opslag.Wachtend) en blijft de claim staan, zodat ook
            ; andere computers hem niet printen.
            Tijd := Opslag.Registreer(p.patnr)
            p.geregistreerd := Tijd != ""
            this.VandaagGeprint[p.patnr] := Tijd != "" ? Tijd : "?"
            if this.HerprintOk.Has(p.patnr)
                this.HerprintOk.Delete(p.patnr)
            p.geprintNu := true
            p.etiket := Etiket
        }
        if !ok
            return this.Fout()
        if !Ph.WachtTerug(Dossier)
            return this.Fout("P11", "Pharmacom keerde na het printen niet terug naar de aanschrijfbuffer")
        if !p.geregistreerd
            return this.Fout("P12", "het register van geprinte pati" Teken.EUml "nten kon niet bijgewerkt worden (het etiket is wel geprint)")
        return {ok: true, tekst: Etiket}
    }

    ; SCHADUWMODUS (nog geen stop): staat de medicatiehistorie op Laatste V/A,
    ; nieuwste bovenaan? De uitkomst gaat alleen naar het log ("SCHADUW
    ; sortering"); zodra de logs laten zien dat het in de praktijk altijd
    ; klopt, wordt dit een echte controle. Leest alleen datums (max. 15 regels).
    static SchaduwSortering(e, Rijen) {
        try {
            c := e ? e.Kolom("i)^Laatste\s*V") : -1
            if c < 0
                return Log("  SCHADUW sortering: kolom Laatste V/A niet gevonden")
            Datums := []
            loop Min(Rijen, 15)
                Datums.Push(e.CelKol(A_Index - 1, c))
            Reden := Regels.Aflopend(Datums)
            Log("  SCHADUW sortering Laatste V/A: " (Reden = "" ? "aflopend" : "NIET aflopend: " Reden))
        } catch as f
            Log("  SCHADUW sortering: fout (" f.Message ")")
    }

    ; Controle vlak voor het printen: "" als alles klopt, anders de reden.
    ; - de selectie staat op Rij (en geen van beide helften staat ergens anders);
    ; - de bovenste regels zijn niet veranderd sinds de historie stabiel was (Snap);
    ; - op Rij staan nog Ap = de apotheek, evt. ASB: Deelbaar, en dezelfde etiketnaam.
    static RegelKlopt(h, e, Rij, Etiket, Snap) {
        Sh := h.Geselecteerd(), Se := e ? e.Geselecteerd() : -1
        if Sh != Rij && Se != Rij
            return "de selectie staat niet op regel " (Rij + 1)
        if (Sh >= 0 && Sh != Rij) || (Se >= 0 && Se != Rij)
            return "de twee helften van de medicatiehistorie hebben een andere selectie"
        if h.Momentopname("ap", "einddatum") != Snap
            return "de medicatiehistorie is veranderd"
        if h.Cel(Rij, "ap") != this.Apotheek
            return "Ap is niet meer " this.Apotheek
        if Inst.Optie("deelbaar") && !RegExMatch(h.Cel(Rij, "herhaal"), Regels.DeelbaarPatroon)
            return "Herhaal info is niet meer ASB: Deelbaar"
        if e && e.Cel(Rij, "etiket") != Etiket
            return "de etiketnaam is veranderd"
        return ""
    }
}

RondeTijd() {
    Verstreken := (A_TickCount - Ronde.Start) // 1000
    if Ronde.Verwerkt > 0 {
        Resterend := Round((A_TickCount - Ronde.Start) / Ronde.Verwerkt * (Ronde.Aantal - Ronde.Verwerkt) / 1000)
        Venster.Ui("tijd", FmtTijd(Verstreken) " verstreken  " Teken.Mid "  nog " Teken.PlusMin " " FmtTijd(Resterend))
    } else
        Venster.Ui("tijd", FmtTijd(Verstreken) " verstreken")
}
