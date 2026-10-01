#NoEnv
#SingleInstance Force
#Persistent
#MaxHotkeysPerInterval 1000
SendMode Input
SetWorkingDir %A_ScriptDir%
SetTitleMatchMode, 2
SetBatchLines, -1

;@Ahk2Exe-SetName Etiketten autoprinter
;@Ahk2Exe-SetDescription Etiketten autoprinter voor Pharmacom
;@Ahk2Exe-SetMainIcon Etiketten_autoprinter.ico

; =====================================================================
; Etiketten autoprinter voor Pharmacom
; (het versienummer staat alleen bij AppVersie hieronder)
;
; De interface staat in ui\venster.html (HTML/CSS in de ingebouwde browser).
;
; De app leest Pharmacom zelf uit via de Java Access Bridge (de
; toegankelijkheidskoppeling van Java). Er wordt niet gekopieerd met
; Ctrl+C en er wordt nergens gegokt:
;
;   1. De aanschrijfbuffer wordt uitgelezen (en automatisch bijgewerkt als
;      die in Pharmacom verandert): alle pati"enten met Pat.nr,
;      geboortedatum en ontslagdatum verschijnen in de lijst.
;   2. Pati"enten ZONDER ontslagdatum staan aangevinkt. Wie vandaag al
;      geprint is, staat uitgevinkt (dubbel printen voorkomen).
;   3. Per pati"ent:
;      - de pati"ent wordt op Pat.nr opgezocht in de aanschrijfbuffer en
;        met de pijltjestoetsen geselecteerd (daarna gecontroleerd);
;      - Ctrl+B -> wachten op het dossier -> F4 -> wachten op de
;        medicatiehistorie -> pijl omhoog;
;      - controle dat het dossier van de juiste pati"ent is (Pat.nr, of
;        achternaam + geboortedatum in het dossiervenster);
;      - de BOVENSTE regel met Ap = de ingelogde apotheek (rechtsonder in
;        Pharmacom, bijv. "AN - RS - 183" -> AN) en, als die optie aan
;        staat, Herhaal info = "ASB: Deelbaar" wordt opgezocht en
;        geselecteerd (geen passende regel -> Escape en overslaan);
;      - Ctrl+P -> wachten op het afdrukmenu -> "Barcode etiket" (Alt+B) -> Escape ->
;        wachten tot de aanschrijfbuffer weer zichtbaar is.
;   4. Elke ronde krijgt een rapport (CSV) in de map Rapporten.
;
; VEILIGHEID: klopt een selectie niet, verschijnt een scherm niet, is het
; dossier niet van de juiste pati"ent of is Pharmacom niet meer het actieve
; venster, dan stopt de app. Tijdens het printen zijn toetsenbord en muis
; geblokkeerd (optie); Esc stopt dan direct.
;
; Eenmalig nodig: de Java Access Bridge inschakelen (knop in de app) en
; daarna Pharmacom opnieuw starten.
; =====================================================================

AppTitel  := "Etiketten autoprinter"
AppVersie := "5.8.0"
;@Ahk2Exe-Let U_Versie = %A_PriorLine~U)^.*"(.+)".*$~$1%
;@Ahk2Exe-SetVersion %U_Versie%
; Ahk2Exe neemt het versienummer over uit de AppVersie-regel (A_PriorLine:
; de Let-regel moet daar DIRECT onder staan). De .exe-versie wordt gebruikt
; bij het bijwerken.
PhWin     := "Pharmacom ahk_exe javaw.exe"
IniFile     := A_ScriptDir . "\Etiketten_autoprinter.ini"
; Register van geprinte pati"enten en rapporten staan in de gedeelde map
; (bij een lokale installatie: de netwerkmap waar hij vandaan kwam). Is die
; niet bereikbaar, dan naast de app.
IniRead, DataMap, %IniFile%, Opslag, Map, %A_ScriptDir%
If !InStr(FileExist(DataMap), "D")
    DataMap := A_ScriptDir
GegevensMap := DataMap . "\Gegevens"
GeprintMap  := GegevensMap . "\Geprint"
RapportMap  := DataMap . "\Rapporten"
; Logbestand: een per dag, per computer, 30 dagen bewaard
LogMap      := A_ScriptDir . "\Gegevens\Log"
FormatTime, Vandaag,, yyyy-MM-dd
LogFile     := LogMap . "\" . Vandaag . " " . A_ComputerName . ".txt"
FileCreateDir, %GeprintMap%
FileCreateDir, %RapportMap%
FileCreateDir, %LogMap%
; Bewaartermijnen (dagen). Rapporten bevatten naam en geboortedatum (AVG),
; het register alleen Pat.nr's en is na de dag zelf niet meer nodig.
IniRead, RapportDagen, %IniFile%, Opslag, RapportDagen, 90
IniRead, RegisterDagen, %IniFile%, Opslag, RegisterDagen, 7
Opruimen(LogMap . "\*.txt", 30)
Opruimen(RapportMap . "\Rapport *.csv", RapportDagen)
Opruimen(GeprintMap . "\*.txt", RegisterDagen)
FileDelete, %A_ScriptDir%\Gegevens\Etiketten_autoprinter_log.txt   ; oud logbestand (v5.3-5.6)

; Kolommen waaraan de tabellen herkend worden (reguliere expressies op de
; kolomkop). Sleutel = naam die de app intern gebruikt.
BufferKoppen   := {naam: "i)^Pati", patnr: "i)^Pat\.?\s*nr", ontslag: "i)^Ontslag", gebdatum: "i)^Geb"}
; De medicatiehistorie bestaat uit twee tabellen naast elkaar (zelfde regels):
; links Laatste V/A + Etiketnaam, rechts Labeler, CF, Ap, Th. einddatum, ...
; (Labeler is nodig om hem niet te verwarren met de tabel in Receptverwerking,
; die ook Ap, Th. einddatum en Herhaal info heeft.)
HistorieKoppen := {labeler: "i)^Labeler", ap: "i)^Ap\W*$", einddatum: "i)^Th\.?\s*einddatum", herhaal: "i)^Herhaal"}
; Waarde in de kolom Herhaal info waarop gefilterd wordt (als de optie aan staat)
DeelbaarPatroon := "i)^ASB:\s*Deelbaar"
; Label rechtsonder in Pharmacom, bijv. "AN - RS - 183": het eerste deel is
; de apotheek waarop je ingelogd bent.
ApotheekPatroon := "^\s*([A-Za-z0-9]{1,4})\s*-\s*\S+\s*-\s*\S+\s*$"
Apotheek := ""
EtiketKoppen   := {etiket: "i)^Etiket"}

; --- Tekens (via Chr, altijd goed ook in een .exe) ---
EUml    := Chr(235)     ; e met trema
Bol     := Chr(0x25CF)  ; bolletje
Mid     := Chr(0xB7)    ; middenpunt
Play    := Chr(0x25B6)
Blok    := Chr(0x25A0)
PlusMin := Chr(0xB1)
Kruis   := Chr(0x2715)
Streep  := Chr(0x2013)
Vink    := Chr(0x2713)
Rond    := Chr(0x21BB)
Ellips  := Chr(0x2026)
Pijl    := Chr(0x25B8)

; --- Kleuren ---
KlrKop    := "1E293B"
KlrAchter := "F8FAFC"
KlrTekst  := "0F172A"
KlrGrijs  := "64748B"
KlrLicht  := "94A3B8"
KlrBlauw  := "2563EB"
KlrGroen  := "16A34A"
KlrOranje := "EA580C"
KlrRood   := "DC2626"

; Soorten pati"ent in de lijst: print = te printen, al = vandaag al geprint,
; ontslag, controle, en tijdens/na een ronde: bezig, ok, skip, fout.
; (De kleuren daarvan staan in ui\venster.html.)

; --- Wachttijden: [naam, standaard (ms), omschrijving] ---
; De app wacht zelf tot een scherm er echt is (dossier, medicatiehistorie,
; aanschrijfbuffer); deze tijden zijn alleen de korte extra pauzes daarna.
Wachttijden := [ ["SleepNaCtrlB",    50,    "Nadat het dossier verscheen"]
    , ["SleepNaF4",       100,   "Nadat de medicatiehistorie verscheen"]
    , ["SleepNaOmhoog",   100,   "Na pijl omhoog"]
    , ["SleepNaScherm",   100,   "Nadat de aanschrijfbuffer terug is"]
    , ["SleepNavigatie",  50,    "Na elke pijltjestoets"]
    , ["SleepNaCtrlP",    25,    "Na Ctrl+P (afdrukmenu)"]
    , ["MaxWachtPrint",   3000,  "Maximaal wachten op het afdrukmenu"]
    , ["SleepNaAltB",     25,    "Na het kiezen in het afdrukmenu"]
    , ["SleepNaEscape",   100,   "Na Escape"]
    , ["MaxWachtScherm",  10000, "Maximaal wachten op een scherm"]
    , ["MaxWachtLeeg",    4000,  "Maximaal wachten op een lege medicatiehistorie"] ]

; Instellingen van voor v5.1 golden voor vaste wachttijden; die worden
; (behalve de printinstellingen) teruggezet naar de nieuwe standaard.
IniRead, WtVersie, %IniFile%, Wachttijden, Versie, 1
If (WtVersie < 2)
{
    For i, k in ["SleepNaCtrlB", "SleepNaF4", "SleepNaOmhoog", "SleepNaScherm", "SleepNavigatie", "SleepNaEscape", "MaxWachtScherm"]
        IniDelete, %IniFile%, Wachttijden, %k%
    IniWrite, 2, %IniFile%, Wachttijden, Versie
}

; Ondergrenzen: korter wachten op het afdrukmenu is onveilig (te vroeg
; opgeven = het etiket wordt niet geprint). Het wachten stopt zodra het
; venster er is, dus een ruime waarde kost geen tijd.
WtMinimum := {MaxWachtPrint: 1000}

Wt := {}
For i, w in Wachttijden
{
    k := w[1]
    d := w[2]
    IniRead, v, %IniFile%, Wachttijden, %k%, %d%
    If v is not integer
        v := d
    If (WtMinimum.HasKey(k) && v < WtMinimum[k])
    {
        v := d
        IniWrite, %v%, %IniFile%, Wachttijden, %k%
    }
    Wt[k] := v
}

IniRead, OptBevestigen, %IniFile%, Opties, Bevestigen, 1
IniRead, OptBovenop,    %IniFile%, Opties, Bovenop, 1
IniRead, OptDeelbaar,   %IniFile%, Opties, AlleenDeelbaar, 1
IniRead, OptControle,   %IniFile%, Opties, DossierControleren, 1
IniRead, OptPatnr,      %IniFile%, Opties, DossierAlleenPatnr, 1
IniRead, OptBlokkeer,   %IniFile%, Opties, InvoerBlokkeren, 1
IniRead, OptGeluid,     %IniFile%, Opties, Geluid, 1
; Item in het afdrukmenu (Ctrl+P in het dossier) dat gekozen wordt; de
; sneltoets wordt uit Pharmacom gelezen (Barcode etiket = Alt+B).
IniRead, PrintMenuItem, %IniFile%, Opties, PrintMenu, Barcode etiket
PrintMenuItem := Trim(PrintMenuItem)
IniRead, UpdateMap,     %IniFile%, Update, Map, %A_Space%
UpdateMap := Trim(UpdateMap)

Jab := {varianten: {}, f: "", naam: ""}
Uitgevinkt := {}         ; Pat.nr's die de gebruiker heeft uitgevinkt
HerprintOk := {}         ; Pat.nr's die al geprint zijn maar toch aangevinkt
VandaagGeprint := {}     ; Pat.nr -> tijd (uit Gegevens\Geprint\<datum>.txt)
LaatsteHandtekening := ""
Geblokkeerd := false
RapportBestand := ""
AltBVerstuurd := false
Bezig := false
Stoppen := false
StopReden := ""
Vullen := false
PhHwnd := 0
PhPID := 0
JreBin := ""
Verbonden := false
VerbStatus := ""
Patienten := []
UiWachtrij := []
DialoogAntwoord := {}
DialoogTeller := 0
Knoppen := {}
HoverKnop := ""
Aantal := 0
Verwerkt := 0
Geprint := 0
Overgeslagen := 0
RunStart := 0

Gosub, MaakTray
Gosub, MaakGui
Log("App gestart (v" . AppVersie . ")")
Gosub, Bewaking
SetTimer, Bewaking, 3000
SetTimer, UpdateBijStart, -1500
SetTimer, ControleerLokaal, -2500
return  ; ===== einde auto-execute =====


; =====================================================================
; Verbinding met Pharmacom
; =====================================================================
; Draait elke 3 seconden (als er niet geprint wordt): zoekt Pharmacom,
; leest de aanschrijfbuffer in zodra er (opnieuw) verbinding is en werkt de
; lijst bij als de aanschrijfbuffer in Pharmacom verandert.
Bewaking:
    If (Bezig || BewakingBezig)
        return
    BewakingBezig := true
    WasVerbonden := Verbonden
    Verbind()
    If (Verbonden && !WasVerbonden)
        VernieuwLijst(false, true)
    Else If (Verbonden)
    {
        Handtekening := BufferHandtekening()
        If (Handtekening != "" && Handtekening != LaatsteHandtekening)
        {
            Log("Aanschrijfbuffer is veranderd in Pharmacom")
            VernieuwLijst(true, true)
        }
    }
    BewakingBezig := false
return

