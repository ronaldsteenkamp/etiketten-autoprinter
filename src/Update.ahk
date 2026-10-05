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

    ; GitHub-repository met releases ("eigenaar/naam"): AppGitHub in de app,
    ; of [Update] GitHub= in de ini. Leeg = alleen de updatemap.
    static GitHub => Trim(Inst.Lees1("Update", "GitHub", AppGitHub))

    ; Kijkt of er een nieuwere versie is en installeert die (na bevestiging).
    ; GitHub is de eerste bron: de nieuwste release daar telt. Alleen als
    ; GitHub niet bereikbaar is (of niet ingesteld), kijkt de app in de
    ; updatemap (netwerkmap). Stil = geen melding als er niets nieuws is.
    static Controleer(Stil) {
        if Ronde.Bezig || Inst.Test
            return
        Nieuw := "", NieuweVersie := "", Release := "", GitHubWeg := false
        ; Draait de app vanaf de netwerkmap zelf, dan niet van GitHub bijwerken:
        ; dat zou de .exe in de gedeelde map vervangen zonder controlewaarde,
        ; en dan weigeren de lokaal geïnstalleerde computers de update. Die map
        ; werkt de beheerder bij (maak_release.ps1 + kopiëren).
        VanafMap := this.OpNetwerk() && (Inst.UpdateMap = "" || Inst.UpdateMap = A_ScriptDir)
        if this.GitHub != "" && !VanafMap {
            Release := this.GitHubNieuwste()
            GitHubWeg := !IsObject(Release)
            if IsObject(Release) && VersieNummer(Release.versie) > VersieNummer(AppVersie)
                NieuweVersie := Release.versie
            else
                Release := ""
        }
        ; Reserve: de netwerkmap, als GitHub niet bereikbaar of niet ingesteld is
        if (GitHubWeg || this.GitHub = "") && Inst.UpdateMap != "" && FileExist(Inst.UpdateMap "\" this.ExeNaam) {
            try v := FileGetVersion(Inst.UpdateMap "\" this.ExeNaam)
            catch
                v := ""
            if VersieNummer(v) > VersieNummer(AppVersie)
                Nieuw := Inst.UpdateMap "\" this.ExeNaam, NieuweVersie := v
        }
        ; Uitkomst onthouden (Instellingen toont wanneer en wat)
        this.ZetGekeken(IsObject(Release) ? "versie " NieuweVersie " staat klaar op GitHub"
            : Nieuw != "" ? "versie " NieuweVersie " staat klaar in de netwerkmap" (GitHubWeg ? " (GitHub niet bereikbaar)" : "")
            : GitHubWeg ? "GitHub niet bereikbaar; in de netwerkmap niets nieuwers"
            : "je hebt de nieuwste versie")
        if GitHubWeg && !Stil && Nieuw = ""
            return Venster.Melding("Updates", "GitHub (" this.GitHub ") was niet bereikbaar of heeft geen release met " this.ExeNaam " en " this.ExeNaam ".sha256." (Inst.UpdateMap != "" ? "`n`nIn de netwerkmap staat ook geen nieuwere versie." : ""), "waarschuwing")
        if Nieuw = "" && !IsObject(Release) {
            if !Stil
                Venster.Melding("Updates", VanafMap ? "De app start vanaf de netwerkmap (" A_ScriptDir "): na een herstart heb je altijd de versie die daar staat (nu " AppVersie ")."
                    : Inst.UpdateMap = "" && this.GitHub = "" ? "Er is geen updatemap of GitHub ingesteld." : "Je hebt de nieuwste versie (" AppVersie ").")
            return
        }
        if !A_IsCompiled {
            if !Stil
                Venster.Melding("Updates", "Versie " NieuweVersie " staat klaar, maar bijwerken kan alleen vanuit de .exe.", "waarschuwing")
            return
        }
        Waar := IsObject(Release) ? " op GitHub" : ""
        if !Venster.Vraag("Nieuwe versie beschikbaar", "Versie " NieuweVersie " staat klaar" Waar " (je hebt nu " AppVersie ").`n`nNu bijwerken? De app wordt daarna opnieuw gestart.", "Bijwerken", "Later")
            return
        if IsObject(Release) {
            Nieuw := this.GitHubDownload(Release)
            if Nieuw = ""
                return Venster.Melding("Bijwerken niet mogelijk", "De nieuwe versie kon niet van GitHub gedownload worden. Er is niets gewijzigd.`n`nProbeer het later opnieuw.", "fout")
        }
        Kopie := this.VeiligeKopie(Nieuw)
        if Kopie = ""
            return
        ; Een klein hulpscript vervangt de .exe zodra deze app gesloten is. Het
        ; afsluiten kan even duren (het venster, de waakhond): zolang de .exe
        ; nog in gebruik is, mislukt het kopiëren; dan elke seconde opnieuw,
        ; tot 30 keer. (Eerst wachtte hij vast 2 s, en startte bij een
        ; mislukte kopie gewoon de oude versie weer.)
        Hulp := A_Temp "\Etiketten_autoprinter_update.cmd"
        try FileDelete Hulp
        FileAppend "@echo off`r`nset n=0`r`n:opnieuw`r`nping 127.0.0.1 -n 2 >nul`r`nset /a n+=1`r`n"
            . "copy /y `"" Kopie "`" `"" A_ScriptFullPath "`" >nul 2>&1`r`n"
            . "if errorlevel 1 if %n% lss 30 goto opnieuw`r`n"
            . "start `"`" `"" A_ScriptFullPath "`"`r`ndel `"%~f0`"`r`n", Hulp, "CP0"
        Log("Bijwerken naar versie " NieuweVersie)
        Run '"' Hulp '"', , "Hide"
        ExitApp
    }

    ; Wanneer de app voor het laatst naar updates keek, en met welke uitkomst
    ; (in de toestand van deze computer)
    static ZetGekeken(Tekst) => Staat.Schrijf(SubStr(A_Now, 1, 12) "|" Tekst, "App", "Updates")

    static LaatstGekeken() {
        d := StrSplit(Staat.Lees("App", "Updates", ""), "|", , 2)
        return d.Length = 2 && StrLen(d[1]) = 12 ? FormatTime(d[1] "00", "ddd d-M HH:mm") ": " d[2] : ""
    }

    ; --- GitHub ------------------------------------------------------------------
    ; Nieuwste release: {versie, exe, sha} (download-adressen), of "" als GitHub
    ; niet bereikbaar is of de release de twee bestanden niet heeft. Download
    ; gebruikt de proxy-instellingen van Windows.
    static GitHubNieuwste() {
        Json := A_Temp "\Etiketten_autoprinter_release.json"
        try {
            try FileDelete Json
            ; ?t=... voorkomt een oud antwoord uit de cache van Windows
            Download "https://api.github.com/repos/" this.GitHub "/releases/latest?t=" A_TickCount, Json
            J := FileRead(Json, "UTF-8")
        } catch as e {
            Log("GitHub niet bereikbaar (" this.GitHub "): " e.Message)
            return ""
        }
        R := this.LeesRelease(J)
        if !IsObject(R)
            Log("GitHub: geen bruikbare release (" this.GitHub ")")
        return R
    }

    ; Uit het antwoord van GitHub (JSON): {versie, exe, sha} of ""
    static LeesRelease(J) {
        if !RegExMatch(J, '"tag_name"\s*:\s*"v?(\d+(?:\.\d+){0,3})"', &T)
            return ""
        Exe := "", Sha := "", Pos := 1
        while Pos := RegExMatch(J, '"browser_download_url"\s*:\s*"([^"]+)"', &U, Pos) {
            if RegExMatch(U[1], "i)/\Q" this.ExeNaam "\E$")
                Exe := U[1]
            else if RegExMatch(U[1], "i)/\Q" this.ExeNaam ".sha256\E$")
                Sha := U[1]
            Pos += U.Len
        }
        return Exe != "" && Sha != "" ? {versie: T[1], exe: Exe, sha: Sha} : ""
    }

    ; Downloadt de .exe en de controlewaarde naar een eigen tijdelijke map.
    ; Geeft het pad van de .exe (met .sha256 ernaast voor VeiligeKopie) of "".
    static GitHubDownload(R) {
        Map_ := A_Temp "\Etiketten autoprinter download"
        Exe := Map_ "\" this.ExeNaam
        try {
            DirCreate Map_
            try FileDelete Exe
            try FileDelete Exe ".sha256"
            Download R.sha, Exe ".sha256"
            Download R.exe, Exe
            Log("Versie " R.versie " gedownload van GitHub")
            return Exe
        } catch as e {
            Log("Downloaden van GitHub mislukt: " e.Message)
            return ""
        }
    }

    ; Kopieert de nieuwe .exe naar de tijdelijke map en controleert die kopie
    ; tegen <exe>.sha256 ernaast. Geeft het pad van de kopie, of "".
    static VeiligeKopie(Bron) {
        try Verwacht := StrLower(Trim(FileRead(Bron ".sha256"), " `t`r`n"))
        catch
            Verwacht := ""
        ; Alleen de eerste 64 tekens (sha256sum zet er soms " bestandsnaam" achter)
        Verwacht := SubStr(Verwacht, 1, 64)
        if !RegExMatch(Verwacht, "^[0-9a-f]{64}$") {
            Log("Update geweigerd: geen geldige controlewaarde (" Bron ".sha256)")
            Venster.Melding("Bijwerken niet mogelijk", "Bij de nieuwe versie in de updatemap ontbreekt de controlewaarde (" this.ExeNaam ".sha256).`n`nVraag de beheerder de nieuwe versie opnieuw in de netwerkmap te zetten, met de controlewaarde erbij.", "waarschuwing")
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

    ; "Niet meer vragen" geldt per computer (de ini in de netwerkmap is gedeeld)
    static NietVragenSleutel => "LokaalNietVragen " A_ComputerName

    ; Net gedownload (bijv. van GitHub) en gestart vanuit Downloads of het
    ; bureaublad: dan ook aanbieden om te installeren
    static UitDownloads() {
        for m in [EnvGet("USERPROFILE") "\Downloads", A_Desktop]
            if InStr(A_ScriptDir, m) = 1
                return true
        return false
    }

    static ControleerLokaal() {
        if Ronde.Bezig || !A_IsCompiled || Inst.Test || !(this.OpNetwerk() || this.UitDownloads())
            return
        if Inst.Getal(Inst.Lees1("Opties", this.NietVragenSleutel, 0), 0)
            return
        this.InstalleerLokaal(false)
    }

    static InstalleerLokaal(Gevraagd) {
        if !A_IsCompiled
            return Venster.Melding("Installeren", "Installeren kan alleen vanuit de gecompileerde .exe.", "waarschuwing")
        Doel := this.LokaleMap
        if !this.OpNetwerk() && InStr(A_ScriptDir, Doel) = 1
            return Venster.Melding("Installeren", "De app draait al vanaf deze computer:`n" A_ScriptDir)
        Netwerk := this.OpNetwerk()
        Tekst := Netwerk
            ? "De app start nu vanaf de netwerkschijf. Op deze computer installeren?`n`n"
            . Teken.Punt " geen beveiligingswaarschuwing van Windows meer bij het starten`n"
            . Teken.Punt " sneller opstarten, en hij werkt ook als de netwerkschijf even weg is`n"
            . Teken.Punt " snelkoppeling op het bureaublad en in het startmenu`n"
            . Teken.Punt " nieuwe versies in deze netwerkmap worden automatisch aangeboden`n`n"
            . "De planning, de instellingen, de rapporten en het register van geprinte pati" Teken.EUml "nten blijven in de netwerkmap (gedeeld met de andere computers)."
            : "De app start nu vanuit " A_ScriptDir ". Op deze computer installeren?`n`n"
            . Teken.Punt " vaste plek (" Doel ")`n"
            . Teken.Punt " snelkoppeling op het bureaublad en in het startmenu`n"
            . (this.GitHub != "" ? Teken.Punt " nieuwe versies op GitHub worden automatisch aangeboden`n" : "")
            . "`nDaarna kun je het gedownloade bestand weggooien."
        if !Venster.Vraag("Op deze computer installeren?", Tekst, "Installeren", Gevraagd ? "Annuleren" : "Niet meer vragen") {
            if !Gevraagd
                Inst.Schrijf(1, "Opties", this.NietVragenSleutel)
            return
        }
        Exe := Doel "\" this.ExeNaam
        try {
            DirCreate Doel
            FileCopy A_ScriptFullPath, Exe, 1
        } catch {
            return Venster.Melding("Installeren mislukt", "De app kon niet naar " Doel " gekopieerd worden.", "fout")
        }
        ; De eigen ini bevat alleen de netwerkmap (updates en gedeelde ini) en
        ; de opslagmap; de rest leest de lokale app uit de gedeelde ini
        Ini := Doel "\Etiketten_autoprinter.ini"
        if Netwerk {
            IniWrite A_ScriptDir, Ini, "Update", "Map"
            IniWrite (InStr(FileExist(Inst.DataMap), "D") ? Inst.DataMap : A_ScriptDir), Ini, "Opslag", "Map"
        } else {
            ; Gedownload: geen netwerkmap; instellingen meenemen, gegevens in
            ; de nieuwe map, updates via GitHub
            if !FileExist(Ini) && FileExist(Inst.Bestand)
                try FileCopy Inst.Bestand, Ini
            IniWrite Doel, Ini, "Opslag", "Map"
        }
        FileCreateShortcut Exe, A_Desktop "\Etiketten autoprinter.lnk", Doel, , "Etiketten printen vanuit de aanschrijfbuffer van Pharmacom"
        FileCreateShortcut Exe, A_Programs "\Etiketten autoprinter.lnk", Doel, , "Etiketten printen vanuit de aanschrijfbuffer van Pharmacom"
        ; Starten met Windows voortaan de lokale versie
        if Opstart.Aan()
            FileCreateShortcut Exe, Opstart.Snelkoppeling, Doel, , "Etiketten printen vanuit de aanschrijfbuffer van Pharmacom"
        Log("Lokaal ge" Teken.IUml "nstalleerd in " Doel)
        Venster.Melding("Ge" Teken.IUml "nstalleerd", "De app staat nu op deze computer, met een snelkoppeling op het bureaublad en in het startmenu.`n`nDe lokale versie wordt nu gestart. Gebruik voortaan de snelkoppeling.")
        Run '"' Exe '"', Doel
        ExitApp
    }
}
