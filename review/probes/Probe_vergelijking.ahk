#Requires AutoHotkey v2.0
Uit := A_ScriptDir "\probe2_uitvoer.txt"
try FileDelete Uit
P(Naam, Waarde) => FileAppend(Naam " => " Waarde "`n", Uit, "UTF-8")
; Waarden zoals ze uit de koppeling komen: via StrGet uit een buffer (zoals Jab.CelTekst/Naam)
Uitbuf(s) {
    b := Buffer(StrPut(s, "UTF-16"))
    StrPut(s, b, "UTF-16")
    return StrGet(b, "UTF-16")
}
Trimmed(s) => Trim(RegExReplace(Uitbuf(s), "<[^>]*>"), " `t`r`n" Chr(160))   ; zoals JabTabel.Cel
a := Trimmed("0123"), b := Trimmed("123")
P("Cel '0123' = Cel '123'", a = b)
P("Cel '123' = Cel '123.0'", Trimmed("123") = Trimmed("123.0"))
P("Cel '1e3' = Cel '1000'", Trimmed("1e3") = Trimmed("1000"))
P("Cel '0x10' = Cel '16'", Trimmed("0x10") = Trimmed("16"))
P("Cel ' 123 ' = Cel '123'", Trimmed(" 123 ") = Trimmed("123"))
P("Cel 'an' != Cel 'AN'", Trimmed("an") != Trimmed("AN"))
P("Cel '0183' != Cel '183' (Ap als getal)", Trimmed("0183") != Trimmed("183"))
M := Map(), M[Trimmed("0123")] := 1
P("Map: '0123' geregistreerd, Has('123')", M.Has(Trimmed("123")))
; Register-regel zoals LeesRegister: StrSplit van een gelezen regel
r := StrSplit("10:00:00;0123", ";")
P("Register-sleutel '0123' Has(Cel '123')", Map(r[2], 1).Has(Trimmed("123")))
ExitApp
