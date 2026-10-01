; =====================================================================
; Updates en lokaal installeren
;
; Publiceren zet de .exe met een controlewaarde (.sha256) in de updatemap.
; Bijwerken kopieert eerst naar de tijdelijke map en installeert alleen als
; de controlewaarde klopt (vangt half gekopieerde of beschadigde bestanden
; af; beperk de schrijfrechten op de updatemap tegen kwaadwillenden).
; =====================================================================

; Starten met Windows: snelkoppeling in de map Opstarten van de gebruiker
class Opstart {
    static Snelkoppeling => A_Startup "\Etiketten autoprinter.lnk"

    static Aan() => FileExist(this.Snelkoppeling) != ""

    static Zet(Aan) {
        if Aan {
            if !A_IsCompiled
                return Venster.Melding("Starten met Windows", "Dit kan alleen vanuit de gecompileerde .exe.", "waarschuwing")
            try {
                FileCreateShortcut A_ScriptFullPath, this.Snelkoppeling, A_ScriptDir, , "Etiketten printen vanuit de aanschrijfbuffer van Pharmacom"
                Log("Starten met Windows: aan (" A_ScriptFullPath ")")
            } catch as e
                Venster.Melding("Starten met Windows", "De snelkoppeling kon niet gemaakt worden: " e.Message, "fout")
        } else {
            try FileDelete this.Snelkoppeling
            Log("Starten met Windows: uit")
        }
    }
}

class Update {
    static ExeNaam := "Etiketten_autoprinter.exe"

    static Publiceer() {
        Doel := Inst.UpdateMap
        if Doel = "" || !InStr(FileExist(Doel), "D")
            return Venster.Melding("Updates", "Kies eerst een bestaande updatemap.", "waarschuwing")
        if !A_IsCompiled
            return Venster.Melding("Updates", "Dit kan alleen vanuit de gecompileerde .exe.", "waarschuwing")
        Exe := Doel "\" this.ExeNaam
        ; Eerst de controlewaarde weghalen: zo installeert niemand een half
        ; gekopieerde .exe terwijl het kopi"eren nog bezig is
        try FileDelete Exe ".sha256"
        Hash := ""
        try {
            FileCopy A_ScriptFullPath, Exe, 1
            Hash := Sha256(A_ScriptFullPath)
            if Hash != "" && Sha256(Exe) = Hash
                FileAppend Hash, Exe ".sha256", "UTF-8-RAW"
        }
        if Hash = "" || !FileExist(Exe ".sha256")
            return Venster.Melding("Updates", "Kopi" Teken.EUml "ren naar de updatemap is mislukt.", "fout")
        Log("Versie " AppVersie " in de updatemap gezet")
        Venster.Melding("Updates", "Versie " AppVersie " staat nu in de updatemap. Andere computers krijgen de update bij de volgende start.")
    }

    ; Kijkt of er in de updatemap een nieuwere versie staat en installeert die
    ; (na bevestiging). Stil = geen melding als er niets nieuws is.
    static Controleer(Stil) {
        if Ronde.Bezig || Inst.UpdateMap = ""
            return
        Nieuw := Inst.UpdateMap "\" this.ExeNaam
        if !FileExist(Nieuw) {
            if !Stil
                Venster.Melding("Updates", "In de updatemap staat geen " this.ExeNaam ".", "waarschuwing")
            return
        }
        try NieuweVersie := FileGetVersion(Nieuw)
        catch
            NieuweVersie := ""
        if VersieNummer(NieuweVersie) <= VersieNummer(AppVersie) {
            if !Stil
                Venster.Melding("Updates", "Je hebt de nieuwste versie (" AppVersie ").")
            return
        }
        if !A_IsCompiled {
            if !Stil
                Venster.Melding("Updates", "Versie " NieuweVersie " staat klaar, maar bijwerken kan alleen vanuit de .exe.", "waarschuwing")
            return
        }
        if !Venster.Vraag("Nieuwe versie beschikbaar", "Versie " NieuweVersie " staat klaar (je hebt nu " AppVersie ").`n`nNu bijwerken? De app wordt daarna opnieuw gestart.", "Bijwerken", "Later")
            return
        Kopie := this.VeiligeKopie(Nieuw)
        if Kopie = ""
            return
        ; Een klein hulpscript vervangt de .exe zodra deze app gesloten is
        Hulp := A_Temp "\Etiketten_autoprinter_update.cmd"
        try FileDelete Hulp
        FileAppend "@echo off`r`nping 127.0.0.1 -n 3 >nul`r`ncopy /y `"" Kopie "`" `"" A_ScriptFullPath "`" >nul`r`nstart `"`" `"" A_ScriptFullPath "`"`r`ndel `"%~f0`"`r`n", Hulp, "CP0"
        Log("Bijwerken naar versie " NieuweVersie)
        Run '"' Hulp '"', , "Hide"
        ExitApp
    }

