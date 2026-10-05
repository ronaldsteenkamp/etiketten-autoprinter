; =====================================================================
; "Wat is er nieuw": na een update één keer de wijzigingen tonen.
; Nieuwste versie bovenaan; houd elke regel kort en voor gebruikers.
; =====================================================================

class Wijzigingen {
    static Lijst := [
        ["6.10.2", ["Instellingen: 'Netwerkmap en updates' legt uit waar de planning gedeeld wordt en laat zien wanneer de app het laatst naar updates keek."
            , "De knop 'Deze versie in de updatemap zetten' is weg uit Instellingen (alleen voor de beheerder)."]]
        , ["6.10.1", ["Het venster staat alleen nog bovenop tijdens het printen, zodat je Pharmacom gewoon ziet als de app niets doet. Wil je hem toch altijd bovenop, zet dan in Instellingen 'Venster altijd bovenop' aan."]]
        , ["6.10.0", ["Updates ook via GitHub: staat er geen nieuwere versie in de updatemap, dan kijkt de app bij de nieuwste release op GitHub."
            , "Gedownload en gestart vanuit Downloads of het bureaublad: de app biedt aan zich op de computer te installeren."]]
        , ["6.9.1", ["Bijwerken: wacht nu tot de app echt gesloten is (eerst startte soms gewoon de oude versie weer)."]]
        , ["6.9.0", ["Geplande ronde: stopt hij door een hapering, dan gaat de app zelf verder (tot 3 keer). Stopt hij twee keer bij dezelfde patiënt, dan wordt die overgeslagen."
            , "Planning: een combinatie van instelling en afdeling die niet bestaat, kan niet meer opgeslagen worden en wordt in de lijst als fout getoond."
            , "Lege groep: de melding 'Geen patiënten gevonden' van Pharmacom wordt nu zelf gesloten (bleef eerst openstaan, waardoor de volgende planning wachtte)."
            , "Logbestanden van alle computers staan nu samen in de netwerkmap."
            , "Instellingen: overzicht van de computers met hun versie en wanneer de app er het laatst draaide."
            , "Diagnose: hoe vaak elke foutcode de afgelopen 30 dagen voorkwam."
            , "Gegevens die vaak veranderen staan per computer in een eigen bestand (Gegevens\Computers), zodat computers elkaars wijzigingen niet overschrijven."]]
        , ["6.8.1", ["Op deze computer installeren: geen beveiligingswaarschuwing van Windows meer bij het starten. De planning en instellingen blijven gedeeld in de netwerkmap."
            , "'Niet meer vragen' bij installeren geldt nu per computer."]]
        , ["6.8.0", ["De app draait nooit meer twee keer tegelijk (ook niet als hij via de netwerkmap en via de stationsletter gestart wordt)."
            , "Planning: een minuut voor de geplande tijd controleert de app of de ronde kan starten, en waarschuwt meteen als dat niet zo is."
            , "Planning: de app onthoudt de apotheek, zodat een planning ook draait als Pharmacom die bij het opstarten nog niet laat zien."
            , "Planning: opent de aanschrijfbuffer ook als Pharmacom op een scherm staat waarvan de naam niet in de titel staat."
            , "Elke fout heeft een vaste code (bijv. [P11]) in de melding, het logbestand en het rapport; de lijst staat in de LEESMIJ."
            , "Nieuwe optie: Pharmacom terughalen als een ander venster ervoor springt (standaard uit)."
            , "Sluit Pharmacom tijdens het printen af, dan stopt de ronde meteen."
            , "Instelling en Afdeling worden direct ingevuld via de koppeling met Pharmacom (zonder klikken en typen)."]]
        , ["6.7.0", ["Planning: de aanschrijfbuffer hoeft niet open te staan; de app opent hem zelf."
            , "Planning: staat de computer op slot of is Pharmacom bezet, dan wacht de geplande ronde (tot 2 uur) en start hij zodra het kan."
            , "Rond een geplande tijd en tijdens het printen gaat de computer niet in slaapstand."
            , "Waakhond: loopt de app vast tijdens het printen, dan wordt hij na 20 seconden afgesloten, zodat toetsenbord en muis weer vrij zijn."]]
        , ["6.6.0", ["Veiliger: gaat er onverwacht iets mis, dan stopt de app de ronde netjes, maakt toetsenbord en muis vrij en meldt wat er gebeurde."
            , "Instellingen: 'Starten met Windows', zodat de planning altijd draait."
            , "Planning: per planning zie je of de laatste ronde gelukt, mislukt, geannuleerd of niet uitgevoerd is; gemiste rondes worden gemeld."]]
        , ["6.5.3", ["Planning: kies je een andere instelling, dan wordt de afdeling leeggemaakt als die er niet bij hoort."]]
        , ["6.5.2", ["Planning: elke groep kan maar één keer gepland worden; al geplande afdelingen staan grijs in de lijst."
            , "Planning: de naam is altijd de naam van de groep."
            , "Planning: nieuw veld Opmerking."]]
        , ["6.5.1", ["Planning: regels slepen om de volgorde te veranderen."
            , "De knop 'Overnemen uit Pharmacom' is vervallen; kies de groep uit de lijst."]]
        , ["6.5.0", ["Planning: volgorde zelf aanpassen met de pijltjes, of sorteren op naam (A–Z)."
            , "Planning: Instelling en Afdeling kiezen uit een lijst (of typen). Met 'Alle groepen ophalen' haalt de app de lijst uit Pharmacom."]]
        , ["6.4.2", ["De knop Stop werkt nu ook tijdens het printen (muisklikken op dit venster worden niet meer geblokkeerd)."
            , "Na Stop of Esc zet de app Pharmacom terug op de aanschrijfbuffer, zodat Doorgaan meteen werkt."]]
        , ["6.4.1", ["De knop Vernieuwen is een klein knopje (↻) boven de lijst geworden; F5 werkt nog steeds."
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
