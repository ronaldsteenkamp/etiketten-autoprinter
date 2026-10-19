; =====================================================================
; Opslag: logbestand, register van geprinte pati"enten, rapporten
;
; Register, rapporten, logs en de toestand per computer staan in de gedeelde
; map (Inst.DataMap; bij een lokale installatie de netwerkmap waar hij
; vandaan kwam), zodat alles van alle computers op één plek staat. Is die
; niet bereikbaar, dan naast de app. Het log is er een per dag, per computer
; en bevat alleen Pat.nr's.
; =====================================================================

Log(Msg) => Opslag.Log(Msg)

class Opslag {
    static GeprintMap := "", RapportMap := "", LogMap := ""
    static RapportBestand := ""

    ; De gedeelde map, of de map van de app als die niet bereikbaar is
    static Hoofdmap() => InStr(FileExist(Inst.DataMap), "D") ? Inst.DataMap : A_ScriptDir

    static Init() {
        DataMap := this.Hoofdmap()
        this.GeprintMap := DataMap "\Gegevens\Geprint"
        this.RapportMap := DataMap "\Rapporten"
        this.LogMap := DataMap "\Gegevens\Log"
        this.ClaimMap := this.GeprintMap "\Bezig"
        Staat.Dir := DataMap "\Gegevens\Computers"
        for m in [this.GeprintMap, this.ClaimMap, this.RapportMap, this.LogMap, Staat.Dir]
            try DirCreate m
        this.Opruim()
        try FileDelete A_ScriptDir "\Gegevens\Etiketten_autoprinter_log.txt"   ; oud log (v5.3-5.6)
    }

