; =====================================================================
; Java Access Bridge (JAB): Pharmacom uitlezen en bedienen.
;
; Laadt de bridge-DLL uit de Java-map van Pharmacom. Java-objecten die de
; bridge teruggeeft moeten weer vrijgegeven worden; JabTabel doet dat zelf
; (in __Delete), de zoekfuncties geven alles vrij wat ze niet teruggeven.
; =====================================================================

class Jab {
    static f := ""            ; Map functienaam -> adres ("" = niet gekoppeld)
    static jt := "Int64"      ; type van een Java-object (Int64 bij de -32 dll)
    static js := 8            ; grootte daarvan in bytes
    static dll := ""
    static geladen := Map()

    static Functies := ["Windows_run", "isJavaWindow", "getAccessibleContextFromHWND"
        , "getAccessibleContextInfo", "getAccessibleChildFromContext", "releaseJavaObject"
        , "getAccessibleTableInfo", "getAccessibleTableCellInfo", "getAccessibleTableColumnHeader"
        , "getAccessibleTableColumnDescription", "getAccessibleTableRowSelectionCount"
        , "getAccessibleTableRowSelections", "getAccessibleTextInfo", "getAccessibleTextRange"
        , "getAccessibleKeyBindings", "addAccessibleSelectionFromContext"
        , "clearAccessibleSelectionFromContext"]

    ; Eerst de moderne (-32) variant, dan de oude. True als Hwnd bereikbaar is.
    static Koppel(Hwnd, JreMap) {
        if this.f && this.IsJava(Hwnd)
            return true
        for i, Dll in ["WindowsAccessBridge-32.dll", "WindowsAccessBridge.dll"] {
            if !this.geladen.Has(Dll) {
                Pad := JreMap "\" Dll
                if !FileExist(Pad)
                    continue
                h := DllCall("LoadLibrary", "Str", Pad, "Ptr")
                if !h
                    continue
                v := {naam: Dll, js: i = 1 ? 8 : 4, jt: i = 1 ? "Int64" : "Ptr", f: Map()}
                for Fn in this.Functies
                    v.f[Fn] := DllCall("GetProcAddress", "Ptr", h, "AStr", Fn, "Ptr")
                this.geladen[Dll] := v
                if !v.f["Windows_run"] || !v.f["isJavaWindow"]
                    continue
                DllCall(v.f["Windows_run"], "Cdecl")
                Sleep 700   ; de bridge meldt zich via berichten bij Java
            }
            v := this.geladen[Dll]
            if !v.f["isJavaWindow"]
                continue
            loop 3 {
                if DllCall(v.f["isJavaWindow"], "Ptr", Hwnd, "Cdecl Int") {
                    this.f := v.f, this.js := v.js, this.jt := v.jt, this.dll := Dll
                    return true
                }
                Sleep 100
            }
        }
        return false
    }

    static IsJava(Hwnd) => this.f ? DllCall(this.f["isJavaWindow"], "Ptr", Hwnd, "Cdecl Int") : 0

    ; {vm, ac} van het hoofdelement van een venster, of "" (ac zelf vrijgeven)
    static VanVenster(Hwnd) {
        if !this.IsJava(Hwnd)
            return ""
        Vm := 0, Ac := 0
        if !DllCall(this.f["getAccessibleContextFromHWND"], "Ptr", Hwnd, "Int*", &Vm, this.jt "*", &Ac, "Cdecl Int") || !Ac
            return ""
        return {vm: Vm, ac: Ac}
    }

    static Release(Vm, Obj) {
        if Obj && this.f
            DllCall(this.f["releaseJavaObject"], "Int", Vm, this.jt, Obj, "Cdecl")
    }

    static Kind(Vm, Ac, i) => DllCall(this.f["getAccessibleChildFromContext"], "Int", Vm, this.jt, Ac, "Int", i, "Cdecl " this.jt)

    static Info(Vm, Ac) {
        Buf := Buffer(6188, 0)
        if !DllCall(this.f["getAccessibleContextInfo"], "Int", Vm, this.jt, Ac, "Ptr", Buf, "Cdecl Int")
            return ""
        return {name: StrGet(Buf, "UTF-16")
            , role: StrGet(Buf.Ptr + 4608, "UTF-16")
            , states: StrGet(Buf.Ptr + 5632, "UTF-16")
            , children: NumGet(Buf, 6148, "Int")
            , x: NumGet(Buf, 6152, "Int"), y: NumGet(Buf, 6156, "Int")      ; schermcoördinaten
            , w: NumGet(Buf, 6160, "Int"), h: NumGet(Buf, 6164, "Int")
            , text: NumGet(Buf, 6180, "Int")}
    }

    static Heeft(Info, Toestand) => InStr("," Info.states ",", "," Toestand ",") > 0