; Korte "vingerafdruk" van de aanschrijfbuffer (Pat.nr's + ontslagdatums),
; of "" als de aanschrijfbuffer niet zichtbaar is.
BufferHandtekening() {
    global BufferKoppen
    t := JabZoekTabel(BufferKoppen)
    If (!IsObject(t))
        return ""
    s := t.rows . ":"
    Loop % t.rows
        s .= Cel(t, A_Index - 1, "patnr") . "/" . Cel(t, A_Index - 1, "ontslag") . ";"
    JabVrijgeven(t)
    return s
}

Verbind() {
    global
    local hwnd, pad
    WinGet, hwnd, ID, %PhWin%
    If (!hwnd)
    {
        Verbonden := false
        ZetVerbinding("geen")
        return false
    }
    PhHwnd := hwnd
    WinGet, PhPID, PID, ahk_id %hwnd%
    WinGet, pad, ProcessPath, ahk_id %hwnd%
    SplitPath, pad,, JreBin
    If (A_PtrSize = 8)
    {
        ; Pharmacom draait op 32-bit Java; de koppeling werkt alleen vanuit 32-bit.
        Verbonden := false
        ZetVerbinding("64bit")
        return false
    }
    Verbonden := JabKoppel(hwnd, JreBin)
    ZetVerbinding(Verbonden ? "ok" : "jab")
    return Verbonden
}

ZetVerbinding(St) {
    global
    local Kl, Tx
    If (St = VerbStatus)
        return
    VerbStatus := St
    If (St = "ok")
        Kl := KlrGroen, Tx := "Verbonden met Pharmacom"
    Else If (St = "jab")
        Kl := KlrOranje, Tx := "Koppeling staat uit"
    Else If (St = "64bit")
        Kl := KlrRood, Tx := "Verkeerde versie (64-bit)"
    Else
        Kl := KlrLicht, Tx := "Pharmacom niet gevonden"
    UiVerbinding(St = "ok" ? "ok" : St = "jab" ? "warn" : St = "64bit" ? "err" : "off", Tx)
    ToonKnop("Start", St != "jab")
    ToonKnop("Koppel", St = "jab")
    ZetKnop("Vernieuwen", St = "ok" && !Bezig)

    If (St = "ok")
        Status("idle", "Verbonden. De aanschrijfbuffer wordt uitgelezen" . Ellips)
    Else If (St = "jab")
    {
        If (JabPropsAan())
            Status("fout", "De koppeling is ingeschakeld, maar Pharmacom moet nog opnieuw gestart worden. Sluit Pharmacom helemaal af en open het opnieuw.")
        Else
            Status("fout", "De koppeling met Pharmacom (Java Access Bridge) staat nog uit. Klik op 'Koppeling inschakelen' en start Pharmacom daarna opnieuw.")
    }
    Else If (St = "64bit")
        Status("fout", "Deze app moet als 32-bit programma gecompileerd worden (Ahk2Exe: base 'Unicode 32-bit').")
    Else
        Status("fout", "Pharmacom is niet geopend. Open Pharmacom met het scherm Aanschrijfbuffer.")
    Log("Verbinding: " . Tx)
}

JabPropsAan() {
    EnvGet, Profiel, USERPROFILE
    FileRead, Inhoud, %Profiel%\.accessibility.properties
    return RegExMatch(Inhoud, "m)^\s*assistive_technologies\s*=.*AccessBridge") > 0
}

KoppelInschakelen:
    If (JreBin = "")
        Verbind()
    If (JreBin != "" && FileExist(JreBin . "\jabswitch.exe"))
        RunWait, "%JreBin%\jabswitch.exe" -enable,, Hide
    If (!JabPropsAan())
    {
        ; Zonder jabswitch: het instellingenbestand zelf schrijven
        EnvGet, Profiel, USERPROFILE
        FileAppend, `nassistive_technologies=com.sun.java.accessibility.AccessBridge`nscreen_magnifier_present=true`n, %Profiel%\.accessibility.properties
    }
    If (JabPropsAan())
    {
        Log("Java Access Bridge ingeschakeld")
        VerbStatus := ""
        Verbind()
        Melding("Koppeling ingeschakeld", "Sluit Pharmacom helemaal af en start het opnieuw. Deze app maakt daarna vanzelf verbinding.")
    }
    Else
        Melding("Koppeling mislukt", "De koppeling kon niet ingeschakeld worden.`n`nVoer eventueel handmatig uit:`n" . JreBin . "\jabswitch.exe -enable", "fout")
return


; =====================================================================
; Aanschrijfbuffer uitlezen
; =====================================================================
; Behoud = de vinkjes die de gebruiker zelf heeft gezet/weggehaald
; aanhouden (anders: terug naar de standaard).
VernieuwLijst(Behoud := false, Stil := false) {
    global
    local t, r, p, lijst, check, n, nOntslag, nControle, nAl
    If (Bezig)
        return false
    If (!Verbonden && !Verbind())
        return false
    If (!Stil)
        Status("idle", "De aanschrijfbuffer wordt uitgelezen" . Ellips)

    t := JabZoekTabel(BufferKoppen)
    If (!IsObject(t))
    {
        Status("fout", "De aanschrijfbuffer is niet gevonden. Open in Pharmacom het scherm Aanschrijfbuffer en klik op Vernieuwen.")
        return false
    }
    If (!Behoud)
        Uitgevinkt := {}, HerprintOk := {}
    LeesGeprintRegister()

    lijst := []
    LaatsteHandtekening := t.rows . ":"
    Loop % t.rows
    {
        r := A_Index - 1
        p := {rij: r, naam: Cel(t, r, "naam"), patnr: Cel(t, r, "patnr"), ontslag: Cel(t, r, "ontslag"), gebdatum: Cel(t, r, "gebdatum")}
        LaatsteHandtekening .= p.patnr . "/" . p.ontslag . ";"
        If (p.patnr = "")
            p.soort := "controle", p.status := "Controleren: geen Pat.nr gelezen"
        Else If (p.ontslag != "" && IsDatum(p.ontslag))
            p.soort := "ontslag", p.status := (p.gebdatum != "" ? "Geboren " . p.gebdatum : "Ontslagdatum " . p.ontslag)
        Else If (p.ontslag != "")
            p.soort := "controle", p.status := "Onbekende waarde bij ontslagdatum"
        Else If (VandaagGeprint.HasKey(p.patnr))
            p.soort := "al", p.status := "Vandaag al geprint om " . VandaagGeprint[p.patnr]
        Else
            p.soort := "print", p.status := (p.gebdatum != "" ? "Geboren " . p.gebdatum : "Klaar om te printen")
        If (p.soort = "print")
            p.aan := !Uitgevinkt.HasKey(p.patnr)
        Else If (p.soort = "al")
            p.aan := HerprintOk.HasKey(p.patnr)
        Else
            p.aan := false
        lijst.Push(p)
    }
    JabVrijgeven(t)

    Apotheek := LeesApotheek()
    UiVerbinding("ok", "Verbonden" . (Apotheek != "" ? "  " . Mid . "  apotheek " . Apotheek : ""))

    Patienten := lijst
    Geprint := 0
    UiLijst()
    UiTellers()
    Ui("voortgang", {klaar: 0, totaal: 0, kleur: "", links: "Nog niet gestart", rechts: ""})
    KnopTekst("Start", "Start printen")

    n := Patienten.Length()
    nOntslag := TelSoort("ontslag")
    nControle := TelSoort("controle")
    nAl := TelSoort("al")
    Status("idle", n . " pati" . EUml . "nten in de aanschrijfbuffer, " . nOntslag . " met ontslagdatum" . (nAl ? ", " . nAl . " vandaag al geprint" : "") . (nControle ? ", " . nControle . " te controleren" : "") . ". Klik op Start printen.")
    If (Apotheek = "")
        Status("fout", "De ingelogde apotheek (rechtsonder in Pharmacom, bijv. 'AN - RS - 183') kon niet gelezen worden.")
    Log("Aanschrijfbuffer uitgelezen: " . n . " pati" . EUml . "nten, " . nOntslag . " met ontslagdatum, " . nAl . " vandaag al geprint, " . nControle . " te controleren, apotheek '" . Apotheek . "'")
    return true
}

; --- Register van vandaag geprinte pati"enten (dubbel printen voorkomen) ---
RegisterBestand() {
    global GeprintMap
    FormatTime, Datum,, yyyy-MM-dd
    return GeprintMap . "\" . Datum . ".txt"
}

LeesGeprintRegister() {
    global VandaagGeprint
    VandaagGeprint := {}
    Bestand := RegisterBestand()
    If !FileExist(Bestand)
        return
    Loop, Read, %Bestand%
    {
        Delen := StrSplit(A_LoopReadLine, ";")
        If (Delen.Length() >= 2 && Delen[2] != "")
            VandaagGeprint[Delen[2]] := SubStr(Delen[1], 1, 5)
    }
}

RegistreerGeprint(Patnr) {
    global VandaagGeprint, HerprintOk
    FormatTime, Tijd,, HH:mm:ss
    FileAppend, % Tijd . ";" . Patnr . "`n", % RegisterBestand(), UTF-8
    VandaagGeprint[Patnr] := SubStr(Tijd, 1, 5)
    HerprintOk.Delete(Patnr)
}

; Verwijdert bestanden (Patroon, bijv. "map\*.txt") die langer dan Dagen
; dagen niet gewijzigd zijn. Een ongeldige of te kleine waarde doet niets.
Opruimen(Patroon, Dagen) {
    If Dagen is not integer
        return
    If (Dagen < 1)
        return
    Loop, Files, %Patroon%
    {
        Oud := A_Now
        EnvSub, Oud, %A_LoopFileTimeModified%, Days
        If (Oud > Dagen)
            FileDelete, %A_LoopFileFullPath%
    }
}

TelSoort(Soort) {
    global Patienten
    n := 0
    For i, p in Patienten
        If (p.soort = Soort)
            n++
    return n
}

Printbaar(Soort) {
    return (Soort = "print" || Soort = "al")
}

; Datum in de vorm 25-08-1963, 25/08/1963, 25.08.1963, 5-8-63 of 1963-08-25
IsDatum(v) {
    return RegExMatch(v, "^(\d{1,2}[-/.]\d{1,2}[-/.](\d{2}|\d{4})|\d{4}-\d{2}-\d{2})$") > 0
}


; =====================================================================
; Het printen zelf
; =====================================================================
StartRun() {
    global
    local r, doelen, n, res, Duur, Samenvatting, nOntslag, nAl, Afgebroken, p, Waarschuwing
    If (Bezig)
        return
    If (!Verbind())
    {
        Gui, 1:Show, NoActivate
        return
    }
    If (!VernieuwLijst(true))
        return
    If (Apotheek = "")
        return   ; melding staat al in de status

    doelen := []
    nAl := 0
    For r, p in Patienten
    {
        If (p.aan && Printbaar(p.soort))
        {
            doelen.Push(r)
            If (p.soort = "al")
                nAl++
        }
    }
    n := doelen.Length()
    If (n = 0)
    {
        Status("fout", "Er is geen pati" . EUml . "nt aangevinkt om te printen.")
        return
    }

    ; Vandaag al geprint en toch aangevinkt: altijd even vragen
    If (nAl)
    {
        If !Vraag("Opnieuw printen?", nAl . " aangevinkte pati" . EUml . "nt(en) zijn vandaag al geprint.`n`nWil je die echt opnieuw printen?", "Opnieuw printen", "Annuleren", "waarschuwing")
            return
    }
    If (OptBevestigen)
    {
        nOntslag := TelSoort("ontslag")
        If !Vraag("Etiketten printen", n . " pati" . EUml . "nt" . (n = 1 ? "" : "en") . " " . Mid . " apotheek " . Apotheek . (OptDeelbaar ? " " . Mid . " alleen ASB: Deelbaar" : "") . (nOntslag ? "`n`n" . nOntslag . " pati" . EUml . "nt(en) met een ontslagdatum worden overgeslagen." : "") . (OptBlokkeer ? "`n`nToetsenbord en muis worden geblokkeerd tijdens het printen. Druk op Esc om te stoppen." : "`n`nDruk op Esc om te stoppen."), "Start printen", "Annuleren")
            return
    }

    WinActivate, ahk_id %PhHwnd%
    WinWaitActive, ahk_pid %PhPID%,, 3
    If (ErrorLevel)
    {
        Status("fout", "Pharmacom kon niet naar voren gehaald worden.")
        return
    }
    Sleep, 200

    Bezig := true
    Stoppen := false
    StopReden := ""
    Aantal := n
    Verwerkt := 0
    Geprint := 0
    Overgeslagen := 0
    OverslaanLijst := ""
    RunStart := A_TickCount
    ZetKnop("Start", false)
    ZetKnop("Vernieuwen", false)
    ZetKnop("Stop", true)
    Ui("bezig", 1)
    ZetVoortgang(KlrBlauw)
    SetTimer, TijdTimer, 500
    Gosub, TijdTimer

    Instel := "Start: " . n . " pati" . EUml . "nten. Wachttijden (ms):"
    For i, w in Wachttijden
        Instel .= " " . w[1] . "=" . Wt[w[1]]
    Log(Instel)
    StartRapport()
    InvoerBlokkeren(true, OptBlokkeer)

    Afgebroken := false
    For i, r in doelen
    {
        p := Patienten[r]
        p.geprintNu := false
        ZetRij(r, "bezig", "Bezig" . Ellips)
        Status("bezig", "Pati" . EUml . "nt " . i . " van " . n . ": " . p.naam . "  " . Mid . "  Esc = stoppen")
        LogBestand("Pat.nr " . p.patnr . ":")
        res := PrintPatient(p)

        If (res.stop)
        {
            If (StopReden = "")
                StopReden := "onbekende fout"
            If (p.geprintNu)
            {
                ; Het etiket is wel geprint, daarna ging er iets mis
                Geprint++
                p.soort := "ok"
                ZetRij(r, "ok", "Geprint, daarna gestopt: " . StopReden)
                Rapporteer(p, p.etiket, "Geprint (daarna gestopt: " . StopReden . ")")
            }
            Else
            {
                ZetRij(r, "fout", "Gestopt: " . StopReden)
                Rapporteer(p, "", "Gestopt: " . StopReden)
            }
            Afgebroken := true
            break
        }
        If (res.ok)
        {
            Geprint++
            p.soort := "ok"
            ZetRij(r, "ok", "Geprint" . (res.tekst != "" ? "  " . Mid . "  " . res.tekst : ""))
            Rapporteer(p, res.tekst, "Geprint")
            Log("Pat.nr " . p.patnr . " geprint")
        }
        Else
        {
            Overgeslagen++
            p.soort := "skip"
            Uitgevinkt[p.patnr] := true   ; bij Doorgaan niet opnieuw proberen
            ZetRij(r, "skip", "Overgeslagen: " . res.tekst)
            Rapporteer(p, "", "Overgeslagen: " . res.tekst)
            OverslaanLijst .= "- " . p.naam . " (" . p.patnr . "): " . res.tekst . "`n"
            Log("Pat.nr " . p.patnr . " overgeslagen (" . res.tekst . ")")
        }
        Verwerkt := i
        ZetVoortgang(KlrBlauw)
        ZetTellers()
    }

    ; --- Afronden ---
    ; Na een fout: Pharmacom netjes terugzetten op de aanschrijfbuffer, zodat
    ; Doorgaan meteen werkt. Niet als de gebruiker zelf stopte of in een
    ; ander venster bezig is.
    If (Afgebroken && StopReden != "gestopt door gebruiker" && StopReden != "Pharmacom was niet meer het actieve venster")
    {
        ZetSub("Pharmacom terugzetten op de aanschrijfbuffer" . Ellips)
        If (TerugNaarBuffer())
            StopReden .= " (Pharmacom staat weer op de aanschrijfbuffer)"
    }
    InvoerBlokkeren(false)
    Bezig := false
    Ui("bezig", 0)
    SetTimer, TijdTimer, Off
    Duur := FmtTijd((A_TickCount - RunStart) // 1000)
    ZetKnop("Start", true)
    ZetKnop("Vernieuwen", Verbonden)
    ZetKnop("Stop", false)
    ZetTellers()

    Samenvatting := Geprint . " geprint, " . Overgeslagen . " overgeslagen"
    If (StrLen(OverslaanLijst) > 1500)
        OverslaanLijst := SubStr(OverslaanLijst, 1, 1500) . Ellips . "`n"

    If (Afgebroken)
    {
        ZetVoortgang(KlrOranje)
        Ui("tijd", "Gestopt na " . Duur)
        KnopTekst("Start", "Doorgaan")
        Status("gestopt", "Gestopt bij pati" . EUml . "nt " . (Verwerkt + 1) . " van " . Aantal . ": " . StopReden . ". (" . Samenvatting . ") Klik op Doorgaan om verder te gaan; wie al geprint is, wordt overgeslagen.")
        Log("Gestopt: " . StopReden . " (" . Samenvatting . ")")
        Geluid("gestopt")
        Melding("Gestopt", StopReden . ".`n`n" . Samenvatting . "." . (OverslaanLijst != "" ? "`n`nOvergeslagen, handmatig controleren:`n" . OverslaanLijst : "") . "`n`nMet Doorgaan ga je verder; wie al geprint is, staat uitgevinkt.", "waarschuwing")
        return
    }

    ZetVoortgang(KlrGroen)
    Ui("tijd", "Klaar in " . Duur)
    Status("klaar", Samenvatting . ". Het rapport staat in de map Rapporten.")
    Log("Klaar: " . Samenvatting . " in " . Duur)
    Geluid("klaar")
    If (OverslaanLijst != "")
        Melding("Klaar!", Samenvatting . ".`n`nOvergeslagen, handmatig controleren:`n" . OverslaanLijst)
    Else
        TrayTip, %AppTitel%, Klaar! %Samenvatting%., 5, 1
}

; --- Geluid en melding als een ronde klaar of gestopt is ---
Geluid(Soort) {
    global OptGeluid, AppTitel, GuiHwnd
    ; Venster weer laten zien (ook als het geminimaliseerd was) en in de
    ; taakbalk laten knipperen
    Gui, 1:Show, NoActivate
    DllCall("FlashWindow", "Ptr", GuiHwnd, "Int", 1)
    If (!OptGeluid)
        return
    Bestand := A_WinDir . "\Media\" . (Soort = "klaar" ? "Windows Notify System Generic.wav" : "Windows Exclamation.wav")
    If FileExist(Bestand)
        SoundPlay, %Bestand%
    Else
        SoundPlay, % (Soort = "klaar" ? "*64" : "*48")
}

; --- Rapport per ronde (CSV, opent in Excel) ---
StartRapport() {
    global RapportBestand, RapportMap, Apotheek
    FormatTime, Stempel,, yyyy-MM-dd HH.mm.ss
    RapportBestand := RapportMap . "\Rapport " . Stempel . ".csv"
    FileAppend, % "Tijd;Pat.nr;Pati" . Chr(235) . "nt;Geboortedatum;Apotheek;Etiket;Status`r`n", %RapportBestand%, UTF-8
}

Rapporteer(p, Etiket, Status) {
    global RapportBestand, Apotheek
    If (RapportBestand = "")
        return
    FormatTime, Tijd,, HH:mm:ss
    Regel := ""
    For i, v in [Tijd, p.patnr, p.naam, p.gebdatum, Apotheek, Etiket, Status]
        Regel .= (i > 1 ? ";" : "") . """" . StrReplace(v, """", """""") . """"
    FileAppend, % Regel . "`r`n", %RapportBestand%, UTF-8
}

; --- Toetsenbord en muis blokkeren tijdens het printen ---
; Werkt zonder beheerdersrechten: alle toetsen en muisknoppen krijgen
; tijdelijk een sneltoets die niets doet. Esc stopt de ronde. De eigen
; toetsaanslagen van de app gaan er gewoon langs. Ctrl+Alt+Del werkt altijd.
; Volledig = false: alleen Esc als noodstop, verder niets blokkeren.
; ($ = via de toetsenbordhook, zodat de eigen toetsaanslagen van de app
; zoals Ctrl+B en Escape NIET worden tegengehouden.)
InvoerBlokkeren(Aan, Volledig := true) {
    global Geblokkeerd
    static Muis := ["LButton", "RButton", "MButton", "XButton1", "XButton2", "WheelUp", "WheelDown", "WheelLeft", "WheelRight"]
    static Actief := false
    If (Aan)
    {
        If (Actief)
            return
        Hotkey, $*Esc, EscStop, On UseErrorLevel
        If (Volledig)
        {
            Loop, 254
            {
                If (A_Index <= 6 || A_Index = 0x1B)   ; muisknoppen apart, Esc apart
                    continue
                Hotkey, % "$*vk" . Format("{:02X}", A_Index), Blokkeer, On UseErrorLevel
            }
            For i, k in Muis
                Hotkey, *%k%, Blokkeer, On UseErrorLevel
        }
        Actief := true
        Geblokkeerd := Volledig
        Log(Volledig ? "Toetsenbord en muis geblokkeerd (Esc = stoppen)" : "Esc = stoppen")
        return
    }
    If (!Actief)
        return
    Hotkey, $*Esc, Off, UseErrorLevel
    Loop, 254
    {
        If (A_Index <= 6 || A_Index = 0x1B)
            continue
        Hotkey, % "$*vk" . Format("{:02X}", A_Index), Off, UseErrorLevel
    }
    For i, k in Muis
        Hotkey, *%k%, Off, UseErrorLevel
    Actief := false
    Geblokkeerd := false
    Log("Toetsenbord en muis weer vrij")
}

Blokkeer:
return

EscStop:
    Gosub, StopKnop
return

; Print het etiket voor een pati"ent. Geeft terug:
;   {ok: true, tekst: etiketnaam}   geprint
;   {tekst: reden}                  overgeslagen
;   {stop: true}                    afbreken (reden staat in StopReden)
PrintPatient(p) {
    global
    local t, h, e, rij, ontslag, ok, anRij, etiket, vorige, snap, stabiel, rijen, r, Omschrijving, voor, leegTot, eind, gelijk, DossierHwnd

    ; --- 1. Pati"ent in de aanschrijfbuffer opzoeken en selecteren ---
    ZetSub("Pati" . EUml . "nt opzoeken in de aanschrijfbuffer" . Ellips)
    t := WachtOpTabel(BufferKoppen, Wt.MaxWachtScherm)
    If (!IsObject(t))
        return Fout("de aanschrijfbuffer is niet zichtbaar in Pharmacom")
    rij := ZoekRij(t, "patnr", p.patnr, p.rij)
    If (rij < 0)
    {
        JabVrijgeven(t)
        return {tekst: "niet meer in de aanschrijfbuffer"}
    }
    ontslag := Cel(t, rij, "ontslag")
    If (ontslag != "")
    {
        JabVrijgeven(t)
        return {tekst: "ontslagdatum " . ontslag}
    }
    ok := Navigeer(t, rij)
    JabVrijgeven(t)
    If (!ok)
        return Fout("de pati" . EUml . "nt kon niet geselecteerd worden in de aanschrijfbuffer (sluit een eventueel open dossier, klik " . Chr(233) . Chr(233) . "n keer op een pati" . EUml . "nt en klik op Doorgaan)")
    LogBestand("  geselecteerd in aanschrijfbuffer (regel " . (rij + 1) . ")")

    ; --- 2. Dossier en medicatiehistorie openen ---
    ZetSub("Dossier openen" . Ellips)
    voor := WinExist("A")
    If !Stap("^b", 0, "Ctrl+B")
        return Fout("")
    ; Het dossier is een apart venster: wachten tot dat actief is
    If !WachtOpNieuwVenster(voor, Wt.MaxWachtScherm)
        return Fout("het pati" . EUml . "ntdossier verscheen niet")
    DossierHwnd := WinExist("A")
    LogBestand("  dossier geopend")
    Wacht(Wt.SleepNaCtrlB)

    ZetSub("Medicatiehistorie openen" . Ellips)
    If !Stap("{F4}", 0, "F4")
        return Fout("")
    h := WachtOpTabel(HistorieKoppen, Wt.MaxWachtScherm)
    If (!IsObject(h))
    {
        LogZichtbareTabellen()
        return Fout("de medicatiehistorie werd niet herkend (zie logbestand)")
    }
    LogBestand("  medicatiehistorie zichtbaar")
    Wacht(Wt.SleepNaF4)
    If !Stap("{Up}", Wt.SleepNaOmhoog, "Pijl omhoog")
    {
        JabVrijgeven(h)
        return Fout("")
    }

    ; Wachten tot de inhoud geladen en stabiel is. Een lege tabel telt als
    ; "nog aan het laden", tot MaxWachtLeeg verstreken is.
    vorige := ""
    gelijk := 0
    stabiel := false
    leegTot := A_TickCount + Wt.MaxWachtLeeg
    eind := A_TickCount + Wt.MaxWachtScherm
    Loop
    {
        If (Stoppen)
        {
            JabVrijgeven(h)
            return Fout("gestopt door gebruiker")
        }
        rijen := TabelRijen(h)
        If (rijen = 0 && A_TickCount < leegTot)
            vorige := "", gelijk := 0
        Else
        {
            snap := Momentopname(h)
            gelijk := (snap = vorige) ? gelijk + 1 : 0
            If (gelijk >= 2)
            {
                stabiel := true
                break
            }
            vorige := snap
        }
        If (A_TickCount > eind)
            break
        Wacht(120)
    }
    If (!stabiel)
    {
        JabVrijgeven(h)
        return Fout("de medicatiehistorie bleef veranderen")
    }
    If (TabelRijen(h) = 0)
    {
        JabVrijgeven(h)
        LogBestand("  medicatiehistorie bleef leeg")
        If !Stap("{Escape}", Wt.SleepNaEscape, "Escape (lege historie)")
            return Fout("")
        If !WachtTerug(DossierHwnd)
            return Fout("Pharmacom keerde niet terug naar de aanschrijfbuffer")
        return {tekst: "medicatiehistorie is leeg"}
    }

    ; --- Controle: is dit dossier van de juiste pati"ent? ---
    If (OptControle)
    {
        ZetSub("Controleren of het dossier van " . p.naam . " is" . Ellips)
        If !BevestigDossier(p, DossierHwnd)
        {
            JabVrijgeven(h)
            return Fout("kon niet bevestigen dat het geopende dossier van " . p.naam . " (" . p.patnr . ") is")
        }
    }

    ; --- 3. Bovenste regel van de eigen apotheek (en evt. ASB: Deelbaar) ---
    Omschrijving := "Ap = " . Apotheek . (OptDeelbaar ? " en ASB: Deelbaar" : "")
    ZetSub("Regel met " . Omschrijving . " zoeken" . Ellips)
    rijen := TabelRijen(h)
    anRij := -1
    Loop, %rijen%
    {
        r := A_Index - 1
        If (Cel(h, r, "ap") != Apotheek)
            continue
        If (OptDeelbaar && !RegExMatch(Cel(h, r, "herhaal"), DeelbaarPatroon))
            continue
        anRij := r
        break
    }
    If (anRij < 0)
    {
        JabVrijgeven(h)
        LogBestand("  geen regel met " . Omschrijving . " (" . rijen . " regels)")
        If !Stap("{Escape}", Wt.SleepNaEscape, "Escape (geen passende regel)")
            return Fout("")
        If !WachtTerug(DossierHwnd)
            return Fout("Pharmacom keerde niet terug naar de aanschrijfbuffer")
        return {tekst: "geen regel met " . Omschrijving}
    }
    ; Linker tabel (Etiketnaam) - ook nodig als de focus daar staat
    e := JabZoekTabel(EtiketKoppen)
    etiket := IsObject(e) ? Cel(e, anRij, "etiket") : ""
    ok := Navigeer(h, anRij, e)
    If (ok)
    {
        ; Laatste controle vlak voor het printen: staat de selectie nog goed?
        Wacht(Wt.SleepNavigatie)
        ok := (JabGeselecteerd(h.vm, h.at) = anRij)
            || (IsObject(e) && JabGeselecteerd(e.vm, e.at) = anRij)
    }
    JabVrijgeven(h)
    JabVrijgeven(e)
    If (!ok)
        return Fout("de regel met " . Omschrijving . " kon niet geselecteerd worden")
    LogBestand("  regel met " . Omschrijving . " geselecteerd (regel " . (anRij + 1) . ")")

    ; --- 4. Printen ---
    ZetSub("Etiket printen" . Ellips)
    AltBVerstuurd := false
    ok := PrintEtiket()
    If (AltBVerstuurd)
    {
        ; Vanaf Alt+B telt het etiket als geprint (ook als er daarna iets
        ; misgaat), zodat het bij Doorgaan niet nog eens geprint wordt.
        RegistreerGeprint(p.patnr)
        p.geprintNu := true
        p.etiket := etiket
    }
    If (!ok)
        return Fout("")
    If !WachtTerug(DossierHwnd)
        return Fout("Pharmacom keerde na het printen niet terug naar de aanschrijfbuffer")
    return {ok: true, tekst: etiket}
}

; Zoekt in het dossiervenster naar het Pat.nr, of (als OptPatnr uit staat)
; naar achternaam + geboortedatum. Probeert het een paar seconden (het
; dossier kan nog laden).
BevestigDossier(p, Hwnd) {
    global Jab, Wt, Stoppen, OptPatnr
    Achternaam := Trim(StrSplit(p.naam, ",")[1])
    GebPatroon := ""
    If RegExMatch(p.gebdatum, "^(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})$", G)
        GebPatroon := "(?<!\d)0?" . (G1 + 0) . "[-/.]0?" . (G2 + 0) . "[-/.](" . G3 . "|" . SubStr(G3, -1) . ")(?!\d)"
    eind := A_TickCount + 3000
    Loop
    {
        Tekst := DossierTekst(Hwnd)
        HeeftPatnr := (p.patnr != "" && RegExMatch(Tekst, "(?<!\d)" . p.patnr . "(?!\d)"))
        HeeftNaam  := (Achternaam != "" && InStr(Tekst, Achternaam))
        HeeftGeb   := (GebPatroon != "" && RegExMatch(Tekst, GebPatroon))
        If (HeeftPatnr || (!OptPatnr && HeeftNaam && HeeftGeb))
        {
            LogBestand("  dossier bevestigd (" . (HeeftPatnr ? "Pat.nr" : "naam + geboortedatum") . ")")
            return true
        }
        If (A_TickCount > eind || Stoppen)
            break
        Wacht(200)
    }
    LogBestand("  dossier NIET bevestigd: Pat.nr " . (HeeftPatnr ? "ja" : "nee") . ", naam " . (HeeftNaam ? "ja" : "nee") . ", geboortedatum " . (HeeftGeb ? "ja" : "nee") . " (" . StrLen(Tekst) . " tekens tekst in dossier)")
    return false
}

; Alle zichtbare teksten (labels, velden, titel) in het dossiervenster,
; zonder de tabellen.
DossierTekst(Hwnd) {
    global Jab
    WinGetTitle, Titel, ahk_id %Hwnd%
    Tekst := Titel . "`n"
    If (!IsObject(Jab.f) || !DllCall(Jab.f.isJavaWindow, "Ptr", Hwnd, "Cdecl Int"))
        return Tekst
    Vm := 0, Root := 0
    If !DllCall(Jab.f.getAccessibleContextFromHWND, "Ptr", Hwnd, "Int*", Vm, Jab.jt . "*", Root, "Cdecl Int")
        return Tekst
    Teller := 0
    JabVerzamelTekst(Vm, Root, Tekst, 0, Teller)
    JabRelease(Vm, Root)
    return Tekst
}

JabVerzamelTekst(Vm, Ac, ByRef Tekst, Diepte, ByRef Teller) {
    global Jab
    Teller++
    If (Teller > 4000)
        return
    Info := JabInfo(Vm, Ac)
    If (!IsObject(Info) || !InStr("," . Info.states . ",", ",showing,"))
        return
    If (Info.role = "table" || Info.role = "menu bar" || Info.role = "popup menu")
        return
    Naam := Info.name
    If (Trim(Naam) = "" && Info.text)
        Naam := JabNaam(Vm, Ac)
    If (Trim(Naam) != "")
        Tekst .= Naam . "`n"
    If (Diepte > 60)
        return
    n := Info.children > 2000 ? 2000 : Info.children
    Loop, %n%
    {
        Kind := DllCall(Jab.f.getAccessibleChildFromContext, "Int", Vm, Jab.jt, Ac, "Int", A_Index - 1, "Cdecl " . Jab.jt)
        If (!Kind)
            continue
        JabVerzamelTekst(Vm, Kind, Tekst, Diepte + 1, Teller)
        JabRelease(Vm, Kind)
    }
}

; Zet de kolomkoppen van alle zichtbare tabellen in het logbestand (geen
; pati"entgegevens), om te zien waarom een tabel niet herkend wordt.
LogZichtbareTabellen() {
    Alle := []
    JabZoekTabel({}, Alle)
    LogBestand("  Zichtbare tabellen: " . Alle.Length())
    For i, t in Alle
    {
        Kolommen := ""
        For c, k in t.koppen
            Kolommen .= (c > 1 ? " | " : "") . (k = "" ? "(leeg)" : k)
        LogBestand("    tabel " . i . ": " . t.rows . " regels, kolommen: " . Kolommen)
        JabVrijgeven(t)
    }
}

Fout(Reden) {
    global StopReden
    If (StopReden = "")
        StopReden := Reden
    return {stop: true}
}

; Ctrl+P, wachten op het afdrukmenu, item kiezen (Alt+B), wachten tot het menu
; weg is, Escape.
PrintEtiket() {
    global
    local voor, item, eind, toets
    voor := WinExist("A")
    If !Stap("^p", Wt.SleepNaCtrlP, "Ctrl+P")
        return false
    ; Ctrl+P opent in het dossier een afdrukmenu (geen apart venster). Wachten
    ; tot dat menu met het juiste item via de koppeling zichtbaar is.
    item := ""
    eind := A_TickCount + Wt.MaxWachtPrint
    Loop
    {
        If (Stoppen)
        {
            StopReden := "gestopt door gebruiker"
            return false
        }
        item := JabZoekMenuItem(PrintMenuItem)
        If (IsObject(item) || A_TickCount > eind)
            break
        Wacht(30)
    }
    ; Geen menu = niet gokken: de sneltoets zou dan ergens anders terechtkomen
    ; en de Escape hierna zou een te laat geopend menu weer sluiten.
    If (!IsObject(item))
    {
        LogBestand("  afdrukmenu met '" . PrintMenuItem . "' verscheen niet binnen " . Wt.MaxWachtPrint . " ms")
        StopReden := "het afdrukmenu met '" . PrintMenuItem . "' verscheen niet (er is niets geprint)"
        return false
    }
    If (!item.aan || item.toets = "")
    {
        LogBestand("  '" . PrintMenuItem . "' staat uit of heeft geen sneltoets")
        StopReden := "'" . PrintMenuItem . "' kon niet gekozen worden in het afdrukmenu (er is niets geprint)"
        return false
    }
    LogBestand("  afdrukmenu verschenen")
    If !WinActive("ahk_id " . voor)
    {
        StopReden := "het dossier was niet meer het actieve venster"
        return false
    }
    toets := Format("{:L}", item.toets)
    If !Stap("!" . toets, 0, "Alt+" . Format("{:U}", toets) . " - " . PrintMenuItem)
        return false
    AltBVerstuurd := true
    ; Wachten tot het menu dicht is (anders zou Escape het printen annuleren).
    eind := A_TickCount + 10000
    While IsObject(JabZoekMenuItem(PrintMenuItem))
    {
        If (Stoppen)
        {
            StopReden := "gestopt door gebruiker"
            return false
        }
        If (A_TickCount > eind)
        {
            StopReden := "het afdrukmenu sloot niet"
            return false
        }
        Wacht(50)
    }
    Wacht(Wt.SleepNaAltB)
    return Stap("{Escape}", Wt.SleepNaEscape, "Escape")
}

; Zoekt in de vensters van Pharmacom een zichtbaar popupmenu met een item
; met deze naam. Geeft {aan: true/false, toets: sneltoets} of "".
JabZoekMenuItem(Naam) {
    global Jab, PhPID
    If (!IsObject(Jab.f) || !PhPID)
        return ""
    WinGet, Lijst, List, ahk_pid %PhPID%
    Loop, %Lijst%
    {
        Hwnd := Lijst%A_Index%
        If !DllCall(Jab.f.isJavaWindow, "Ptr", Hwnd, "Cdecl Int")
            continue
        Vm := 0, Root := 0
        If !DllCall(Jab.f.getAccessibleContextFromHWND, "Ptr", Hwnd, "Int*", Vm, Jab.jt . "*", Root, "Cdecl Int")
            continue
        If (!Root)
            continue
        Teller := 0
        R := JabZoekMenu(Vm, Root, Naam, 0, Teller)
        JabRelease(Vm, Root)
        If (IsObject(R))
            return R
    }
    return ""
}

JabZoekMenu(Vm, Ac, Naam, Diepte, ByRef Teller) {
    global Jab
    Teller++
    If (Teller > 5000)
        return ""
    Info := JabInfo(Vm, Ac)
    If (!IsObject(Info) || !InStr("," . Info.states . ",", ",showing,"))
        return ""
    If (Info.role = "popup menu")
    {
        n := Info.children > 100 ? 100 : Info.children
        Loop, %n%
        {
            Kind := DllCall(Jab.f.getAccessibleChildFromContext, "Int", Vm, Jab.jt, Ac, "Int", A_Index - 1, "Cdecl " . Jab.jt)
            If (!Kind)
                continue
            Ki := JabInfo(Vm, Kind)
            R := ""
            If (IsObject(Ki) && Ki.role = "menu item" && Trim(Ki.name) = Naam)
                R := {aan: InStr("," . Ki.states . ",", ",enabled,") > 0, toets: JabSneltoets(Vm, Kind)}
            JabRelease(Vm, Kind)
            If (IsObject(R))
                return R
        }
        return ""
    }
    If (Diepte > 60 || RegExMatch(Info.role, "^(table|menu bar|menu|list|tree|combo box)$"))
        return ""
    n := Info.children > 2000 ? 2000 : Info.children
    Loop, %n%
    {
        Kind := DllCall(Jab.f.getAccessibleChildFromContext, "Int", Vm, Jab.jt, Ac, "Int", A_Index - 1, "Cdecl " . Jab.jt)
        If (!Kind)
            continue
        R := JabZoekMenu(Vm, Kind, Naam, Diepte + 1, Teller)
        JabRelease(Vm, Kind)
        If (IsObject(R))
            return R
    }
    return ""
}

; Eerste sneltoets (letter) van een element, of "".
JabSneltoets(Vm, Ac) {
    global Jab
    If (!Jab.f.getAccessibleKeyBindings)
        return ""
    VarSetCapacity(Kb, 4 + 10 * 8, 0)
    If !DllCall(Jab.f.getAccessibleKeyBindings, "Int", Vm, Jab.jt, Ac, "Ptr", &Kb, "Cdecl Int")
        return ""
    If (NumGet(Kb, 0, "Int") < 1)
        return ""
    c := NumGet(Kb, 4, "UShort")
    return (c >= 0x30 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) ? Chr(c) : ""
}

; Wacht tot de medicatiehistorie weg is en de aanschrijfbuffer weer zichtbaar.
; Staat het dossier na 3 seconden nog open (Escape kwam niet aan), dan wordt
; Escape nog een keer gestuurd - alleen als het dossier het actieve venster is.
WachtTerug(Dossier := 0) {
    global
    local eind, h, t, opnieuw
    eind := A_TickCount + Wt.MaxWachtScherm
    opnieuw := A_TickCount + 3000
    Loop
    {
        If (Stoppen)
        {
            StopReden := "gestopt door gebruiker"
            return false
        }
        h := JabZoekTabel(HistorieKoppen)
        If (IsObject(h))
        {
            JabVrijgeven(h)
            If (Dossier && opnieuw && A_TickCount > opnieuw && WinActive("ahk_id " . Dossier))
            {
                opnieuw := 0
                LogBestand("  dossier nog open na 3 s")
                If !Stap("{Escape}", Wt.SleepNaEscape, "Escape opnieuw")
                    return false
            }
        }
        Else
        {
            t := JabZoekTabel(BufferKoppen)
            If (IsObject(t))
            {
                JabVrijgeven(t)
                Wacht(Wt.SleepNaScherm)
                return true
            }
        }
        If (A_TickCount > eind)
            return false
        Wacht(60)
    }
}

; Na een fout: met Escape (afdrukmenu, dossier) terug naar het hoofdvenster
; met de aanschrijfbuffer. Stuurt alleen toetsen als een venster van
; Pharmacom actief is; geeft true als de aanschrijfbuffer weer zichtbaar is.
TerugNaarBuffer() {
    global PhPID, PhHwnd, BufferKoppen, HistorieKoppen
    Loop, 5
    {
        a := WinExist("A")
        WinGet, apid, PID, ahk_id %a%
        If (apid != PhPID)
        {
            LogBestand("  terugzetten: Pharmacom is niet het actieve venster, niets gedaan")
            return false
        }
        If (a = PhHwnd)
        {
            h := JabZoekTabel(HistorieKoppen)
            t := IsObject(h) ? "" : JabZoekTabel(BufferKoppen)
            ok := !IsObject(h) && IsObject(t)
            JabVrijgeven(h)
            JabVrijgeven(t)
            LogBestand(ok ? "  terugzetten: aanschrijfbuffer zichtbaar" : "  terugzetten: aanschrijfbuffer niet herkend")
            return ok
        }
        If (A_Index = 5)
            break
        Send, {Escape}
        LogBestand("  terugzetten: Escape")
        ; Wachten tot het venster dicht is (een afdrukmenu sluiten laat het
        ; venster open; dan volgt de volgende Escape na de wachttijd)
        eind := A_TickCount + 2000
        While (WinExist("A") = a && A_TickCount < eind)
            Sleep, 50
        Sleep, 150
    }
    LogBestand("  terugzetten mislukt")
    return false
}

WachtOpTabel(Koppen, Timeout) {
    global Stoppen, StopReden
    eind := A_TickCount + Timeout
    Loop
    {
        If (Stoppen)
        {
            StopReden := "gestopt door gebruiker"
            return ""
        }
        t := JabZoekTabel(Koppen)
        If (IsObject(t))
            return t
        If (A_TickCount > eind)
            return ""
        Wacht(60)
    }
}

; Wacht tot een ander venster van Pharmacom actief is dan Voor.
WachtOpNieuwVenster(Voor, Timeout) {
    global Stoppen, StopReden, PhPID
    eind := A_TickCount + Timeout
    Loop
    {
        If (Stoppen)
        {
            StopReden := "gestopt door gebruiker"
            return false
        }
        a := WinExist("A")
        If (a && a != Voor)
        {
            WinGet, apid, PID, ahk_id %a%
            If (apid = PhPID)
                return true
        }
        If (A_TickCount > eind)
            return false
        Sleep, 20
    }
}

; Leest de apotheek waarop je ingelogd bent uit het label rechtsonder in
; Pharmacom (bijv. "AN - RS - 183" -> "AN"). Geeft "" als het niet lukt.
LeesApotheek() {
    global Jab, PhPID, ApotheekPatroon
    If (!IsObject(Jab.f) || !PhPID)
        return ""
    WinGet, Lijst, List, ahk_pid %PhPID%
    Loop, %Lijst%
    {
        Hwnd := Lijst%A_Index%
        If !DllCall(Jab.f.isJavaWindow, "Ptr", Hwnd, "Cdecl Int")
            continue
        Vm := 0, Root := 0
        If !DllCall(Jab.f.getAccessibleContextFromHWND, "Ptr", Hwnd, "Int*", Vm, Jab.jt . "*", Root, "Cdecl Int")
            continue
        If (!Root)
            continue
        Teller := 0
        Naam := JabZoekLabel(Vm, Root, ApotheekPatroon, 0, Teller)
        JabRelease(Vm, Root)
        If (Naam != "" && RegExMatch(Naam, ApotheekPatroon, M))
            return M1
    }
    return ""
}

JabZoekLabel(Vm, Ac, Patroon, Diepte, ByRef Teller) {
    global Jab
    Teller++
    If (Teller > 5000)
        return ""
    Info := JabInfo(Vm, Ac)
    If (!IsObject(Info) || !InStr("," . Info.states . ",", ",showing,"))
        return ""
    If (Info.role = "label" && RegExMatch(Info.name, Patroon))
        return Info.name
    If (Diepte > 60 || RegExMatch(Info.role, "^(table|menu bar|menu|popup menu|list|tree|combo box)$"))
        return ""
    n := Info.children > 2000 ? 2000 : Info.children
    Loop, %n%
    {
        Kind := DllCall(Jab.f.getAccessibleChildFromContext, "Int", Vm, Jab.jt, Ac, "Int", A_Index - 1, "Cdecl " . Jab.jt)
        If (!Kind)
            continue
        R := JabZoekLabel(Vm, Kind, Patroon, Diepte + 1, Teller)
        JabRelease(Vm, Kind)
        If (R != "")
            return R
    }
    return ""
}

; Zet de selectie in tabel t met pijltjestoetsen op regel Doel en
; controleert na elke toets of de selectie echt verschoven is.
; t2 = optionele tweede tabel met dezelfde regels (linkerdeel van de
; medicatiehistorie): staat de focus daar, dan wordt die gevolgd.
Navigeer(t, Doel, t2 := "") {
    global Wt, Stoppen
    Act := t, Ander := t2
    sel := JabGeselecteerd(t.vm, t.at)
    If (IsObject(t2) && sel < 0)
    {
        s2 := JabGeselecteerd(t2.vm, t2.at)
        If (s2 >= 0)
            Act := t2, Ander := t, sel := s2
    }
    Loop, % Abs(Doel - sel) + 5
    {
        If (sel = Doel)
            return true
        selAnder := IsObject(Ander) ? JabGeselecteerd(Ander.vm, Ander.at) : ""
        If !Stap(sel < Doel ? "{Down}" : "{Up}", 0, "Pijltjestoets (regel " . (sel + 1) . " -> " . (Doel + 1) . ")")
            return false
        nieuw := sel
        eind := A_TickCount + 1500
        While (nieuw = sel && A_TickCount < eind && !Stoppen)
        {
            Sleep, 20
            nieuw := JabGeselecteerd(Act.vm, Act.at)
            If (nieuw = sel && IsObject(Ander))
            {
                ; Misschien heeft de andere tabel de focus
                s2 := JabGeselecteerd(Ander.vm, Ander.at)
                If (s2 != selAnder)
                {
                    Tmp := Act, Act := Ander, Ander := Tmp
                    nieuw := s2
                }
            }
        }
        If (nieuw = sel)
        {
            LogBestand("  selectie veranderde niet na pijltjestoets")
            return false
        }
        sel := nieuw
        Wacht(Wt.SleepNavigatie)
    }
    return (sel = Doel)
}

ZoekRij(t, Sleutel, Waarde, Hint) {
    rijen := TabelRijen(t)
    If (Hint >= 0 && Hint < rijen && Cel(t, Hint, Sleutel) = Waarde)
        return Hint
    Loop, %rijen%
        If (Cel(t, A_Index - 1, Sleutel) = Waarde)
            return A_Index - 1
    return -1
}

; Korte samenvatting van de bovenste regels, om te zien of een tabel klaar
; is met laden.
Momentopname(h) {
    rijen := TabelRijen(h)
    s := rijen . ":"
    Loop, % (rijen > 12 ? 12 : rijen)
        s .= Cel(h, A_Index - 1, "ap") . "|" . Cel(h, A_Index - 1, "einddatum") . ";"
    return s
}

; Verstuurt een toets, maar alleen als er niet gestopt is en Pharmacom
; (of een venster van Pharmacom zelf, zoals een dialoog) actief is.
Stap(Toets, Ms, Label) {
    global Stoppen, StopReden, PhPID
    If (Stoppen)
    {
        StopReden := "gestopt door gebruiker"
        return false
    }
    If !WinActive("ahk_pid " . PhPID)
    {
        StopReden := "Pharmacom was niet meer het actieve venster"
        return false
    }
    Send, %Toets%
    LogBestand("  " . Label)
    Wacht(Ms)
    return true
}

; Wacht in kleine stukjes, zodat Stop direct reageert.
Wacht(Ms) {
    global Stoppen
    If Ms is not integer
        Ms := 1000
    Eind := A_TickCount + Ms
    While (A_TickCount < Eind && !Stoppen)
        Sleep, 20
}

FmtTijd(Sec) {
    Min := Sec // 60
    Rest := Mod(Sec, 60)
    return Min . ":" . SubStr("0" . Rest, -1)
}

TijdTimer:
    Verstreken := (A_TickCount - RunStart) // 1000
    If (Verwerkt > 0)
    {
        Resterend := Round((A_TickCount - RunStart) / Verwerkt * (Aantal - Verwerkt) / 1000)
        Ui("tijd", FmtTijd(Verstreken) . " verstreken  " . Mid . "  nog " . PlusMin . " " . FmtTijd(Resterend))
    }
    Else
        Ui("tijd", FmtTijd(Verstreken) . " verstreken")
return


; =====================================================================
; Java Access Bridge
; =====================================================================
; Laadt de bridge-DLL uit de Java-map van Pharmacom en kijkt of Pharmacom
; bereikbaar is. Eerst de moderne (-32) variant, dan de oude.
JabKoppel(Hwnd, JreMap) {
    global Jab
    static Functies := ["Windows_run", "isJavaWindow", "getAccessibleContextFromHWND"
        , "getAccessibleContextInfo", "getAccessibleChildFromContext", "releaseJavaObject"
        , "getAccessibleTableInfo", "getAccessibleTableCellInfo", "getAccessibleTableColumnHeader"
        , "getAccessibleTableColumnDescription", "getAccessibleTableRowSelectionCount"
        , "getAccessibleTableRowSelections", "getAccessibleTextInfo", "getAccessibleTextRange"
        , "getAccessibleKeyBindings"]
    If (IsObject(Jab.f) && DllCall(Jab.f.isJavaWindow, "Ptr", Hwnd, "Cdecl Int"))
        return true
    For i, Naam in ["WindowsAccessBridge-32.dll", "WindowsAccessBridge.dll"]
    {
        v := Jab.varianten[Naam]
        If (!IsObject(v))
        {
            Pad := JreMap . "\" . Naam
            If !FileExist(Pad)
                continue
            h := DllCall("LoadLibrary", "Str", Pad, "Ptr")
            If (!h)
                continue
            v := {naam: Naam, js: (i = 1 ? 8 : 4), jt: (i = 1 ? "Int64" : "Ptr"), f: {}}
            For j, Fn in Functies
                v.f[Fn] := DllCall("GetProcAddress", "Ptr", h, "AStr", Fn, "Ptr")
            Jab.varianten[Naam] := v
            If (!v.f.Windows_run || !v.f.isJavaWindow)
                continue
            DllCall(v.f.Windows_run, "Cdecl")
            Sleep, 700   ; de bridge meldt zich via berichten bij Java
        }
        If (!v.f.isJavaWindow)
            continue
        Loop, 3
        {
            If DllCall(v.f.isJavaWindow, "Ptr", Hwnd, "Cdecl Int")
            {
                Jab.f := v.f, Jab.js := v.js, Jab.jt := v.jt, Jab.naam := Naam
                LogBestand("Java Access Bridge actief via " . Naam)
                return true
            }
            Sleep, 100
        }
    }
    return false
}

JabRelease(Vm, Obj) {
    global Jab
    If (Obj)
        DllCall(Jab.f.releaseJavaObject, "Int", Vm, Jab.jt, Obj, "Cdecl")
}

JabInfo(Vm, Ac) {
    global Jab
    VarSetCapacity(Buf, 6188, 0)
    If !DllCall(Jab.f.getAccessibleContextInfo, "Int", Vm, Jab.jt, Ac, "Ptr", &Buf, "Cdecl Int")
        return ""
    return {name: StrGet(&Buf, "UTF-16")
        , role: StrGet(&Buf + 4608, "UTF-16")
        , states: StrGet(&Buf + 5632, "UTF-16")
        , children: NumGet(Buf, 6148, "Int")
        , text: NumGet(Buf, 6180, "Int")}
}

; Naam (= zichtbare tekst) van een element; valt terug op de tekstinhoud.
JabNaam(Vm, Ac) {
    global Jab
    Info := JabInfo(Vm, Ac)
    If (!IsObject(Info))
        return ""
    If (Trim(Info.name) != "" || !Info.text)
        return Info.name
    VarSetCapacity(Ti, 12, 0)
    If !DllCall(Jab.f.getAccessibleTextInfo, "Int", Vm, Jab.jt, Ac, "Ptr", &Ti, "Int", 0, "Int", 0, "Cdecl Int")
        return ""
    n := NumGet(Ti, 0, "Int")
    If (n < 1)
        return ""
    If (n > 1000)
        n := 1000
    VarSetCapacity(Tb, 2 * 1026, 0)
    If !DllCall(Jab.f.getAccessibleTextRange, "Int", Vm, Jab.jt, Ac, "Int", 0, "Int", n - 1, "Ptr", &Tb, "Short", 1025, "Cdecl Int")
        return ""
    return StrGet(&Tb, "UTF-16")
}

JabTabelInfo(Vm, Ac) {
    global Jab
    js := Jab.js, jt := Jab.jt
    VarSetCapacity(Ti, 48, 0)
    If !DllCall(Jab.f.getAccessibleTableInfo, "Int", Vm, jt, Ac, "Ptr", &Ti, "Cdecl Int")
        return ""
    JabRelease(Vm, NumGet(Ti, 0, jt))    ; caption
    JabRelease(Vm, NumGet(Ti, js, jt))   ; summary
    return {rows: NumGet(Ti, 2 * js, "Int"), cols: NumGet(Ti, 2 * js + 4, "Int")
        , ac: NumGet(Ti, 2 * js + 8, jt), at: NumGet(Ti, 3 * js + 8, jt)}
}

JabCelTekst(Vm, At, R, C) {
    global Jab
    VarSetCapacity(Ci, 40, 0)
    If !DllCall(Jab.f.getAccessibleTableCellInfo, "Int", Vm, Jab.jt, At, "Int", R, "Int", C, "Ptr", &Ci, "Cdecl Int")
        return ""
    Cac := NumGet(Ci, 0, Jab.jt)
    If (!Cac)
        return ""
    T := JabNaam(Vm, Cac)
    JabRelease(Vm, Cac)
    return T
}

; Kolomkoppen van een tabel (array, 1-based)
JabKoppen(Vm, Tac, Cols) {
    global Jab
    js := Jab.js, jt := Jab.jt
    Koppen := []
    VarSetCapacity(Hi, 48, 0)
    If DllCall(Jab.f.getAccessibleTableColumnHeader, "Int", Vm, jt, Tac, "Ptr", &Hi, "Cdecl Int")
    {
        Hat := NumGet(Hi, 3 * js + 8, jt)
        If (Hat)
        {
            Loop, %Cols%
                Koppen[A_Index] := Trim(JabCelTekst(Vm, Hat, 0, A_Index - 1))
        }
        JabRelease(Vm, NumGet(Hi, 0, jt))
        JabRelease(Vm, NumGet(Hi, js, jt))
        JabRelease(Vm, NumGet(Hi, 2 * js + 8, jt))
        JabRelease(Vm, Hat)
    }
    Loop, %Cols%
    {
        If (Koppen[A_Index] != "")
            continue
        Dac := DllCall(Jab.f.getAccessibleTableColumnDescription, "Int", Vm, jt, Tac, "Int", A_Index - 1, "Cdecl " . jt)
        Koppen[A_Index] := Dac ? Trim(JabNaam(Vm, Dac)) : ""
        JabRelease(Vm, Dac)
    }
    return Koppen
}

; Kolomnummers (0-based) bij de gezochte koppen, of "" als er een ontbreekt.
PasKoppen(Kop, Koppen) {
    Kol := {}
    For Sleutel, Patroon in Koppen
    {
        Gevonden := 0
        For c, k in Kop
        {
            If RegExMatch(k, Patroon)
            {
                Gevonden := c
                break
            }
        }
        If (!Gevonden)
            return ""
        Kol[Sleutel] := Gevonden - 1
    }
    return Kol
}

JabMaakTabel(Vm, Ac, Koppen) {
    Ti := JabTabelInfo(Vm, Ac)
    If (!IsObject(Ti))
        return ""
    Kop := JabKoppen(Vm, Ac, Ti.cols)
    Kol := PasKoppen(Kop, Koppen)
    If (!IsObject(Kol))
    {
        JabRelease(Vm, Ti.at)
        If (Ti.ac != Ac)
            JabRelease(Vm, Ti.ac)
        return ""
    }
    return {vm: Vm, ac: Ac, at: Ti.at, tac: Ti.ac, rows: Ti.rows, cols: Ti.cols, kol: Kol, koppen: Kop}
}

JabVrijgeven(t) {
    If (!IsObject(t))
        return
    JabRelease(t.vm, t.at)
    If (t.tac != t.ac)
        JabRelease(t.vm, t.tac)
    JabRelease(t.vm, t.ac)
}

; Zoekt in alle zichtbare Pharmacom-vensters naar een zichtbare tabel met
; de gegeven kolomkoppen. Met Alle (een array) worden alle zichtbare
; tabellen verzameld (voor de diagnose).
JabZoekTabel(Koppen, Alle := "") {
    global Jab, PhPID
    If (!IsObject(Jab.f) || !PhPID)
        return ""
    WinGet, Lijst, List, ahk_pid %PhPID%
    Loop, %Lijst%
    {
        Hwnd := Lijst%A_Index%
        If !DllCall(Jab.f.isJavaWindow, "Ptr", Hwnd, "Cdecl Int")
            continue
        Vm := 0, Root := 0
        If !DllCall(Jab.f.getAccessibleContextFromHWND, "Ptr", Hwnd, "Int*", Vm, Jab.jt . "*", Root, "Cdecl Int")
            continue
        If (!Root)
            continue
        Teller := 0
        R := JabZoekIn(Vm, Root, Koppen, 0, Teller, Alle)
        If (IsObject(R))
        {
            ; De tabel heeft eigen verwijzingen; het venster is niet meer nodig
            If (R.ac != Root)
                JabRelease(Vm, Root)
            return R
        }
        If (R != 1)
            JabRelease(Vm, Root)
    }
    return ""
}

; Doorzoekt de boom van zichtbare onderdelen. Geeft een tabel-object
; terug, 1 als het element bewaard is (in Alle), of "" (niets gevonden).
JabZoekIn(Vm, Ac, Koppen, Diepte, ByRef Teller, Alle) {
    global Jab
    Teller++
    If (Teller > 5000)
        return ""
    Info := JabInfo(Vm, Ac)
    If (!IsObject(Info) || !InStr("," . Info.states . ",", ",showing,"))
        return ""
    If (Info.role = "table")
    {
        t := JabMaakTabel(Vm, Ac, Koppen)
        If (!IsObject(t))
            return ""
        If (IsObject(Alle))
        {
            Alle.Push(t)
            return 1
        }
        return t
    }
    If (Diepte > 60 || RegExMatch(Info.role, "^(menu bar|menu|popup menu|list|tree|combo box)$"))
        return ""
    n := Info.children > 2000 ? 2000 : Info.children
    Loop, %n%
    {
        Kind := DllCall(Jab.f.getAccessibleChildFromContext, "Int", Vm, Jab.jt, Ac, "Int", A_Index - 1, "Cdecl " . Jab.jt)
        If (!Kind)
            continue
        R := JabZoekIn(Vm, Kind, Koppen, Diepte + 1, Teller, Alle)
        If (IsObject(R))
        {
            ; Tussenliggende onderdelen vrijgeven (anders blijven ze bij elke
            ; zoekactie - elke 3 s en tijdens het wachten - in Java bewaard)
            If (R.ac != Kind)
                JabRelease(Vm, Kind)
            return R
        }
        If (R != 1)
            JabRelease(Vm, Kind)
    }
    return ""
}

; Geselecteerde regel (0-based) of -1
JabGeselecteerd(Vm, At) {
    global Jab
    n := DllCall(Jab.f.getAccessibleTableRowSelectionCount, "Int", Vm, Jab.jt, At, "Cdecl Int")
    If (n < 1)
        return -1
    VarSetCapacity(Sel, 4 * n, 0)
    If !DllCall(Jab.f.getAccessibleTableRowSelections, "Int", Vm, Jab.jt, At, "Int", n, "Ptr", &Sel, "Cdecl Int")
        return -1
    return NumGet(Sel, 0, "Int")
}

TabelRijen(t) {
    Ti := JabTabelInfo(t.vm, t.ac)
    If (!IsObject(Ti))
        return 0
    JabRelease(t.vm, Ti.at)
    If (Ti.ac != t.ac)
        JabRelease(t.vm, Ti.ac)
    return Ti.rows
}

Cel(t, R, Sleutel) {
    v := JabCelTekst(t.vm, t.at, R, t.kol[Sleutel])
    v := RegExReplace(v, "<[^>]*>")   ; eventuele HTML-opmaak weghalen
    return Trim(v, " `t`r`n" . Chr(160))
}


; =====================================================================
; Diagnose: laat zien wat de app in Pharmacom ziet (alleen kolomkoppen,
; geen pati"entgegevens). Wordt ook in het logbestand gezet.
; =====================================================================
Diagnose:
    If (Bezig)
        return
    Verbind()
    D := AppTitel . " v" . AppVersie . " - diagnose`n`n"
    D .= "Pharmacom: " . (PhHwnd ? "gevonden (proces " . PhPID . ")" : "niet gevonden") . "`n"
    D .= "Java-map: " . JreBin . "`n"
    D .= "App: " . (A_PtrSize = 8 ? "64-bit" : "32-bit") . "`n"
    D .= "Koppeling ingesteld: " . (JabPropsAan() ? "ja" : "nee") . "`n"
    D .= "Koppeling actief: " . (Verbonden ? "ja (" . Jab.naam . ")" : "nee") . "`n"
    If (Verbonden)
        D .= "Ingelogde apotheek: " . ((Ap := LeesApotheek()) != "" ? Ap : "niet gevonden") . "`n"
    If (Verbonden)
    {
        Alle := []
        JabZoekTabel({}, Alle)
        D .= "`nZichtbare tabellen: " . Alle.Length() . "`n"
        For i, t in Alle
        {
            Soort := ""
            If IsObject(PasKoppen(t.koppen, BufferKoppen))
                Soort := "  = AANSCHRIJFBUFFER"
            Else If IsObject(PasKoppen(t.koppen, HistorieKoppen))
                Soort := "  = MEDICATIEHISTORIE"
            Kolommen := ""
            For c, k in t.koppen
                Kolommen .= (c > 1 ? " | " : "") . (k = "" ? "(leeg)" : k)
            D .= "`nTabel " . i . Soort . "`n  " . t.rows . " regels, " . t.cols . " kolommen, geselecteerde regel: " . (JabGeselecteerd(t.vm, t.at) + 1) . "`n  Kolommen: " . Kolommen . "`n"
            JabVrijgeven(t)
        }
    }
    LogBestand("`n" . D)
    Melding("Diagnose", D . "`n(Dit staat ook in het logbestand.)", "code")
return


; =====================================================================
; Venster
; =====================================================================
; De interface is een HTML-pagina (ui\venster.html) in de ingebouwde
; browser van Windows. Klikken komen binnen als "ahk:..."-navigaties
; (WB_BeforeNavigate2); de app werkt de pagina bij via Ui(opdracht, data).
MaakGui:
    GB := 540, GH := 702
    UiMap := A_Temp . "\Etiketten_autoprinter_ui"
    FileCreateDir, %UiMap%
    FileInstall, ui\venster.html, %UiMap%\venster.html, 1
    FileInstall, ui\icoon.png, %UiMap%\icoon.png, 1

    Gui, 1:+HwndGuiHwnd -Caption
    Gui, 1:Color, EEF2F7
    Gui, 1:Margin, 0, 0
    Gui, 1:Add, ActiveX, x0 y0 w%GB% h%GH% vWB, Shell.Explorer
    WB.Silent := true
    ComObjConnect(WB, "WB_")
    Gui, 1:Show, Hide w%GB% h%GH%, %AppTitel%
    WB.Navigate("file:///" . StrReplace(UiMap, "\", "/") . "/venster.html")
    While (WB.ReadyState != 4 || WB.Busy)
        Sleep, 10
    UiWin := WB.Document.parentWindow
    ; Bij Windows-schaalinstelling > 100% de pagina meeschalen
    If (A_ScreenDPI != 96)
        Try WB.ExecWB(63, 2, Round(A_ScreenDPI / 96 * 100), 0)

    ; Afgeronde hoeken en schaduw (Windows 11)
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", GuiHwnd, "UInt", 33, "Int*", 2, "UInt", 4)
    VarSetCapacity(Marge, 16, 0), NumPut(1, Marge, 0, "Int")
    DllCall("dwmapi\DwmExtendFrameIntoClientArea", "Ptr", GuiHwnd, "Ptr", &Marge)

    ; --- Rechtsonder op het scherm, zonder Pharmacom de focus af te pakken ---
    DetectHiddenWindows, On
    WinGetPos,,, VW, VH, ahk_id %GuiHwnd%
    DetectHiddenWindows, Off
    SysGet, WA, MonitorWorkArea
    PosX := WARight - VW - 12
    PosY := WABottom - VH - 12
    If (PosY < WATop)
        PosY := WATop
    Gui, 1:Show, x%PosX% y%PosY% NoActivate
    If (OptBovenop)
        Gui, 1:+AlwaysOnTop

    Knoppen := {start: {aan: 1, zichtbaar: 1}, stop: {aan: 0, zichtbaar: 1}, vernieuwen: {aan: 0, zichtbaar: 1}, koppel: {aan: 1, zichtbaar: 0}}
    Ui("versie", AppVersie)
    For Naam in Knoppen
        UiKnop(Naam)
    UiOpties()
    ZetHint()
    Status("idle")
    UiTellers()
return

; --- Van de app naar de pagina ---
Ui(Opdracht, Data := "") {
    global UiWin
    Try UiWin.api(Opdracht, IsObject(Data) ? Json(Data) : Json(Data . ""))
}

; Eenvoudige JSON-omzetting (alle waarden als tekst; arrays herkend aan 1..n)
Json(v) {
    If IsObject(v)
    {
        n := v.Length()
        If (n > 0 && n = v.Count() || v.Count() = 0)
        {
            s := ""
            For i, x in v
                s .= (i > 1 ? "," : "") . Json(x)
            return "[" . s . "]"
        }
        s := ""
        For k, x in v
            s .= (s = "" ? "" : ",") . Json(k . "") . ":" . Json(x)
        return "{" . s . "}"
    }
    v := StrReplace(v, "\", "\\")
    v := StrReplace(v, """", "\""")
    v := StrReplace(v, "`r", "\r")
    v := StrReplace(v, "`n", "\n")
    v := StrReplace(v, "`t", "\t")
    return """" . v . """"
}

UiKnop(Naam) {
    global Knoppen
    k := Knoppen[Naam]
    Ui("knop", {naam: Naam, aan: k.aan ? 1 : 0, zichtbaar: k.zichtbaar ? 1 : 0, tekst: k.tekst})
}

ZetKnop(Naam, Aan) {
    global Knoppen
    Naam := Format("{:L}", Naam)
    Knoppen[Naam].aan := Aan
    UiKnop(Naam)
}

ToonKnop(Naam, Zichtbaar) {
    global Knoppen
    Naam := Format("{:L}", Naam)
    Knoppen[Naam].zichtbaar := Zichtbaar
    UiKnop(Naam)
}

KnopTekst(Naam, Tekst) {
    global Knoppen
    Naam := Format("{:L}", Naam)
    Knoppen[Naam].tekst := Tekst
    UiKnop(Naam)
}

UiOpties() {
    global
    Ui("opties", {deelbaar: OptDeelbaar, controle: OptControle, patnr: OptPatnr, blokkeer: OptBlokkeer, bevestigen: OptBevestigen, bovenop: OptBovenop, geluid: OptGeluid})
}

ZetHint() {
    global OptBlokkeer, Mid
    Ui("hint", (OptBlokkeer ? "Toetsenbord en muis zijn geblokkeerd tijdens het printen" : "Klik tijdens het printen niet in Pharmacom") . " &middot; <kbd>Esc</kbd> stopt")
}

Status(Fase, Sub := "") {
    global AppTitel, Ellips
    Koppen := {idle: "Klaar voor start", bezig: "Bezig met printen" . Ellips, gestopt: "Gestopt", klaar: "Klaar!", fout: "Let op"}
    If (Sub = "" && Fase = "idle")
        Sub := "Klik op Start printen."
    Ui("status", {fase: Fase, titel: Koppen[Fase], sub: Sub})
    Kop := Koppen[Fase]
    Menu, Tray, Tip, %AppTitel% - %Kop%
}

ZetSub(Tekst) {
    Ui("sub", Tekst)
}

UiVerbinding(Soort, Tekst) {
    Ui("verbinding", {soort: Soort, tekst: Tekst})
}

; Kleur: blauw / groen / oranje
ZetVoortgang(Kleur) {
    global Verwerkt, Aantal
    Kl := (Kleur = "16A34A") ? "groen" : (Kleur = "EA580C") ? "oranje" : ""
    Ui("voortgang", {klaar: Verwerkt, totaal: Aantal, kleur: Kl, links: Verwerkt . " van " . Aantal . " verwerkt"})
}

UiTellers() {
    global Patienten, Geprint
    n := 0
    For i, p in Patienten
        If (p.aan && Printbaar(p.soort))
            n++
    ; Geprint = vandaag al geprint ("Al geprint") + net in deze ronde geprint
    Ui("tellers", {totaal: Patienten.Length(), print: n, ontslag: TelSoort("ontslag"), geprint: TelSoort("al") + TelSoort("ok")})
}

ZetTellers() {
    UiTellers()
}

UiLijst() {
    global Patienten
    L := []
    For i, p in Patienten
        L.Push({naam: p.naam, patnr: p.patnr, ontslag: p.ontslag, soort: p.soort, detail: p.status, aan: p.aan ? 1 : 0})
    Ui("lijst", L)
}

ZetRij(R, Soort, Tekst) {
    global Patienten
    p := Patienten[R]
    p.status := Tekst
    Ui("rij", {i: R - 1, soort: Soort, detail: Tekst, aan: p.aan ? 1 : 0, focus: Soort = "bezig" ? 1 : 0})
}

; --- Van de pagina naar de app ---
WB_BeforeNavigate2(pDisp, Url, Flags, TargetFrameName, PostData, Headers, Cancel) {
    If (SubStr(Url, 1, 4) != "ahk:")
        return
    NumPut(-1, ComObjValue(Cancel), "Short")
    UiActie(SubStr(Url, 5))
}

UiActie(A) {
    global
    local Delen, Soort, i, p, Waarde
    Delen := StrSplit(A, "/")
    Soort := Delen[1]
    If (Soort = "knop" && Delen[2] = "stop")
    {
        Gosub, StopKnop
        return
    }
    If (Soort = "venster" && Delen[2] = "slepen")
    {
        DllCall("ReleaseCapture")
        PostMessage, 0xA1, 2,,, ahk_id %GuiHwnd%
        return
    }
    If (Soort = "dialoog")
    {
        DialoogAntwoord["d" . Delen[2]] := Delen[3]
        return
    }
    If (Soort = "toggle")
    {
        WisselVinkje(Delen[2] + 1)
        return
    }
    If (Soort = "alles")
    {
        AllesWisselen()
        return
    }
    If (Soort = "opt")
    {
        ZetOptie(Delen[2], Delen[3] = "1")
        return
    }
    ; Langere acties niet binnen de klik zelf uitvoeren
    UiWachtrij.Push(A)
    SetTimer, UiVerwerk, -10
}

UiVerwerk:
    While (UiWachtrij.Length())
    {
        UiA := UiWachtrij.RemoveAt(1)
        UiD := StrSplit(UiA, "/")
        If (UiA = "knop/start")
            Gosub, StartKnop
        Else If (UiA = "knop/vernieuwen")
            Gosub, VernieuwKnop
        Else If (UiA = "knop/koppel")
            Gosub, KoppelInschakelen
        Else If (UiA = "link/instellingen")
            Gosub, Instellingen
        Else If (UiA = "link/rapporten")
            Gosub, OpenRapporten
        Else If (UiA = "link/log")
            Gosub, OpenLog
        Else If (UiA = "link/diagnose")
            Gosub, Diagnose
        Else If (UiA = "venster/min")
            Gosub, Minimaliseer
        Else If (UiA = "venster/sluit")
            Gosub, GuiClose
        Else If (UiD[1] = "inst")
            InstellingActie(UiA)
    }
return

WisselVinkje(R) {
    global Patienten, Bezig, Uitgevinkt, HerprintOk
    p := Patienten[R]
    If (Bezig || !IsObject(p) || !Printbaar(p.soort))
        return
    p.aan := !p.aan
    If (p.soort = "al")
    {
        If (p.aan)
            HerprintOk[p.patnr] := true
        Else
            HerprintOk.Delete(p.patnr)
    }
    Else If (p.aan)
        Uitgevinkt.Delete(p.patnr)
    Else
        Uitgevinkt[p.patnr] := true
    ZetRij(R, p.soort, p.status)
    UiTellers()
}

; Kop-vinkje: alles wat nog niet geprint is aan, of (als alles al aan
; staat) alles uit. Vandaag al geprinte pati"enten worden niet aangezet.
AllesWisselen() {
    global Patienten, Bezig
    If (Bezig)
        return
    AllesAan := true
    For i, p in Patienten
        If (p.soort = "print" && !p.aan)
            AllesAan := false
    For i, p in Patienten
    {
        If (p.soort = "print" && p.aan = AllesAan)
            WisselVinkje(i)
        Else If (AllesAan && p.soort = "al" && p.aan)
            WisselVinkje(i)
    }
}

ZetOptie(Naam, Aan) {
    global
    Aan := Aan ? 1 : 0
    If (Naam = "deelbaar")
        OptDeelbaar := Aan
    Else If (Naam = "controle")
        OptControle := Aan
    Else If (Naam = "patnr")
        OptPatnr := Aan
    Else If (Naam = "blokkeer")
        OptBlokkeer := Aan
    Else If (Naam = "bevestigen")
        OptBevestigen := Aan
    Else If (Naam = "bovenop")
        OptBovenop := Aan
    Else If (Naam = "geluid")
        OptGeluid := Aan
    IniWrite, %OptGeluid%,     %IniFile%, Opties, Geluid
    IniWrite, %OptBevestigen%, %IniFile%, Opties, Bevestigen
    IniWrite, %OptBovenop%,    %IniFile%, Opties, Bovenop
    IniWrite, %OptDeelbaar%,   %IniFile%, Opties, AlleenDeelbaar
    IniWrite, %OptControle%,   %IniFile%, Opties, DossierControleren
    IniWrite, %OptPatnr%,      %IniFile%, Opties, DossierAlleenPatnr
    IniWrite, %OptBlokkeer%,   %IniFile%, Opties, InvoerBlokkeren
    If (OptBovenop)
        Gui, 1:+AlwaysOnTop
    Else
        Gui, 1:-AlwaysOnTop
    UiOpties()
    ZetHint()
}

; --- Dialoogvensters in de stijl van de app ---
; Soort: vraag / info / waarschuwing / fout / code.
; Vraag() wacht op het antwoord en geeft true (Ja) of false (Nee).
Vraag(Titel, Tekst, Ja := "Ja", Nee := "Nee", Soort := "vraag") {
    global DialoogAntwoord, DialoogTeller
    DialoogTeller++
    Id := DialoogTeller
    Sleutel := "d" . Id
    DialoogAntwoord[Sleutel] := ""
    Ui("dialoog", {id: Id, soort: Soort, titel: Titel, tekst: Tekst, ja: Ja, nee: Nee})
    Gui, 1:Show
    While (DialoogAntwoord[Sleutel] = "")
        Sleep, 30
    Antwoord := DialoogAntwoord[Sleutel]
    DialoogAntwoord.Delete(Sleutel)
    Ui("dialoogdicht")
    return (Antwoord = "1")
}

Melding(Titel, Tekst, Soort := "info") {
    Vraag(Titel, Tekst, "OK", "", Soort)
}

LogBestand(Msg) {
    global LogFile
    FormatTime, ts,, HH:mm:ss
    FileAppend, %ts%.%A_MSec% - %Msg%`n, %LogFile%, UTF-8
}

Log(Msg) {
    LogBestand(Msg)
}

StartKnop:
    If (Bezig)
        return
    StartRun()
return

StopKnop:
    If (Bezig)
    {
        Stoppen := true
        Status("gestopt", "Wordt gestopt" . Ellips)
    }
return

VernieuwKnop:
    VernieuwLijst(false)
return

OpenLog:
    If FileExist(LogFile)
        Run, %LogFile%
return

OpenRapporten:
    Run, %RapportMap%
return

Minimaliseer:
    Gui, 1:Minimize
return

ToonVenster:
    Gui, 1:Show
return

GuiClose:
    If (Bezig)
    {
        If !Vraag("Afsluiten?", "Er wordt nog geprint. Wil je de app toch afsluiten?", "Afsluiten", "Doorgaan", "waarschuwing")
            return
        Stoppen := true
    }
    InvoerBlokkeren(false)
    ExitApp
return


; =====================================================================
; Instellingen (wachttijden en updates) - als dialoog in de pagina
; =====================================================================
Instellingen:
    InstItems := []
    For i, w in Wachttijden
        InstItems.Push({k: w[1], label: w[3], v: Wt[w[1]], d: w[2]})
    UiOpties()
    Ui("instellingen", {items: InstItems, map: UpdateMap})
return

; Acties uit de instellingen-dialoog: "inst/<actie>?k=v&..."
InstellingActie(A) {
    global
    local Actie, Params, Delen, Paar, kv, k, v, Gekozen, Doel
    Actie := RegExReplace(SubStr(A, 6), "\?.*$")
    Params := {}
    If InStr(A, "?")
    {
        For i, Paar in StrSplit(SubStr(A, InStr(A, "?") + 1), "&")
        {
            kv := StrSplit(Paar, "=", , 2)
            Params[kv[1]] := UriDecode(kv[2])
        }
    }
    If (Actie = "annuleer")
    {
        Ui("dialoogdicht")
        return
    }
    If (Actie = "installeer")
    {
        Ui("dialoogdicht")
        InstalleerLokaal(true)
        return
    }
    If (Actie = "bladeren")
    {
        Gui, 1:+OwnDialogs
        FileSelectFolder, Gekozen,, 3, Kies de map met de nieuwste Etiketten_autoprinter.exe
        If (Gekozen != "")
            Ui("instmap", Gekozen)
        return
    }
    ; opslaan / controleer / publiceer: eerst de waarden bewaren
    For i, w in Wachttijden
    {
        k := w[1]
        v := Params[k]
        If v is integer
        {
            If (WtMinimum.HasKey(k) && v < WtMinimum[k])
                v := WtMinimum[k]
            Wt[k] := v
            IniWrite, %v%, %IniFile%, Wachttijden, %k%
        }
    }
    UpdateMap := Trim(Params["map"])
    IniWrite, %UpdateMap%, %IniFile%, Update, Map
    Log("Instellingen opgeslagen")
    If (Actie = "opslaan")
    {
        Ui("dialoogdicht")
        return
    }
    If (Actie = "controleer")
    {
        ControleerUpdate(false)
        Gosub, Instellingen
        return
    }
    If (Actie = "publiceer")
    {
        Doel := UpdateMap
        If (Doel = "" || !InStr(FileExist(Doel), "D"))
            Melding("Updates", "Kies eerst een bestaande updatemap.", "waarschuwing")
        Else If (!A_IsCompiled)
            Melding("Updates", "Dit kan alleen vanuit de gecompileerde .exe.", "waarschuwing")
        Else
        {
            ; Eerst de controlewaarde weghalen: zo installeert niemand een
            ; half gekopieerde .exe terwijl het kopi"eren nog bezig is
            FileDelete, %Doel%\Etiketten_autoprinter.exe.sha256
            FileCopy, %A_ScriptFullPath%, %Doel%\Etiketten_autoprinter.exe, 1
            Hash := ErrorLevel ? "" : Sha256(A_ScriptFullPath)
            If (Hash != "" && Sha256(Doel . "\Etiketten_autoprinter.exe") = Hash)
                FileAppend, %Hash%, %Doel%\Etiketten_autoprinter.exe.sha256
            If (Hash = "" || !FileExist(Doel . "\Etiketten_autoprinter.exe.sha256"))
                Melding("Updates", "Kopi" . EUml . "ren naar de updatemap is mislukt.", "fout")
            Else
            {
                Log("Versie " . AppVersie . " in de updatemap gezet")
                Melding("Updates", "Versie " . AppVersie . " staat nu in de updatemap. Andere computers krijgen de update bij de volgende start.")
            }
        }
        Gosub, Instellingen
    }
}

; Decodeert %XX-codering (UTF-8) uit de pagina
UriDecode(S) {
    S := StrReplace(S, "+", " ")
    VarSetCapacity(Buf, StrLen(S) + 1, 0)
    n := 0, i := 1
    While (i <= StrLen(S))
    {
        c := SubStr(S, i, 1)
        If (c = "%" && RegExMatch(SubStr(S, i + 1, 2), "^[0-9A-Fa-f]{2}$"))
        {
            NumPut("0x" . SubStr(S, i + 1, 2), Buf, n++, "UChar")
            i += 3
        }
        Else
        {
            ; gewoon teken (ASCII of al gedecodeerd) als UTF-8 wegschrijven
            VarSetCapacity(Tmp, 8, 0)
            m := StrPut(c, &Tmp, "UTF-8") - 1
            Loop, %m%
                NumPut(NumGet(Tmp, A_Index - 1, "UChar"), Buf, n++, "UChar")
            i += 1
        }
    }
    return StrGet(&Buf, n, "UTF-8")
}

UpdateBijStart:
    ControleerUpdate(true)
return

; =====================================================================
; Lokaal installeren: vanaf de netwerkschijf starten is trager en werkt
; niet als de schijf even weg is. De app biedt aan zichzelf naar deze
; computer te kopi"eren (met snelkoppelingen); de netwerkmap wordt dan de
; updatemap, zodat de lokale versie bijgewerkt blijft.
; =====================================================================
ControleerLokaal:
    If (Bezig || !A_IsCompiled || !OpNetwerk())
        return
    IniRead, LokaalNietVragen, %IniFile%, Opties, LokaalNietVragen, 0
    If (LokaalNietVragen)
        return
    InstalleerLokaal(false)
return

OpNetwerk() {
    If (SubStr(A_ScriptDir, 1, 2) = "\\")
        return true
    DriveGet, Soort, Type, % SubStr(A_ScriptDir, 1, 3)
    return (Soort = "Network")
}

LokaleMap() {
    EnvGet, Lokaal, LOCALAPPDATA
    return Lokaal . "\Etiketten autoprinter"
}

InstalleerLokaal(Gevraagd) {
    global IniFile, AppTitel, AppVersie, EUml, DataMap
    If (!A_IsCompiled)
    {
        Melding("Installeren", "Installeren kan alleen vanuit de gecompileerde .exe.", "waarschuwing")
        return
    }
    Doel := LokaleMap()
    If (!OpNetwerk() && InStr(A_ScriptDir, Doel) = 1)
    {
        Melding("Installeren", "De app draait al vanaf deze computer:`n" . A_ScriptDir)
        return
    }
    Tekst := "De app start nu vanaf de netwerkschijf. Op deze computer installeren?`n`n"
        . Chr(8226) . " sneller opstarten, en hij werkt ook als de netwerkschijf even weg is`n"
        . Chr(8226) . " snelkoppeling op het bureaublad en in het startmenu`n"
        . Chr(8226) . " nieuwe versies in deze netwerkmap worden automatisch aangeboden`n`n"
        . "Rapporten en het register van geprinte pati" . EUml . "nten komen dan op deze computer te staan."
    If !Vraag("Op deze computer installeren?", Tekst, "Installeren", Gevraagd ? "Annuleren" : "Niet meer vragen")
    {
        If (!Gevraagd)
            IniWrite, 1, %IniFile%, Opties, LokaalNietVragen
        return
    }
    FileCreateDir, %Doel%
    FileCopy, %A_ScriptFullPath%, %Doel%\Etiketten_autoprinter.exe, 1
    If (ErrorLevel)
    {
        Melding("Installeren mislukt", "De app kon niet naar " . Doel . " gekopieerd worden.", "fout")
        return
    }
    ; Instellingen meenemen, en de netwerkmap als updatemap instellen
    If !FileExist(Doel . "\Etiketten_autoprinter.ini")
        FileCopy, %IniFile%, %Doel%\Etiketten_autoprinter.ini
    IniWrite, %A_ScriptDir%, %Doel%\Etiketten_autoprinter.ini, Update, Map
    IniWrite, %DataMap%, %Doel%\Etiketten_autoprinter.ini, Opslag, Map
    IniWrite, 1, %Doel%\Etiketten_autoprinter.ini, Opties, LokaalNietVragen
    Exe := Doel . "\Etiketten_autoprinter.exe"
    FileCreateShortcut, %Exe%, %A_Desktop%\Etiketten autoprinter.lnk, %Doel%,, Etiketten printen vanuit de aanschrijfbuffer van Pharmacom
    FileCreateShortcut, %Exe%, %A_Programs%\Etiketten autoprinter.lnk, %Doel%,, Etiketten printen vanuit de aanschrijfbuffer van Pharmacom
    Log("Lokaal ge" . Chr(239) . "nstalleerd in " . Doel)
    Melding("Ge" . Chr(239) . "nstalleerd", "De app staat nu op deze computer, met een snelkoppeling op het bureaublad en in het startmenu.`n`nDe lokale versie wordt nu gestart. Gebruik voortaan de snelkoppeling.")
    Run, "%Exe%", %Doel%
    ExitApp
}

; Kijkt of er in de updatemap een nieuwere versie staat en installeert die
; (na bevestiging). Stil = geen melding als er niets nieuws is.
ControleerUpdate(Stil) {
    global UpdateMap, AppVersie, AppTitel, Bezig
    If (Bezig || UpdateMap = "")
        return
    Nieuw := UpdateMap . "\Etiketten_autoprinter.exe"
    If !FileExist(Nieuw)
    {
        If (!Stil)
            Melding("Updates", "In de updatemap staat geen Etiketten_autoprinter.exe.", "waarschuwing")
        return
    }
    FileGetVersion, NieuweVersie, %Nieuw%
    If (VersieNummer(NieuweVersie) <= VersieNummer(AppVersie))
    {
        If (!Stil)
            Melding("Updates", "Je hebt de nieuwste versie (" . AppVersie . ").")
        return
    }
    If (!A_IsCompiled)
    {
        If (!Stil)
            Melding("Updates", "Versie " . NieuweVersie . " staat klaar, maar bijwerken kan alleen vanuit de .exe.", "waarschuwing")
        return
    }
    If !Vraag("Nieuwe versie beschikbaar", "Versie " . NieuweVersie . " staat klaar (je hebt nu " . AppVersie . ").`n`nNu bijwerken? De app wordt daarna opnieuw gestart.", "Bijwerken", "Later")
        return
    ; Eerst lokaal kopi"eren en daar de controlewaarde (gemaakt bij het
    ; publiceren) nakijken; daarna alleen die gecontroleerde kopie gebruiken.
    ; Dit vangt half gekopieerde of beschadigde bestanden af (geen bescherming
    ; tegen iemand die beide bestanden vervangt: beperk daarvoor de
    ; schrijfrechten op de updatemap).
    Nieuw := VeiligeKopie(Nieuw)
    If (Nieuw = "")
        return
    ; Een klein hulpscript vervangt de .exe zodra deze app gesloten is
    Hulp := A_Temp . "\Etiketten_autoprinter_update.cmd"
    FileDelete, %Hulp%
    FileAppend,
    (LTrim
        @echo off
        ping 127.0.0.1 -n 3 >nul
        copy /y "%Nieuw%" "%A_ScriptFullPath%" >nul
        start "" "%A_ScriptFullPath%"
        del "`%~f0"
    ), %Hulp%
    Log("Bijwerken naar versie " . NieuweVersie)
    Run, "%Hulp%",, Hide
    ExitApp
}

; Kopieert de nieuwe .exe naar de tijdelijke map en controleert die kopie
; tegen <exe>.sha256 in de updatemap. Geeft het pad van de kopie, of "".
VeiligeKopie(Bron) {
    Verwacht := ""
    FileRead, Verwacht, %Bron%.sha256
    Verwacht := Format("{:L}", Trim(Verwacht, " `t`r`n"))
    If !RegExMatch(Verwacht, "^[0-9a-f]{64}$")
    {
        Log("Update geweigerd: geen geldige controlewaarde (" . Bron . ".sha256)")
        Melding("Bijwerken niet mogelijk", "Bij de nieuwe versie in de updatemap ontbreekt de controlewaarde (Etiketten_autoprinter.exe.sha256).`n`nZet de nieuwe versie opnieuw in de updatemap via Instellingen " . Chr(8594) . " Updates " . Chr(8594) . " Deze versie in de updatemap zetten.", "waarschuwing")
        return ""
    }
    Kopie := A_Temp . "\Etiketten_autoprinter_nieuw.exe"
    FileCopy, %Bron%, %Kopie%, 1
    If (ErrorLevel || Sha256(Kopie) != Verwacht)
    {
        FileDelete, %Kopie%
        Log("Update geweigerd: controlewaarde klopt niet")
        Melding("Bijwerken niet mogelijk", "De nieuwe versie in de updatemap is onvolledig of beschadigd (de controlewaarde klopt niet). Er is niets gewijzigd.`n`nProbeer het later opnieuw, of zet de versie opnieuw in de updatemap.", "fout")
        return ""
    }
    return Kopie
}

; SHA-256 van een bestand (kleine letters), of "" bij een fout.
Sha256(Bestand) {
    static PROV_RSA_AES := 24, CALG_SHA_256 := 0x800C, CRYPT_VERIFYCONTEXT := 0xF0000000
    f := FileOpen(Bestand, "r")
    If (!IsObject(f))
        return ""
    hProv := 0, hHash := 0, Uit := ""
    If DllCall("advapi32\CryptAcquireContext", "Ptr*", hProv, "Ptr", 0, "Ptr", 0, "UInt", PROV_RSA_AES, "UInt", CRYPT_VERIFYCONTEXT)
    {
        If DllCall("advapi32\CryptCreateHash", "Ptr", hProv, "UInt", CALG_SHA_256, "Ptr", 0, "UInt", 0, "Ptr*", hHash)
        {
            VarSetCapacity(Buf, 65536)
            Ok := true
            While (Ok && !f.AtEOF)
            {
                n := f.RawRead(Buf, 65536)
                Ok := DllCall("advapi32\CryptHashData", "Ptr", hHash, "Ptr", &Buf, "UInt", n, "UInt", 0)
            }
            Lengte := 32
            VarSetCapacity(H, 32, 0)
            If (Ok && DllCall("advapi32\CryptGetHashParam", "Ptr", hHash, "UInt", 2, "Ptr", &H, "UInt*", Lengte, "UInt", 0))
                Loop, 32
                    Uit .= Format("{:02x}", NumGet(H, A_Index - 1, "UChar"))
            DllCall("advapi32\CryptDestroyHash", "Ptr", hHash)
        }
        DllCall("advapi32\CryptReleaseContext", "Ptr", hProv, "UInt", 0)
    }
    f.Close()
    return Uit
}

; "5.7.1" -> 5007001 (om versies te kunnen vergelijken). Ontbrekende delen
; tellen als 0 (in AHK v1 is "" + 0 leeg, dus expliciet afvangen).
VersieNummer(V) {
    N := 0
    D := StrSplit(V, ".")
    Loop, 3
    {
        Deel := D[A_Index]
        If Deel is not integer
            Deel := 0
        N := N * 1000 + Deel
    }
    return N
}


; =====================================================================
; Systeemvak (icoon rechtsonder bij de klok)
; =====================================================================
MaakTray:
    If (!A_IsCompiled)
    {
        If FileExist(A_ScriptDir . "\Etiketten_autoprinter.ico")
            Menu, Tray, Icon, %A_ScriptDir%\Etiketten_autoprinter.ico
        Else
            Menu, Tray, Icon, shell32.dll, 17
    }
    Menu, Tray, NoStandard
    Menu, Tray, Add, Venster tonen, ToonVenster
    Menu, Tray, Add, Start printen, StartKnop
    Menu, Tray, Add, Stoppen, StopKnop
    Menu, Tray, Add
    Menu, Tray, Add, Afsluiten, GuiClose
    Menu, Tray, Default, Venster tonen
    Menu, Tray, Tip, %AppTitel%
return
