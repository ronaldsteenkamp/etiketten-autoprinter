; =====================================================================
; Instellingen (Etiketten_autoprinter.ini naast de app)
; =====================================================================

class Inst {
    static Bestand := A_ScriptDir "\Etiketten_autoprinter.ini"

    ; Wachttijden: [naam, standaard (ms), omschrijving]. De app wacht zelf tot
    ; een scherm er echt is; dit zijn alleen de korte pauzes daarna.
    static Wachttijden := [["SleepNaCtrlB", 50, "Nadat het dossier verscheen"]
        , ["SleepNaF4", 100, "Nadat de medicatiehistorie verscheen"]
        , ["SleepNaOmhoog", 100, "Na pijl omhoog"]
        , ["SleepNaScherm", 100, "Nadat de aanschrijfbuffer terug is"]
        , ["SleepNavigatie", 50, "Na het selecteren van een regel"]
        , ["SleepNaCtrlP", 25, "Na Ctrl+P (afdrukmenu)"]
        , ["MaxWachtPrint", 3000, "Maximaal wachten op het afdrukmenu"]
        , ["SleepNaAltB", 25, "Na het kiezen in het afdrukmenu"]
        , ["SleepNaEscape", 100, "Na Escape"]
        , ["MaxWachtScherm", 10000, "Maximaal wachten op een scherm"]
        , ["MaxWachtLeeg", 4000, "Maximaal wachten op een lege medicatiehistorie"]]

    ; Ondergrenzen: te kort wachten op het afdrukmenu is onveilig (te vroeg
    ; opgeven = niet geprint). Het wachten stopt zodra het menu er is.
    static Minimum := Map("MaxWachtPrint", 1000)

    ; Opties: naam in de pagina -> sleutel in de ini (standaard allemaal aan)
    static OptieSleutels := Map("deelbaar", "AlleenDeelbaar", "controle", "DossierControleren"
        , "patnr", "DossierAlleenPatnr", "blokkeer", "InvoerBlokkeren", "bevestigen", "Bevestigen"
        , "bovenop", "Bovenop", "geluid", "Geluid")

    static Wt := Map()
    static Opties := Map()
    static PrintMenu := "Barcode etiket"
    static UpdateMap := ""
    static DataMap := ""
    static RapportDagen := 90
    static RegisterDagen := 7

    static Lees() {
        ; Instellingen van voor v5.1 golden voor vaste wachttijden; die worden
        ; (behalve de printinstellingen) teruggezet naar de standaard.
        if this.Getal(this.Lees1("Wachttijden", "Versie", 1), 1) < 2 {
            for k in ["SleepNaCtrlB", "SleepNaF4", "SleepNaOmhoog", "SleepNaScherm", "SleepNavigatie", "SleepNaEscape", "MaxWachtScherm"]
                try IniDelete this.Bestand, "Wachttijden", k
            this.Schrijf(2, "Wachttijden", "Versie")
        }
        for w in this.Wachttijden {
            k := w[1], d := w[2]
            v := this.Getal(this.Lees1("Wachttijden", k, d), d)
            if this.Minimum.Has(k) && v < this.Minimum[k] {
                v := d
                this.Schrijf(v, "Wachttijden", k)
            }
            this.Wt[k] := v
        }
        for Naam, Sleutel in this.OptieSleutels
            this.Opties[Naam] := this.Getal(this.Lees1("Opties", Sleutel, 1), 1) ? 1 : 0
        ; Item in het afdrukmenu (Ctrl+P in het dossier); de sneltoets leest de
        ; app uit Pharmacom (Barcode etiket = Alt+B).
        this.PrintMenu := Trim(this.Lees1("Opties", "PrintMenu", "Barcode etiket"))
        this.UpdateMap := Trim(this.Lees1("Update", "Map", ""))
        this.DataMap := Trim(this.Lees1("Opslag", "Map", A_ScriptDir))
        this.RapportDagen := this.Getal(this.Lees1("Opslag", "RapportDagen", 90), 90)
        this.RegisterDagen := this.Getal(this.Lees1("Opslag", "RegisterDagen", 7), 7)
    }

    static Lees1(Sectie, Sleutel, Standaard) {
        try return IniRead(this.Bestand, Sectie, Sleutel, Standaard)
        return Standaard
    }

    static Schrijf(Waarde, Sectie, Sleutel) {
        try IniWrite Waarde, this.Bestand, Sectie, Sleutel
    }

    static Getal(v, Standaard) => IsInteger(v) ? Integer(v) : Standaard

    ; --- Per apotheek ----------------------------------------------------------
    ; Deze opties (en het afdrukmenu-item) gelden per ingelogde apotheek, in de
    ; ini-sectie [Opties <code>], bijv. [Opties AN]. Staat daar niets, dan
    ; geldt de algemene waarde uit [Opties]. De overige opties horen bij de
    ; computer (geluid, venster bovenop, toetsenbord blokkeren, bevestigen).
    static PerApotheek := ["deelbaar", "controle", "patnr"]
    static Apotheek := ""
    static ApOpties := Map()
    static ApPrintMenu := ""

    static ZetApotheek(Ap) {
        if Ap = this.Apotheek
            return
        this.Apotheek := Ap
        this.ApOpties := Map(), this.ApPrintMenu := ""
        if Ap = ""
            return
        for Naam in this.PerApotheek {
            v := this.Lees1("Opties " Ap, this.OptieSleutels[Naam], "")
            if IsInteger(v)
                this.ApOpties[Naam] := Integer(v) ? 1 : 0
        }
        this.ApPrintMenu := Trim(this.Lees1("Opties " Ap, "PrintMenu", ""))
    }

    static IsPerApotheek(Naam) {
        for n in this.PerApotheek
            if n = Naam
                return true
        return false
    }

    ; Item in het afdrukmenu voor de huidige apotheek
    static PrintItem => this.ApPrintMenu != "" ? this.ApPrintMenu : this.PrintMenu

    static ZetPrintItem(Tekst) {
        Tekst := Trim(Tekst)
        if Tekst = ""
            return
        if this.Apotheek != "" {
            this.ApPrintMenu := Tekst
            this.Schrijf(Tekst, "Opties " this.Apotheek, "PrintMenu")
        } else {
            this.PrintMenu := Tekst
            this.Schrijf(Tekst, "Opties", "PrintMenu")
        }
    }

    static Optie(Naam) => this.ApOpties.Has(Naam) ? this.ApOpties[Naam] : this.Opties.Has(Naam) ? this.Opties[Naam] : 1

    static ZetOptie(Naam, Aan) {
        if !this.OptieSleutels.Has(Naam)
            return
        Aan := Aan ? 1 : 0
        if this.Apotheek != "" && this.IsPerApotheek(Naam) {
            this.ApOpties[Naam] := Aan
            this.Schrijf(Aan, "Opties " this.Apotheek, this.OptieSleutels[Naam])
        } else {
            this.Opties[Naam] := Aan
            this.Schrijf(Aan, "Opties", this.OptieSleutels[Naam])
        }
    }

    ; Geeft de opgeslagen waarde terug (na de ondergrens), of "" als ongeldig
    static ZetWachttijd(k, v) {
        if !IsInteger(v)
            return ""
        v := Integer(v)
        if this.Minimum.Has(k) && v < this.Minimum[k]
            v := this.Minimum[k]
        this.Wt[k] := v
        this.Schrijf(v, "Wachttijden", k)
        return v
    }
}