    ; Naam (= zichtbare tekst) van een element; valt terug op de tekstinhoud.
    static Naam(Vm, Ac) {
        Info := this.Info(Vm, Ac)
        if !Info
            return ""
        if Trim(Info.name) != "" || !Info.text
            return Info.name
        Ti := Buffer(12, 0)
        if !DllCall(this.f["getAccessibleTextInfo"], "Int", Vm, this.jt, Ac, "Ptr", Ti, "Int", 0, "Int", 0, "Cdecl Int")
            return ""
        n := Min(NumGet(Ti, 0, "Int"), 1000)
        if n < 1
            return ""
        Tb := Buffer(2 * 1026, 0)
        if !DllCall(this.f["getAccessibleTextRange"], "Int", Vm, this.jt, Ac, "Int", 0, "Int", n - 1, "Ptr", Tb, "Short", 1025, "Cdecl Int")
            return ""
        return StrGet(Tb, "UTF-16")
    }

    ; Eerste sneltoets (letter/cijfer) van een element, of "".
    static Sneltoets(Vm, Ac) {
        if !this.f["getAccessibleKeyBindings"]
            return ""
        Kb := Buffer(4 + 10 * 8, 0)
        if !DllCall(this.f["getAccessibleKeyBindings"], "Int", Vm, this.jt, Ac, "Ptr", Kb, "Cdecl Int")
            || NumGet(Kb, 0, "Int") < 1
            return ""
        c := NumGet(Kb, 4, "UShort")
        return (c >= 0x30 && c <= 0x39) || (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) ? Chr(c) : ""
    }

    ; --- Doorzoeken van de boom -------------------------------------------
    ; Roept Bezoek(vm, ac, info, diepte) aan voor elk zichtbaar element in de
    ; Java-vensters van proces Pid. Bezoek geeft terug:
    ;   ""        verder zoeken (ook in de kinderen)
    ;   "stop"    niet in de kinderen van dit element zoeken
    ;   "houd"    dit element bewaren (niet vrijgeven) en niet verder in de kinderen
    ;   object    klaar: dit wordt teruggegeven (element is dan eigendom van het object)
    ; Max = maximaal aantal bezochte elementen per venster.
    static Doorzoek(Pid, Bezoek, Max := 5000) {
        if !this.f || !Pid
            return ""
        for Hwnd in WinGetList("ahk_pid " Pid) {
            R := this.VanVenster(Hwnd)
            if !R
                continue
            Teller := 0
            Res := this._Doorzoek(R.vm, R.ac, Bezoek, 0, &Teller, Max)
            if IsObject(Res) {
                if !Res.HasProp("ac") || Res.ac != R.ac
                    this.Release(R.vm, R.ac)
                return Res
            }
            if Res != "houd"
                this.Release(R.vm, R.ac)
        }
        return ""
    }

    ; Geeft object (gevonden), "houd" (element zelf bewaard) of "".
    static _Doorzoek(Vm, Ac, Bezoek, Diepte, &Teller, Max) {
        if ++Teller > Max
            return ""
        Info := this.Info(Vm, Ac)
        if !Info || !this.Heeft(Info, "showing")
            return ""
        Res := Bezoek(Vm, Ac, Info, Diepte)
        if IsObject(Res) || Res = "houd"
            return Res
        if Res = "stop" || Diepte > 60
            return ""
        loop Min(Info.children, 2000) {
            Kind := this.Kind(Vm, Ac, A_Index - 1)
            if !Kind
                continue
            R := this._Doorzoek(Vm, Kind, Bezoek, Diepte + 1, &Teller, Max)
            if IsObject(R) {
                ; Tussenliggende onderdelen vrijgeven; het gevonden object
                ; houdt zijn eigen verwijzing.
                if !R.HasProp("ac") || R.ac != Kind
                    this.Release(Vm, Kind)
                return R
            }
            if R != "houd"
                this.Release(Vm, Kind)
        }
        return ""
    }

    ; --- Tabellen ----------------------------------------------------------
    ; Zoekt een zichtbare tabel waarvan de kolomkoppen passen bij Koppen (Map
    ; sleutel -> reguliere expressie). Met Alle (een array) worden alle
    ; zichtbare tabellen verzameld (voor de diagnose).
    static ZoekTabel(Pid, Koppen, Alle := "") {
        Bezoek(Vm, Ac, Info, Diepte) {
            if Info.role = "table" {
                t := JabTabel.Maak(Vm, Ac, Koppen)
                if !t
                    return "stop"
                if IsObject(Alle) {
                    Alle.Push(t)
                    return "houd"
                }
                return t
            }
            if RegExMatch(Info.role, "^(menu bar|menu|popup menu|list|tree|combo box)$")
                return "stop"
            return ""
        }
        return this.Doorzoek(Pid, Bezoek)
    }