    ; Staan de gegevens (rapporten met naam en geboortedatum, logs, register)
    ; in dezelfde map als de app of de updatemap? Dan kan iedereen die de app
    ; mag starten of bijwerken ook de rapporten lezen. Geeft "" of een
    ; waarschuwing (voor het log en de diagnose). Zie docs\ICT.md.
    static MapWaarschuwing() {
        Data := RTrim(this.Hoofdmap(), "\")
        for Naam, Map_ in Map("de map van de app", A_ScriptDir, "de updatemap", Inst.UpdateMap)
            if Map_ != "" && Data = RTrim(Map_, "\")
                return "de gegevens (rapporten met namen en geboortedata, logs, register) staan in " Naam " (" Data "). Zet ze in een aparte, afgeschermde map: [Opslag] Map= in de ini (zie docs\ICT.md)"
        return ""
    }

    ; Bewaartermijnen: rapporten bevatten naam en geboortedatum (AVG), het
    ; register alleen Pat.nr's en is na de dag zelf niet meer nodig. Bij het
    ; starten en elke 6 uur (zie hoofdbestand, niet tijdens een ronde), zodat
    ; een app die dagen openstaat ook opruimt.
    static Opruim() {
        n := Opruimen(this.LogMap "\*.txt", 30)
            + Opruimen(this.RapportMap "\Rapport *.csv", Inst.RapportDagen)
            + Opruimen(this.RapportMap "\Proefronde *.csv", Inst.RapportDagen)
            + Opruimen(this.GeprintMap "\*.txt", Inst.RegisterDagen)
            + Opruimen(this.ClaimMap "\*.txt", 2)
        if n
            this.Log("Opgeruimd: " n " oude bestanden (logs, rapporten, register, claims)")
    }

    static LogBestand => this.LogMap "\" FormatTime(, "yyyy-MM-dd") " " A_ComputerName ".txt"

    static Log(Msg) {
        try FileAppend FormatTime(, "HH:mm:ss") "." A_MSec " - " Msg "`n", this.LogBestand, "UTF-8"
    }

    ; Overzicht van de laatste Dagen uit de logs van alle computers: rondes
    ; klaar en hoe vaak elke foutcode voorkwam (tekst voor de diagnose)
    static FoutOverzicht(Dagen := 30) {
        Regels := [], Bestanden := 0
        loop files this.LogMap "\*.txt" {
            if DateDiff(A_Now, A_LoopFileTimeModified, "Days") > Dagen
                continue
            Bestanden++
            try loop read A_LoopFileFullPath
                Regels.Push(A_LoopReadLine)
        }
        T := TelLogregels(Regels)
        s := "Laatste " Dagen " dagen (" Bestanden " logbestanden, alle computers): " T.klaar " rondes afgerond"
        if !T.codes.Count
            return s ", geen foutcodes.`n"
        s .= ". Foutcodes:`n"
        for c, n in T.codes
            s .= "  [" c "] " n Chr(215) "  " FoutOmschrijving(c) "`n"
        return s
    }

    ; --- Register van vandaag geprinte pati"enten (dubbel printen voorkomen)
    ; Faalt nooit stil: niet te lezen = "" (de app print dan niet), niet te
    ; schrijven = de registratie blijft in Wachtend en wordt bij elke keer
    ; lezen opnieuw weggeschreven (en telt intussen gewoon mee).
    static RegisterBestand => this.GeprintMap "\" FormatTime(, "yyyy-MM-dd") ".txt"
    static Wachtend := []    ; [{dag, tijd, patnr}] nog niet in het register gekomen

    ; Map Pat.nr -> tijd (uu:mm), of "" als het register niet te lezen is
    ; (map niet bereikbaar, bestand niet te openen). Geen bestand in een
    ; bereikbare map = vandaag nog niemand geprint.
    static LeesRegister() {
        if !InStr(FileExist(this.GeprintMap), "D")
            return ""
        Geprint := Map()
        if FileExist(this.RegisterBestand) {
            try {
                loop read this.RegisterBestand {
                    Delen := StrSplit(A_LoopReadLine, ";")
                    if Delen.Length >= 2 && Delen[2] != ""
                        Geprint[Delen[2]] := SubStr(Delen[1], 1, 5)
                }
            } catch
                return ""
        }
        this.Inhalen(Geprint)
        return Geprint
    }

    ; Geeft de tijd (uu:mm) terug, of "" als het register niet bijgewerkt kon
    ; worden (dan staat hij in Wachtend)
    static Registreer(Patnr) {
        Tijd := FormatTime(, "HH:mm:ss"), Dag := FormatTime(, "yyyy-MM-dd")
        if !this.SchrijfRegistratie(Dag, Tijd, Patnr) {
            this.Wachtend.Push({dag: Dag, tijd: Tijd, patnr: Patnr})
            Log("  LET OP: Pat.nr " Patnr " kon niet in het register gezet worden (" this.GeprintMap "); wordt later opnieuw geprobeerd")
            return ""
        }
        return SubStr(Tijd, 1, 5)
    }

    static SchrijfRegistratie(Dag, Tijd, Patnr) {
        loop 3 {
            try {
                FileAppend Tijd ";" Patnr "`n", this.GeprintMap "\" Dag ".txt", "UTF-8-RAW"
                return true
            }
            Sleep 200
        }
        return false
    }

    ; Registraties die nog niet weggeschreven konden worden: meetellen (als
    ; ze van vandaag zijn) en opnieuw proberen weg te schrijven
    static Inhalen(Geprint) {
        Vandaag := FormatTime(, "yyyy-MM-dd")
        i := this.Wachtend.Length
        while i >= 1 {
            w := this.Wachtend[i]
            if w.dag = Vandaag && !Geprint.Has(w.patnr)
                Geprint[w.patnr] := SubStr(w.tijd, 1, 5)
            if this.SchrijfRegistratie(w.dag, w.tijd, w.patnr) {
                this.Wachtend.RemoveAt(i)
                Log("Pat.nr " w.patnr " alsnog in het register gezet")
            }
            i--
        }
    }

    ; --- Claim: "deze patiënt wordt nu door mij verwerkt" -------------------
    ; Een bestand per patiënt per dag in Gegevens\Geprint\Bezig, exclusief
    ; aangemaakt (CREATE_NEW): zo kunnen twee computers (of twee rondes) nooit
    ; tegelijk dezelfde patiënt printen. Na afloop weer weg (GeefVrij). Blijft
    ; hij staan (app vastgelopen, of geprint maar niet in het register), dan
    ; slaan andere rondes deze patiënt die dag over.
    ; Geeft {ok}, {bezet: wie} of {fout: reden}.
    static ClaimMap := ""
    static Eigenaar => A_ComputerName " " A_UserName " " DllCall("GetCurrentProcessId")

    static ClaimBestand(Patnr) => this.ClaimMap "\" FormatTime(, "yyyy-MM-dd") " " Patnr ".txt"

    static Claim(Patnr) {
        if !InStr(FileExist(this.ClaimMap), "D") {
            try DirCreate this.ClaimMap
            if !InStr(FileExist(this.ClaimMap), "D")
                return {fout: "map " this.ClaimMap " niet bereikbaar"}
        }
        Bestand := this.ClaimBestand(Patnr)
        Fout := NieuwBestand(Bestand, this.Eigenaar " " A_Now)
        if Fout = 0
            return {ok: true}
        if Fout != 80 && Fout != 32   ; ERROR_FILE_EXISTS, ERROR_SHARING_VIOLATION (wordt net aangemaakt)
            return {fout: Fout = -1 ? "claim kon niet geschreven worden" : "Windows-fout " Fout}
        try Wie := Trim(FileRead(Bestand, "UTF-8"))
        catch
            Wie := ""
        ; Van deze app zelf (bijv. Doorgaan nadat vrijgeven mislukte): overnemen
        if Wie != "" && InStr(Wie, this.Eigenaar " ") = 1
            return {ok: true}
        Log("  claim van Pat.nr " Patnr " bestaat al: " Bestand " (" (Wie != "" ? Wie : "inhoud onbekend") ")")
        return {bezet: Wie != "" ? StrSplit(Wie, " ")[1] : "een andere computer"}
    }

    ; Claims van vandaag die niet van deze app zijn: Map Pat.nr -> computer.
    ; Een andere ronde is daar nu mee bezig, of de app liep daar vast (dan is
    ; het etiket misschien geprint maar niet geregistreerd). Niet bereikbaar =
    ; lege Map (het register zelf faalt dan al, zie LeesRegister).
    static Bezig() {
        Res := Map(), Mijn := this.Eigenaar " "
        try loop files this.ClaimMap "\" FormatTime(, "yyyy-MM-dd") " *.txt" {
            Patnr := RegExReplace(SubStr(A_LoopFileName, 12), "\.txt$")
            try Wie := Trim(FileRead(A_LoopFileFullPath, "UTF-8"))
            catch
                Wie := ""
            if Wie != "" && InStr(Wie, Mijn) = 1
                continue
            Res[Patnr] := Wie != "" ? StrSplit(Wie, " ")[1] : "een andere computer"
        }
        return Res
    }

    ; Alleen een eigen claim weghalen
    static GeefVrij(Patnr) {
        Bestand := this.ClaimBestand(Patnr)
        try Wie := FileRead(Bestand, "UTF-8")
        catch
            return
        if InStr(Trim(Wie), this.Eigenaar " ") = 1
            try FileDelete Bestand
    }

    ; --- Rapport per ronde (CSV, opent in Excel)
    static StartRapport(Proef := false) {
        this.RapportBestand := this.RapportMap "\" (Proef ? "Proefronde " : "Rapport ") FormatTime(, "yyyy-MM-dd HH.mm.ss") ".csv"
        try FileAppend "Tijd;Pat.nr;Pati" Teken.EUml "nt;Geboortedatum;Apotheek;Etiket;Status`r`n", this.RapportBestand, "UTF-8"
    }

    static Rapporteer(p, Etiket, Status, Apotheek) {
        if this.RapportBestand = ""
            return
        Regel := ""
        for v in [FormatTime(, "HH:mm:ss"), p.patnr, p.naam, p.gebdatum, Apotheek, Etiket, Status]
            Regel .= (A_Index > 1 ? ";" : "") '"' StrReplace(v, '"', '""') '"'
        try FileAppend Regel "`r`n", this.RapportBestand, "UTF-8"
    }
}

; =====================================================================
; Toestand per computer: Gegevens\Computers\<computer>.ini in de gedeelde
; map. Wat vaak verandert (planning gedraaid/status, laatst bekende
; apotheek, versie) staat hier en niet in de gedeelde ini: een ini wordt bij
; elke wijziging helemaal herschreven, dus twee computers die tegelijk
; schrijven = een wijziging kwijt. In dit bestand schrijft alleen de
; computer zelf; lezen mag iedereen (overzicht van de computers).
;
; Oud (tot v6.8): in de gedeelde ini met de computernaam in de sleutel.
; Lees() valt daarop terug, zodat er niets verloren gaat.
; =====================================================================
class Staat {
    static Dir := ""

