; =====================================================================
; "Wat is er nieuw": na een update één keer de wijzigingen tonen.
; Nieuwste versie bovenaan; houd elke regel kort en voor gebruikers.
; =====================================================================

class Wijzigingen {
    static Lijst := [
        ["6.4.1", ["De knop Vernieuwen is een klein knopje (↻) boven de lijst geworden; F5 werkt nog steeds."
            , "Na een proefronde kun je meteen weer vinkjes zetten; de uitkomst blijft zichtbaar."
            , "Heeft een andere computer net geprint, dan ziet de lijst dat vanzelf binnen 30 seconden."]]
        , ["6.4.0", ["Proefronde: alles doorlopen zonder te printen (knop Proef of Ctrl+Shift+Enter)."
            , "Planning: groepen (afdelingen) automatisch laten printen op vaste dagen en tijden, met even/oneven weken."
            , "Sneltoetsen: F5 vernieuwen, Ctrl+Enter start, F1 overzicht."
            , "Instellingen per apotheek: wat er geprint wordt, geldt nu per ingelogde apotheek."
            , "Dit venster: na een update zie je wat er veranderd is."]]
        , ["6.3", ["BENU-huisstijl in groen, rustiger ontwerp en nieuw icoon."
            , "Vinkjes netjes in het midden van de vakjes."]]
        , ["6.2", ["De app controleert de aanschrijfbuffer veel zuiniger en pauzeert als hij niet nodig is."]]
        , ["6.1", ["Vraag of idee? Knop rechtsboven om Ronald te mailen of een Teams-bericht te sturen."
            , "Nieuwe iconen."]]
        , ["6.0", ["Nieuwe techniek onder de motorkap: sneller en betrouwbaarder selecteren in Pharmacom."]]
        , ["5.8", ["Na een fout zet de app Pharmacom zelf terug op de aanschrijfbuffer.", "Veiligere updates."]]
        , ["5.7.3", ["Het afdrukmenu wordt nu echt gecontroleerd voordat er geprint wordt."]]]

    ; Bij het starten: toon wat er nieuw is sinds de laatst geziene versie.
    ; Bij een eerste installatie alleen onthouden, niets tonen.
    static BijStart() {
        Gezien := Inst.Lees1("App", "LaatstGezien", "")
        Inst.Schrijf(AppVersie, "App", "LaatstGezien")
        if Gezien = "" || VersieNummer(Gezien) >= VersieNummer(AppVersie)
            return
        Tekst := this.Tekst(Gezien)
        if Tekst != ""
            Venster.Keuze("Wat is er nieuw in " AppVersie, Tekst, [{t: "Fijn!", v: "1", hoofd: 1}], "nieuw")
    }

    ; Alle wijzigingen tonen (vanuit het Over-venster)
    static Toon(*) => Venster.Keuze("Wat is er nieuw", this.Tekst("0", 99), [{t: "Sluiten", v: "1", hoofd: 1}], "nieuw")

    ; Wijzigingen van versies nieuwer dan Sinds (maximaal Max versies)
    static Tekst(Sinds, Max := 4) {
        Tekst := "", n := 0
        for v in this.Lijst {
            if VersieNummer(v[1]) <= VersieNummer(Sinds)
                continue
            if ++n > Max
                break
            Tekst .= (Tekst = "" ? "" : "`n") "Versie " v[1] "`n"
            for r in v[2]
                Tekst .= Teken.Punt " " r "`n"
        }
        return RTrim(Tekst, "`n")
    }
}