    static TabelInfo(Vm, Ac) {
        js := this.js, jt := this.jt
        Ti := Buffer(48, 0)
        if !DllCall(this.f["getAccessibleTableInfo"], "Int", Vm, jt, Ac, "Ptr", Ti, "Cdecl Int")
            return ""
        this.Release(Vm, NumGet(Ti, 0, jt))    ; caption
        this.Release(Vm, NumGet(Ti, js, jt))   ; summary
        return {rows: NumGet(Ti, 2 * js, "Int"), cols: NumGet(Ti, 2 * js + 4, "Int")
            , ac: NumGet(Ti, 2 * js + 8, jt), at: NumGet(Ti, 3 * js + 8, jt)}
    }

    static CelTekst(Vm, At, R, C) {
        Ci := Buffer(40, 0)
        if !DllCall(this.f["getAccessibleTableCellInfo"], "Int", Vm, this.jt, At, "Int", R, "Int", C, "Ptr", Ci, "Cdecl Int")
            return ""
        Cac := NumGet(Ci, 0, this.jt)
        if !Cac
            return ""
        T := this.Naam(Vm, Cac)
        this.Release(Vm, Cac)
        return T
    }

    ; Kolomkoppen van een tabel (array, 1-based)
    static Kolomkoppen(Vm, Tac, Cols) {
        js := this.js, jt := this.jt
        Koppen := []
        Koppen.Length := Cols
        Hi := Buffer(48, 0)
        if DllCall(this.f["getAccessibleTableColumnHeader"], "Int", Vm, jt, Tac, "Ptr", Hi, "Cdecl Int") {
            Hat := NumGet(Hi, 3 * js + 8, jt)
            if Hat
                loop Cols
                    Koppen[A_Index] := Trim(this.CelTekst(Vm, Hat, 0, A_Index - 1))
            this.Release(Vm, NumGet(Hi, 0, jt))
            this.Release(Vm, NumGet(Hi, js, jt))
            this.Release(Vm, NumGet(Hi, 2 * js + 8, jt))
            this.Release(Vm, Hat)
        }
        loop Cols {
            if Koppen.Has(A_Index) && Koppen[A_Index] != ""
                continue
            Dac := DllCall(this.f["getAccessibleTableColumnDescription"], "Int", Vm, jt, Tac, "Int", A_Index - 1, "Cdecl " jt)
            Koppen[A_Index] := Dac ? Trim(this.Naam(Vm, Dac)) : ""
            this.Release(Vm, Dac)
        }
        return Koppen
    }

    ; Geselecteerde regel (0-based) of -1
    static Geselecteerd(Vm, At) {
        n := DllCall(this.f["getAccessibleTableRowSelectionCount"], "Int", Vm, this.jt, At, "Cdecl Int")
        if n < 1
            return -1
        Sel := Buffer(4 * n, 0)
        if !DllCall(this.f["getAccessibleTableRowSelections"], "Int", Vm, this.jt, At, "Int", n, "Ptr", Sel, "Cdecl Int")
            return -1
        return NumGet(Sel, 0, "Int")
    }

    ; --- Overige zoekfuncties ----------------------------------------------
    ; Zichtbaar popupmenu met een item met deze naam: {aan, toets} of "".
    static ZoekMenuItem(Pid, Naam) {
        Bezoek(Vm, Ac, Info, Diepte) {
            if Info.role = "popup menu" {
                loop Min(Info.children, 100) {
                    Kind := Jab.Kind(Vm, Ac, A_Index - 1)
                    if !Kind
                        continue
                    Ki := Jab.Info(Vm, Kind)
                    R := ""
                    if Ki && Ki.role = "menu item" && Trim(Ki.name) = Naam
                        R := {aan: Jab.Heeft(Ki, "enabled"), toets: Jab.Sneltoets(Vm, Kind)}
                    Jab.Release(Vm, Kind)
                    if R
                        return R
                }
                return "stop"
            }
            if RegExMatch(Info.role, "^(table|menu bar|menu|list|tree|combo box)$")
                return "stop"
            return ""
        }
        return this.Doorzoek(Pid, Bezoek)
    }

    ; Eerste zichtbaar label waarvan de tekst past bij Patroon, of "".
    static ZoekLabel(Pid, Patroon) {
        Bezoek(Vm, Ac, Info, Diepte) {
            if Info.role = "label" && RegExMatch(Info.name, Patroon)
                return {tekst: Info.name}
            if RegExMatch(Info.role, "^(table|menu bar|menu|popup menu|list|tree|combo box)$")
                return "stop"
            return ""
        }
        R := this.Doorzoek(Pid, Bezoek)
        return R ? R.tekst : ""
    }

