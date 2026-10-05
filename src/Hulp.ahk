; =====================================================================
; Algemene hulpfuncties (zonder toestand)
; =====================================================================

; Tekens via Chr, zodat ze ook in de .exe altijd goed zijn
class Teken {
    static EUml := Chr(235), Mid := Chr(0xB7), PlusMin := Chr(0xB1)
    static Ellips := Chr(0x2026), Pijl := Chr(0x2192), Punt := Chr(8226), IUml := Chr(239)
}

; JSON van een waarde. Alle waarden worden tekst (zoals de pagina verwacht);
; Array -> [..], Map/object -> {..}.
Json(v) {
    if IsObject(v) {
        s := ""
        if v is Array {
            for x in v
                s .= (A_Index > 1 ? "," : "") Json(x ?? "")
            return "[" s "]"
        }
        for k, x in (v is Map ? v : v.OwnProps())
            s .= (s = "" ? "" : ",") Json(String(k)) ":" Json(x)
        return "{" s "}"
    }
    v := StrReplace(String(v), "\", "\\")
    v := StrReplace(v, '"', '\"')
    v := StrReplace(v, "`r", "\r")
    v := StrReplace(v, "`n", "\n")
    v := StrReplace(v, "`t", "\t")
    v := StrReplace(v, Chr(0x2028), " ")
    v := StrReplace(v, Chr(0x2029), " ")
    return '"' v '"'
}

; Datum in de vorm 25-08-1963, 25/08/1963, 25.08.1963, 5-8-63 of 1963-08-25
IsDatum(v) => RegExMatch(v, "^(\d{1,2}[-/.]\d{1,2}[-/.](\d{2}|\d{4})|\d{4}-\d{2}-\d{2})$") > 0

FmtTijd(Sec) => (Sec // 60) ":" Format("{:02}", Mod(Sec, 60))

; "5.7.1" -> 5007001 (om versies te vergelijken); ontbrekende delen = 0
VersieNummer(V) {
    N := 0
    D := StrSplit(V, ".")
    loop 3
        N := N * 1000 + (D.Has(A_Index) && IsInteger(D[A_Index]) ? Integer(D[A_Index]) : 0)
    return N
}

; Decodeert %XX-codering (UTF-8) uit de pagina
UriDecode(S) {
    S := StrReplace(S, "+", " ")
    Buf := Buffer(StrPut(S, "UTF-8") + 8, 0)
    n := 0, i := 1
    while i <= StrLen(S) {
        c := SubStr(S, i, 1)
        if c = "%" && RegExMatch(SubStr(S, i + 1, 2), "^[0-9A-Fa-f]{2}$") {
            NumPut("UChar", Integer("0x" SubStr(S, i + 1, 2)), Buf, n++)
            i += 3
        } else {
            n += StrPut(c, Buf.Ptr + n, "UTF-8") - 1
            i += 1
        }
    }
    return StrGet(Buf, n, "UTF-8")
}

; Toont het hoofdvenster van Pharmacom de aanschrijfbuffer? ("Pharmacom -
; Aanschrijfbuffer"). Zonder schermnaam in de titel: aannemen van wel.
TitelIsBuffer(Titel) => !RegExMatch(Titel, "^Pharmacom\s+-\s+\S") || InStr(Titel, "Aanschrijfbuffer") > 0

; --- Foutcodes ------------------------------------------------------------
; Vaste code per soort fout, zodat een melding, het log, het rapport en de
; planningstatus makkelijk terug te vinden en te tellen zijn (lijst ook in
; LEESMIJ.md). De eerste regel die past telt. Codes nooit hergebruiken.
FoutCode(Tekst) {
    static Lijst := [
        ["i)^gestopt door gebruiker", "G01"]
        , ["i)Pharmacom is afgesloten", "P01"]
        , ["i)^Pharmacom (was niet (meer )?het actieve venster|kon niet naar voren)", "P02"]
        , ["i)dossier was niet meer het actieve venster", "P03"]
        , ["i)aanschrijfbuffer (is niet zichtbaar|ging niet open|is niet gevonden)|niet op de aanschrijfbuffer", "P04"]
        , ["i)kon niet geselecteerd worden in de aanschrijfbuffer", "P05"]
        , ["i)ntdossier verscheen niet", "P06"]
        , ["i)medicatiehistorie (werd niet herkend|bleef veranderen)", "P07"]
        , ["i)kon niet bevestigen dat het geopende dossier", "P08"]
        , ["i)^de regel met .* kon niet geselecteerd", "P09"]
        , ["i)afdrukmenu|kon niet gekozen worden", "P10"]
        , ["i)keerde (na het printen )?niet terug naar de aanschrijfbuffer", "P11"]
        , ["i)^(het veld|de velden|Pharmacom (kent|accepteerde))", "L01"]
        , ["i)knop Zoeken|zoeken in Pharmacom duurde", "L02"]
        , ["i)lijst bevat ook", "L03"]
        , ["i)computer is vergrendeld", "L04"]
        , ["i)Pharmacom is niet (open|bereikbaar)|geen verbinding met Pharmacom", "L05"]
        , ["i)melding of venster open", "L06"]
        , ["i)niemand ingelogd", "L07"]
        , ["i)apotheek .* ingelogd", "L08"]
        , ["i)kon niet gecontroleerd worden", "L09"]
        , ["i)^niet gestart binnen", "L10"]
        , ["i)er loopt (nog|al) een ronde", "L11"]
        , ["i)hoort bij instelling|is niet bekend bij instelling|^instelling .* is niet bekend", "L12"]
        , ["i)onverwachte fout|onbekende fout", "X99"]]
    for f in Lijst
        if RegExMatch(Tekst, f[1])
            return f[2]
    return ""
}

; Korte omschrijving van een foutcode (voor het overzicht in Diagnose)
FoutOmschrijving(Code) {
    static M := Map("G01", "gestopt door gebruiker", "P01", "Pharmacom afgesloten", "P02", "Pharmacom niet actief"
        , "P03", "dossier niet actief", "P04", "aanschrijfbuffer niet zichtbaar", "P05", "patiënt niet te selecteren"
        , "P06", "dossier verscheen niet", "P07", "medicatiehistorie", "P08", "dossier niet bevestigd"
        , "P09", "regel niet te selecteren", "P10", "afdrukmenu", "P11", "niet terug naar de aanschrijfbuffer"
        , "L01", "veld Instelling/Afdeling", "L02", "zoeken", "L03", "andere afdeling in de lijst"
        , "L04", "computer vergrendeld", "L05", "Pharmacom niet open", "L06", "melding open in Pharmacom"
        , "L07", "niemand ingelogd", "L08", "andere apotheek ingelogd", "L09", "Pharmacom niet te controleren"
        , "L10", "niet gestart binnen 2 uur", "L11", "er liep al een ronde", "L12", "planning klopt niet"
        , "X99", "onverwachte fout")
    return M.Has(Code) ? M[Code] : ""
}

; Telt in logregels: afgeronde rondes en foutcodes (één per regel).
; Geeft {klaar, codes: Map code -> aantal}.
TelLogregels(Regels) {
    Res := {klaar: 0, codes: Map()}
    for r in Regels {
        ; Alleen echte logregels (met tijd); niet de regels van een diagnose
        ; die zelf in het log staat
        if !RegExMatch(r, "^\d\d:\d\d:\d\d\.\d+ - ")
            continue
        if RegExMatch(r, "^\S+ - (Ronde|Proefronde|Geplande ronde '.*') klaar: ")
            Res.klaar++
        if RegExMatch(r, "\[([GPLX]\d\d)\]", &M)
            Res.codes[M[1]] := (Res.codes.Has(M[1]) ? Res.codes[M[1]] : 0) + 1
    }
    return Res
}

; Tekst met de foutcode erachter ("... [P11]"), als er een past
MetCode(Tekst) {
    c := FoutCode(Tekst)
    return c = "" || InStr(Tekst, "[" c "]") ? Tekst : Tekst " [" c "]"
}

; Codeert tekst voor in een URL (UTF-8, %XX)
UriEncode(S) {
    Buf := Buffer(StrPut(S, "UTF-8"))
    n := StrPut(S, Buf, "UTF-8") - 1
    Uit := ""
    loop n {
        c := NumGet(Buf, A_Index - 1, "UChar")
        Uit .= (c >= 0x30 && c <= 0x39) || (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || c = 0x2D || c = 0x2E || c = 0x5F || c = 0x7E
            ? Chr(c) : Format("%{:02X}", c)
    }
    return Uit
}

; Base64 van een Buffer (zonder regeleinden)
Base64(Buf) {
    static Vlaggen := 0x40000001   ; CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF
    n := 0
    DllCall("crypt32\CryptBinaryToStringW", "Ptr", Buf, "UInt", Buf.Size, "UInt", Vlaggen, "Ptr", 0, "UInt*", &n)
    Uit := Buffer(n * 2)
    DllCall("crypt32\CryptBinaryToStringW", "Ptr", Buf, "UInt", Buf.Size, "UInt", Vlaggen, "Ptr", Uit, "UInt*", &n)
    return StrGet(Uit, n, "UTF-16")
}

; Verwijdert bestanden (Patroon, bijv. "map\*.txt") die langer dan Dagen
; dagen niet gewijzigd zijn. Een ongeldige of te kleine waarde doet niets.
Opruimen(Patroon, Dagen) {
    if !IsInteger(Dagen) || Dagen < 1
        return
    loop files Patroon {
        if DateDiff(A_Now, A_LoopFileTimeModified, "Days") > Dagen
            try FileDelete A_LoopFileFullPath
    }
}

; SHA-256 van een bestand (kleine letters), of "" bij een fout.
Sha256(Bestand) {
    static PROV_RSA_AES := 24, CALG_SHA_256 := 0x800C, CRYPT_VERIFYCONTEXT := 0xF0000000
    try f := FileOpen(Bestand, "r")
    catch
        return ""
    if !f
        return ""
    hProv := 0, hHash := 0, Uit := ""
    if DllCall("advapi32\CryptAcquireContext", "Ptr*", &hProv, "Ptr", 0, "Ptr", 0, "UInt", PROV_RSA_AES, "UInt", CRYPT_VERIFYCONTEXT) {
        if DllCall("advapi32\CryptCreateHash", "Ptr", hProv, "UInt", CALG_SHA_256, "Ptr", 0, "UInt", 0, "Ptr*", &hHash) {
            Buf := Buffer(65536)
            Ok := true
            while Ok && !f.AtEOF {
                n := f.RawRead(Buf, Buf.Size)
                Ok := DllCall("advapi32\CryptHashData", "Ptr", hHash, "Ptr", Buf, "UInt", n, "UInt", 0)
            }
            Lengte := 32
            H := Buffer(32, 0)
            if Ok && DllCall("advapi32\CryptGetHashParam", "Ptr", hHash, "UInt", 2, "Ptr", H, "UInt*", &Lengte, "UInt", 0)
                loop 32
                    Uit .= Format("{:02x}", NumGet(H, A_Index - 1, "UChar"))
            DllCall("advapi32\CryptDestroyHash", "Ptr", hHash)
        }
        DllCall("advapi32\CryptReleaseContext", "Ptr", hProv, "UInt", 0)
    }
    f.Close()
    return Uit
}
