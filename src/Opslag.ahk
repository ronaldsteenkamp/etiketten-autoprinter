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
        Staat.Dir := DataMap "\Gegevens\Computers"
        for m in [this.GeprintMap, this.RapportMap, this.LogMap, Staat.Dir]
            try DirCreate m
        ; Bewaartermijnen: rapporten bevatten naam en geboortedatum (AVG), het
        ; register alleen Pat.nr's en is na de dag zelf niet meer nodig.
        Opruimen(this.LogMap "\*.txt", 30)
        Opruimen(this.RapportMap "\Rapport *.csv", Inst.RapportDagen)
        Opruimen(this.RapportMap "\Proefronde *.csv", Inst.RapportDagen)
        Opruimen(this.GeprintMap "\*.txt", Inst.RegisterDagen)
        try FileDelete A_ScriptDir "\Gegevens\Etiketten_autoprinter_log.txt"   ; oud log (v5.3-5.6)
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
    static RegisterBestand => this.GeprintMap "\" FormatTime(, "yyyy-MM-dd") ".txt"

    ; Map Pat.nr -> tijd (uu:mm)
    static LeesRegister() {
        Geprint := Map()
        try {
            loop read this.RegisterBestand {
                Delen := StrSplit(A_LoopReadLine, ";")
                if Delen.Length >= 2 && Delen[2] != ""
                    Geprint[Delen[2]] := SubStr(Delen[1], 1, 5)
            }
        }
        return Geprint
    }

    ; Geeft de tijd (uu:mm) terug
    static Registreer(Patnr) {
        Tijd := FormatTime(, "HH:mm:ss")
        try FileAppend Tijd ";" Patnr "`n", this.RegisterBestand, "UTF-8-RAW"
        return SubStr(Tijd, 1, 5)
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