    ; Alle zichtbare teksten (labels, velden, titel) in een venster, zonder
    ; tabellen en menu's.
    static VensterTekst(Hwnd) {
        Tekst := WinGetTitle(Hwnd) "`n"
        R := this.VanVenster(Hwnd)
        if !R
            return Tekst
        Teller := 0
        this._Tekst(R.vm, R.ac, &Tekst, 0, &Teller)
        this.Release(R.vm, R.ac)
        return Tekst
    }

    static _Tekst(Vm, Ac, &Tekst, Diepte, &Teller) {
        if ++Teller > 4000
            return
        Info := this.Info(Vm, Ac)
        if !Info || !this.Heeft(Info, "showing")
            return
        if Info.role = "table" || Info.role = "menu bar" || Info.role = "popup menu"
            return
        Naam := Info.name
        if Trim(Naam) = "" && Info.text
            Naam := this.Naam(Vm, Ac)
        if Trim(Naam) != ""
            Tekst .= Naam "`n"
        if Diepte > 60
            return
        loop Min(Info.children, 2000) {
            Kind := this.Kind(Vm, Ac, A_Index - 1)
            if !Kind
                continue
            this._Tekst(Vm, Kind, &Tekst, Diepte + 1, &Teller)
            this.Release(Vm, Kind)
        }
    }
}

; Een gevonden tabel. Geeft zijn Java-objecten zelf vrij als hij niet meer
; gebruikt wordt.
class JabTabel {
    ; Tabel-object als de kolomkoppen passen, anders "" (Ac blijft dan van de
    ; aanroeper).
    static Maak(Vm, Ac, Koppen) {
        Ti := Jab.TabelInfo(Vm, Ac)
        if !Ti
            return ""
        Kop := Jab.Kolomkoppen(Vm, Ac, Ti.cols)
        Kol := JabTabel.PasKoppen(Kop, Koppen)
        if !Kol {
            Jab.Release(Vm, Ti.at)
            if Ti.ac != Ac
                Jab.Release(Vm, Ti.ac)
            return ""
        }
        return JabTabel(Vm, Ac, Ti, Kol, Kop)
    }

    ; Kolomnummers (0-based) bij de gezochte koppen, of "" als er een ontbreekt.
    static PasKoppen(Kop, Koppen) {
        Kol := Map()
        for Sleutel, Patroon in Koppen {
            Gevonden := 0
            for c, k in Kop {
                if RegExMatch(k, Patroon) {
                    Gevonden := c
                    break
                }
            }
            if !Gevonden
                return ""
            Kol[Sleutel] := Gevonden - 1
        }
        return Kol
    }

    __New(Vm, Ac, Ti, Kol, Kop) {
        this.vm := Vm, this.ac := Ac, this.at := Ti.at, this.tac := Ti.ac
        this.rows := Ti.rows, this.cols := Ti.cols, this.kol := Kol, this.koppen := Kop
    }

    __Delete() {
        Jab.Release(this.vm, this.at)
        if this.tac != this.ac
            Jab.Release(this.vm, this.tac)
        Jab.Release(this.vm, this.ac)
    }

    ; Tekst in een cel, zonder HTML-opmaak en witruimte
    Cel(R, Sleutel) {
        v := Jab.CelTekst(this.vm, this.at, R, this.kol[Sleutel])
        v := RegExReplace(v, "<[^>]*>")
        return Trim(v, " `t`r`n" Chr(160))
    }

    ; Actueel aantal regels (de tabel kan intussen veranderd zijn)
    Rijen() {
        Ti := Jab.TabelInfo(this.vm, this.ac)
        if !Ti
            return 0
        Jab.Release(this.vm, Ti.at)
        if Ti.ac != this.ac
            Jab.Release(this.vm, Ti.ac)
        return Ti.rows
    }

    Geselecteerd() => Jab.Geselecteerd(this.vm, this.at)

    ; Selecteert regel R direct via de koppeling (zoals een klik). Geeft true
    ; als de selectie daarna op R staat.
    Selecteer(R) {
        if !Jab.f["addAccessibleSelectionFromContext"] || !Jab.f["clearAccessibleSelectionFromContext"]
            return false
        DllCall(Jab.f["clearAccessibleSelectionFromContext"], "Int", this.vm, Jab.jt, this.ac, "Cdecl")
        DllCall(Jab.f["addAccessibleSelectionFromContext"], "Int", this.vm, Jab.jt, this.ac, "Int", R * this.cols, "Cdecl")
        return this.Geselecteerd() = R
    }

    ; Korte samenvatting van de bovenste regels, om te zien of de tabel klaar
    ; is met laden.
    Momentopname(Sleutels*) {
        n := this.Rijen()
        s := n ":"
        loop Min(n, 12) {
            r := A_Index - 1
            for k in Sleutels
                s .= this.Cel(r, k) "|"
            s .= ";"
        }
        return s
    }
}
