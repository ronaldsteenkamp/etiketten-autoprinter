; =====================================================================
; Opslag: logbestand, register van geprinte pati"enten, rapporten
;
; Register en rapporten staan in de gedeelde map (Inst.DataMap; bij een
; lokale installatie de netwerkmap waar hij vandaan kwam). Is die niet
; bereikbaar, dan naast de app. Het log staat altijd naast de app (een per
; dag, per computer) en bevat alleen Pat.nr's.
; =====================================================================

Log(Msg) => Opslag.Log(Msg)

class Opslag {
    static GeprintMap := "", RapportMap := "", LogMap := ""
    static RapportBestand := ""

    static Init() {
        DataMap := Inst.DataMap
        if !InStr(FileExist(DataMap), "D")
            DataMap := A_ScriptDir
        this.GeprintMap := DataMap "\Gegevens\Geprint"
        this.RapportMap := DataMap "\Rapporten"
        this.LogMap := A_ScriptDir "\Gegevens\Log"
        for m in [this.GeprintMap, this.RapportMap, this.LogMap]
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