    static Bestand(Computer := "") => this.Dir "\" (Computer != "" ? Computer : A_ComputerName) ".ini"

    ; OudSectie/OudSleutel: waar het tot v6.8 in de gedeelde ini stond
    static Lees(Sectie, Sleutel, Standaard := "", Computer := "", OudSectie := "", OudSleutel := "") {
        try v := IniRead(this.Bestand(Computer), Sectie, Sleutel, "")
        catch
            v := ""
        if v = "" && OudSleutel != ""
            v := Inst.Lees1(OudSectie != "" ? OudSectie : Sectie, OudSleutel, "")
        return v != "" ? v : Standaard
    }

    static Schrijf(Waarde, Sectie, Sleutel) {
        try IniWrite Waarde, this.Bestand(), Sectie, Sleutel
    }

    static Wis(Sectie, Sleutel) {
        try IniDelete this.Bestand(), Sectie, Sleutel
    }

    ; Bij het starten en elk uur: wie ben ik, welke versie, waar vandaan
    static Meld(Bij := false) {
        if !Bij {
            this.Schrijf(AppVersie, "App", "Versie")
            this.Schrijf(A_Now, "App", "Gestart")
            this.Schrijf(A_ScriptFullPath, "App", "Pad")
            this.Schrijf(Update.OpNetwerk() ? "netwerkmap" : "lokaal", "App", "Soort")
        }
        this.Schrijf(A_Now, "App", "Gezien")
    }

    ; Alle computers (voor het overzicht in Instellingen), nieuwste eerst
    static Computers() {
        Res := []
        loop files this.Dir "\*.ini" {
            Naam := SubStr(A_LoopFileName, 1, -4)
            Lees := (k) => this.Lees("App", k, "", Naam)
            Res.Push({naam: Naam, versie: Lees("Versie"), gezien: Lees("Gezien"), soort: Lees("Soort")
                , apotheek: Lees("Apotheek"), hier: Naam = A_ComputerName ? 1 : 0})
        }
        ; Sorteren op laatst gezien (nieuwste eerst)
        loop Res.Length - 1 {
            loop Res.Length - A_Index {
                k := A_Index
                if StrCompare(Res[k].gezien, Res[k + 1].gezien) < 0
                    Tmp := Res[k], Res[k] := Res[k + 1], Res[k + 1] := Tmp
            }
        }
        return Res
    }
}
