; =====================================================================
; Beslisregels zonder Pharmacom, venster of bestanden: welke patiënt mag
; geprint worden, welke regel wordt gekozen, klopt het dossier, staat de
; medicatiehistorie op datum. Alles hier is los te testen (tests\Regels.ahk);
; de rest van de app leest Pharmacom uit en voert de stappen uit.
; =====================================================================

class Regels {
    ; Waarde in Herhaal info waarop gefilterd wordt (als die optie aan staat)
    static DeelbaarPatroon := "i)^ASB:\s*Deelbaar"

    ; Soort van een patiënt in de lijst. Geprint = Map Pat.nr -> tijd (register
    ; van vandaag), Bezig = Map Pat.nr -> wie (claims van anderen). Geeft
    ; [soort, tekst]; tekst "" = de gewone tekst voor die soort.
    ;   print = te printen, al = vandaag al geprint, ontslag, controle
    static Soort(Patnr, Ontslag, Geprint, Bezig) {
        if Patnr = ""
            return ["controle", "Controleren: geen Pat.nr gelezen"]
        if Ontslag != "" && IsDatum(Ontslag)
            return ["ontslag", ""]
        if Ontslag != ""
            return ["controle", "Onbekende waarde bij ontslagdatum"]
        if Geprint.Has(Patnr)
            return ["al", "Vandaag al geprint om " Geprint[Patnr]]
        if Bezig.Has(Patnr)
            return ["controle", "Staat op 'bezig' bij " Bezig[Patnr] ": controleer of er een etiket is"]
        return ["print", ""]
    }

    ; Bovenste regel (0-based) met Ap = Apotheek en, als Deelbaar, Herhaal
    ; info "ASB: Deelbaar"; -1 als er geen is. Cel(r, sleutel) geeft de tekst
    ; van een cel ("ap", "herhaal"); zo worden alleen de nodige cellen gelezen.
    static KiesRegel(Aantal, Cel, Apotheek, Deelbaar) {
        loop Aantal {
            r := A_Index - 1
            if Cel(r, "ap") != Apotheek
                continue
            if Deelbaar && !RegExMatch(Cel(r, "herhaal"), this.DeelbaarPatroon)
                continue
            return r
        }
        return -1
    }

    ; Staat het Pat.nr in het dossier? Teksten = de teksten van het
    ; dossiervenster (titel, labels, velden) in volgorde. Geeft
    ;   los:  het Pat.nr staat ergens (als los getal) in een van de teksten
    ;   veld: het staat in het Pat.nr-veld: één tekst "Pat.nr: 123", of een
    ;         label "Pat.nr" met direct daarna een tekst "123"
    static DossierPatnr(Teksten, Patnr) {
        Res := {los: false, veld: false}
        if Patnr = ""
            return Res
        Label := "i)^\s*Pat(i\S{1,2}nt)?\.?\s*-?\s*nr\.?\s*[:.]?\s*"
        Vorige := ""
        for t in Teksten {
            t := Trim(t, " `t`r`n" Chr(160))
            if t = ""
                continue
            if RegExMatch(t, "(?<!\d)\Q" Patnr "\E(?!\d)")
                Res.los := true
            if RegExMatch(t, Label "0*\Q" Patnr "\E$")
                || (RegExMatch(Vorige, Label "$") && RegExMatch(t, "^0*\Q" Patnr "\E$"))
                Res.veld := true
            Vorige := t
        }
        return Res
    }

    ; Datum (25-08-1963, 5-8-63, 1963-08-25, ook met / of .) als getal
    ; yyyyMMdd, of "" als het geen datum is. Twee cijfers voor het jaar: tot
    ; en met dit jaar = 20xx, anders 19xx.
    static DatumGetal(v) {
        v := Trim(v)
        ; (Let op: AutoHotkey kent geen verschil tussen hoofd- en kleine
        ; letters in namen, dus geen "m" naast de match "M".)
        if RegExMatch(v, "^(\d{4})-(\d{1,2})-(\d{1,2})$", &D)
            Jaar := D[1], Maand := D[2], Dag := D[3]
        else if RegExMatch(v, "^(\d{1,2})[-/.](\d{1,2})[-/.](\d{2}|\d{4})$", &D) {
            Dag := D[1], Maand := D[2], Jaar := D[3]
            if StrLen(Jaar) = 2
                Jaar := (Integer(Jaar) <= Integer(SubStr(A_YYYY, 3)) ? "20" : "19") Jaar
        } else
            return ""
        if Maand < 1 || Maand > 12 || Dag < 1 || Dag > 31
            return ""
        return Format("{:04}{:02}{:02}", Jaar, Maand, Dag)
    }

    ; Staan de datums aflopend (nieuwste bovenaan)? Lege of onleesbare datums
    ; tellen niet mee. Geeft "" of wat er niet klopt.
    static Aflopend(Datums) {
        Vorige := "", VorigeRij := 0
        for i, v in Datums {
            g := this.DatumGetal(v)
            if g = ""
                continue
            if Vorige != "" && g > Vorige
                return "regel " i " (" v ") is nieuwer dan regel " VorigeRij " (" Datums[VorigeRij] ")"
            Vorige := g, VorigeRij := i
        }
        return ""
    }
}