    ; Kopieert de nieuwe .exe naar de tijdelijke map en controleert die kopie
    ; tegen <exe>.sha256 in de updatemap. Geeft het pad van de kopie, of "".
    static VeiligeKopie(Bron) {
        try Verwacht := StrLower(Trim(FileRead(Bron ".sha256"), " `t`r`n"))
        catch
            Verwacht := ""
        if !RegExMatch(Verwacht, "^[0-9a-f]{64}$") {
            Log("Update geweigerd: geen geldige controlewaarde (" Bron ".sha256)")
            Venster.Melding("Bijwerken niet mogelijk", "Bij de nieuwe versie in de updatemap ontbreekt de controlewaarde (" this.ExeNaam ".sha256).`n`nZet de nieuwe versie opnieuw in de updatemap via Instellingen " Teken.Pijl " Updates " Teken.Pijl " Deze versie in de updatemap zetten.", "waarschuwing")
            return ""
        }
        Kopie := A_Temp "\Etiketten_autoprinter_nieuw.exe"
        Ok := false
        try {
            FileCopy Bron, Kopie, 1
            Ok := Sha256(Kopie) = Verwacht
        }
        if !Ok {
            try FileDelete Kopie
            Log("Update geweigerd: controlewaarde klopt niet")
            Venster.Melding("Bijwerken niet mogelijk", "De nieuwe versie in de updatemap is onvolledig of beschadigd (de controlewaarde klopt niet). Er is niets gewijzigd.`n`nProbeer het later opnieuw, of zet de versie opnieuw in de updatemap.", "fout")
            return ""
        }
        return Kopie
    }

    ; --- Lokaal installeren ----------------------------------------------------
    ; Vanaf de netwerkschijf starten is trager en werkt niet als de schijf even
    ; weg is. De app biedt aan zichzelf naar deze computer te kopi"eren (met
    ; snelkoppelingen); de netwerkmap wordt dan de updatemap.
    static OpNetwerk() {
        if SubStr(A_ScriptDir, 1, 2) = "\\"
            return true
        try return DriveGetType(SubStr(A_ScriptDir, 1, 3)) = "Network"
        return false
    }

    static LokaleMap => EnvGet("LOCALAPPDATA") "\Etiketten autoprinter"

    static ControleerLokaal() {
        if Ronde.Bezig || !A_IsCompiled || !this.OpNetwerk()
            return
        if Inst.Getal(Inst.Lees1("Opties", "LokaalNietVragen", 0), 0)
            return
        this.InstalleerLokaal(false)
    }

    static InstalleerLokaal(Gevraagd) {
        if !A_IsCompiled
            return Venster.Melding("Installeren", "Installeren kan alleen vanuit de gecompileerde .exe.", "waarschuwing")
        Doel := this.LokaleMap
        if !this.OpNetwerk() && InStr(A_ScriptDir, Doel) = 1
            return Venster.Melding("Installeren", "De app draait al vanaf deze computer:`n" A_ScriptDir)
        Tekst := "De app start nu vanaf de netwerkschijf. Op deze computer installeren?`n`n"
            . Teken.Punt " sneller opstarten, en hij werkt ook als de netwerkschijf even weg is`n"
            . Teken.Punt " snelkoppeling op het bureaublad en in het startmenu`n"
            . Teken.Punt " nieuwe versies in deze netwerkmap worden automatisch aangeboden`n`n"
            . "Rapporten en het register van geprinte pati" Teken.EUml "nten blijven in de netwerkmap."
        if !Venster.Vraag("Op deze computer installeren?", Tekst, "Installeren", Gevraagd ? "Annuleren" : "Niet meer vragen") {
            if !Gevraagd
                Inst.Schrijf(1, "Opties", "LokaalNietVragen")
            return
        }
        Exe := Doel "\" this.ExeNaam
        try {
            DirCreate Doel
            FileCopy A_ScriptFullPath, Exe, 1
        } catch {
            return Venster.Melding("Installeren mislukt", "De app kon niet naar " Doel " gekopieerd worden.", "fout")
        }
        ; Instellingen meenemen, en de netwerkmap als updatemap instellen
        Ini := Doel "\Etiketten_autoprinter.ini"
        if !FileExist(Ini)
            try FileCopy Inst.Bestand, Ini
        IniWrite A_ScriptDir, Ini, "Update", "Map"
        IniWrite (InStr(FileExist(Inst.DataMap), "D") ? Inst.DataMap : A_ScriptDir), Ini, "Opslag", "Map"
        IniWrite 1, Ini, "Opties", "LokaalNietVragen"
        FileCreateShortcut Exe, A_Desktop "\Etiketten autoprinter.lnk", Doel, , "Etiketten printen vanuit de aanschrijfbuffer van Pharmacom"
        FileCreateShortcut Exe, A_Programs "\Etiketten autoprinter.lnk", Doel, , "Etiketten printen vanuit de aanschrijfbuffer van Pharmacom"
        Log("Lokaal ge" Teken.IUml "nstalleerd in " Doel)
        Venster.Melding("Ge" Teken.IUml "nstalleerd", "De app staat nu op deze computer, met een snelkoppeling op het bureaublad en in het startmenu.`n`nDe lokale versie wordt nu gestart. Gebruik voortaan de snelkoppeling.")
        Run '"' Exe '"', Doel
        ExitApp
    }
}
