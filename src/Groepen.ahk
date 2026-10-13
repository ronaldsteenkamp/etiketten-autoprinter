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
