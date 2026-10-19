"""
pytest voor de Python-port (etiketten_logica.py).

Drie soorten tests:
  1. Overeenkomst met de bestaande AHK-tests (tests/Eenheid.ahk, tests/Planning.ahk,
     tests/Update.ahk): bewijst dat de port hetzelfde rekent als de app.
  2. Randgevallen die de review heeft onderzocht (huidig gedrag vastgelegd).
  3. Gewenst gedrag bij een bevinding: gemarkeerd met xfail(strict=True) en het ID uit
     review/REVIEW.md. Zodra de app (en deze port) verbeterd is, slaagt de test en
     faalt xfail -> markering weghalen.

Draaien:  python -m pytest review/tests_voorstel -q
"""
import pytest

from etiketten_logica import (
    Planregel, csv_regel, csv_veilig, datediff_days, dossier_bevestigd, gemist, is_datum,
    kies_regel, lees_apotheek, lees_release, momenten, nu_aan, rapport_bestand,
    register_bestand, seconden_tot, soort, titel_is_buffer, tweewekelijks_klopt,
    verwachte_sha, versie_nummer, week_klopt, week_nr, weekdag, wordt_opgeruimd, MAX_UITSTEL,
)


def It(**kw):
    it = Planregel()
    for k, v in kw.items():
        setattr(it, k, v)
    return it


# --- 1. Gelijk aan de AHK-tests -------------------------------------------------

class TestZoalsAhk:
    def test_versies(self):
        assert versie_nummer("6.0.0") > versie_nummer("5.8.0")
        assert versie_nummer("5.10.0") > versie_nummer("5.9.9")
        assert versie_nummer("") == 0
        assert versie_nummer("5.8.1.0") == 5008001
        assert versie_nummer("6.13") > versie_nummer("6.12.0")
        assert versie_nummer("6.13") == versie_nummer("6.13.0.0")
        assert versie_nummer("6.14") > versie_nummer("6.13")

    def test_datum_en_titel(self):
        assert is_datum("25-08-1963") and is_datum("5-8-63") and is_datum("1963-08-25")
        assert not is_datum("onbekend")
        assert titel_is_buffer("Pharmacom - Aanschrijfbuffer")
        assert not titel_is_buffer("Pharmacom - Apotheek dashboard")
        assert titel_is_buffer("Pharmacom")

    def test_weken_en_dagen(self):
        assert weekdag("20261001120000") == 4
        assert weekdag("20261004120000") == 7
        assert weekdag("20261005120000") == 1
        assert week_nr("20261001") == 40
        assert week_nr("20261231") == 53
        assert week_nr("20270104") == 1
        assert week_klopt("even", "20261001") and not week_klopt("oneven", "20261001")

    @pytest.mark.parametrize("nu,laatst,verwacht", [
        ("20261001080000", "", True), ("20261001081400", "", True), ("20261001081500", "", False),
        ("20261001075900", "", False), ("20261001075959", "", False), ("20261001081459", "", True),
        ("20261001080500", "202610010800", False), ("20261001080500", "202609300800", True),
    ])
    def test_nu_aan(self, nu, laatst, verwacht):
        assert nu_aan(It(), nu, laatst) is verwacht

    def test_nu_aan_overig(self):
        assert not nu_aan(It(dagen="1235"), "20261001080500", "")
        assert not nu_aan(It(weken="oneven"), "20261001080500", "")
        assert not nu_aan(It(aan=0), "20261001080500", "")
        assert not nu_aan(It(computer="ANDERE-PC"), "20261001080500", "")
        assert nu_aan(It(tijd="7:30"), "20261001073200", "")
        assert nu_aan(It(), "20261001093000", "", max_min=MAX_UITSTEL)
        assert not nu_aan(It(), "20261001100000", "", max_min=MAX_UITSTEL)

    def test_momenten_en_gemist(self):
        ma = It(dagen="1", weken="alle")
        assert momenten(ma, "20261001000000", "20261013000000") == ["20261005080000", "20261012080000"]
        assert momenten(It(dagen="1", weken="even"), "20261001000000", "20261013000000") == ["20261012080000"]
        assert momenten(ma, "20261005080000", "20261005090000") == []
        assert len(momenten(ma, "20261005070000", "20261005080000")) == 1
        assert len(gemist(ma, "20261004120000", "20261012081500", "")) == 2
        assert len(gemist(ma, "20261004120000", "20261012081500", "202610050801")) == 1

    def test_seconden_tot(self):
        assert seconden_tot(It(), "20261001075900") == 60
        assert seconden_tot(It(), "20261001080030") == -30
        assert seconden_tot(It(dagen="1"), "20261001075900") == ""

    def test_release(self):
        j = '''{"tag_name": "v6.10.0", "assets": [
          {"browser_download_url": "https://github.com/v/e/releases/download/v6.10.0/Etiketten_autoprinter.exe.sha256"},
          {"browser_download_url": "https://github.com/v/e/releases/download/v6.10.0/Etiketten_autoprinter.exe"}]}'''
        r = lees_release(j)
        assert r and r["versie"] == "6.10.0" and r["exe"].endswith(".exe") and r["sha"].endswith(".sha256")
        assert lees_release(j.replace("Etiketten_autoprinter.exe.sha256", "iets.txt")) is None
        assert lees_release('{"message":"Not Found"}') is None


# --- 2. Randgevallen (huidig gedrag) -------------------------------------------

class TestRandgevallen:
    def test_week53_twee_oneven_weken_achter_elkaar(self):
        """H4: 28-12-2026 (week 53) en 4-1-2027 (week 1) zijn allebei oneven."""
        assert week_nr("20261228") == 53 and week_nr("20270104") == 1
        assert week_klopt("oneven", "20261228") and week_klopt("oneven", "20270104")
        # 'even': week 52 (21-12) en daarna pas week 2 (11-1): drie weken ertussen
        assert week_klopt("even", "20261221") and not week_klopt("even", "20261228")
        assert not week_klopt("even", "20270104") and week_klopt("even", "20270111")

    def test_week53_komt_vaker_voor(self):
        jaren = [j for j in range(2020, 2040) if week_nr(f"{j}1228") == 53]
        assert jaren == [2020, 2026, 2032, 2037]

    def test_ongeldige_tijd_geeft_fout(self):
        """L1: tijd 25:00 uit de ini -> DateDiff-fout (in de app elke 20 s via de planningtimer)."""
        with pytest.raises(ValueError):
            nu_aan(It(dagen="1234567", weken="alle", tijd="25:00"), "20261015120000", "")

    def test_zomertijd(self):
        """L2: 02:30 op 29-03-2026 bestaat niet; om 03:00 is het al 30 min 'voorbij'."""
        it = It(dagen="7", weken="alle", tijd="02:30")
        assert not nu_aan(it, "20260329030000", "")
        assert gemist(it, "20260329000000", "20260329031500", "") == ["20260329023000"]

    def test_versie_randen(self):
        """L4: vierde deel telt niet; delen >= 1000 lopen over."""
        assert not versie_nummer("6.13.0.1") > versie_nummer("6.13")
        assert not versie_nummer("6.1000") > versie_nummer("7.0")
        assert versie_nummer("6.14-beta") < versie_nummer("6.13")

    def test_opruimen_effectief_31_dagen(self):
        """M3: '> 30 dagen' met afgekapte dagen: een bestand van 30 d 23 u blijft staan."""
        assert datediff_days("20261015230000", "20260915000000") == 30
        assert not wordt_opgeruimd("20261015230000", "20260915000000", 30)
        assert wordt_opgeruimd("20261016000000", "20260915000000", 30)
        assert not wordt_opgeruimd("20261016000000", "20200101000000", 0)   # 0 = nooit opruimen

    def test_patnr_patroon_in_vrije_tekst(self):
        """H2: het Pat.nr wordt in ALLE tekst van het dossiervenster gezocht."""
        assert dossier_bevestigd("Jansen, A", "123", "", "Pat.nr: 123", True)
        assert not dossier_bevestigd("Jansen, A", "123", "", "Pat.nr: 1234", True)
        # Ander dossier, maar het Pat.nr staat toevallig als huisnummer/telefoon in beeld:
        assert dossier_bevestigd("Jansen, A", "123", "", "Pat.nr: 98765\nDorpsstraat 123", True)
        assert dossier_bevestigd("Jansen, A", "123", "", "Pat.nr: 98765\nTel. 06-123", True)

    def test_naam_en_geboortedatum_substring(self):
        """H2: achternaam als deel van een andere naam telt mee (optie 'alleen Pat.nr' uit)."""
        tekst = "Pat.nr: 555\nJongeneel, K.\nGeboren 01-02-1950"
        assert dossier_bevestigd("Jong, P", "900001", "01-02-1950", tekst, alleen_patnr=False)
        assert not dossier_bevestigd("Jong, P", "900001", "01-02-1950", tekst, alleen_patnr=True)

    def test_deelbaar_is_een_voorvoegsel(self):
        """M9: 'ASB: Deelbaar' wordt als begin van de tekst herkend."""
        regels = [{"ap": "AN", "herhaal": "ASB: Deelbaar niet"}, {"ap": "AN", "herhaal": "ASB: Deelbaar"}]
        assert kies_regel(regels, "AN", alleen_deelbaar=True) == 0

    def test_bovenste_regel_is_niet_de_nieuwste(self):
        """K3: de app neemt de bovenste regel, zonder naar de datum te kijken. In de
        nep-Pharmacom (tests/NepPharmacom.js) is dat METFORMINE (02-09) en niet
        SIMVASTATINE (04-09)."""
        regels = [
            {"ap": "BG", "herhaal": "ASB: Deelbaar", "laatste": "01-09-2026", "etiket": "PARACETAMOL"},
            {"ap": "AN", "herhaal": "ASB: Deelbaar", "laatste": "02-09-2026", "etiket": "METFORMINE"},
            {"ap": "AN", "herhaal": "ASB: Deelbaar", "laatste": "04-09-2026", "etiket": "SIMVASTATINE"},
        ]
        assert regels[kies_regel(regels, "AN", True)]["etiket"] == "METFORMINE"
        # Andersom gesorteerd (bijv. door op een kolomkop te klikken): ander etiket
        assert regels[::-1][kies_regel(regels[::-1], "AN", True)]["etiket"] == "SIMVASTATINE"

    def test_apotheek_case_en_patroon(self):
        assert kies_regel([{"ap": "an"}], "AN", False) == 0
        assert lees_apotheek("AN - RS - 183") == "AN"
        # L7: elk label met twee streepjes past, ook als het niet de statusbalk is
        assert lees_apotheek("T1 - GUA - 3") == "T1"

    def test_soort_in_de_buffer(self):
        assert soort("", "", set()) == "controle"
        assert soort("1", "01-10-2026", set()) == "ontslag"
        assert soort("1", "?", set()) == "controle"
        assert soort("1", "", {"1"}) == "al"
        assert soort("1", "", {"01"}) == "print"     # exacte vergelijking, geen 01 = 1

    def test_sha(self):
        assert verwachte_sha("E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855  Etiketten_autoprinter.exe\n")
        assert verwachte_sha("geen hash") == ""

    def test_bestandsnamen(self):
        assert register_bestand("20261015080000") == "2026-10-15.txt"
        assert rapport_bestand("20261015080510", False) == "Rapport 2026-10-15 08.05.10.csv"
        assert rapport_bestand("20261015080510", True).startswith("Proefronde ")

    def test_csv_formule_gaat_ongemoeid_door(self):
        """L3: een waarde die met = begint, komt als formule in Excel."""
        r = csv_regel(["900001", '=HYPERLINK("http://x";"klik")'])
        assert r == '"900001";"=HYPERLINK(""http://x"";""klik"")"'


# --- 3. Gewenst gedrag (xfail tot het verbeterd is) -----------------------------

class TestGewenst:
    @pytest.mark.xfail(strict=True, reason="H4: even/oneven op ISO-weeknummer verspringt na week 53")
    def test_om_de_week_blijft_om_de_week(self):
        oneven = [d for d in ("20261214", "20261221", "20261228", "20270104", "20270111")
                  if week_klopt("oneven", d)]
        assert oneven == ["20261214", "20261228", "20270111"]

    def test_voorstel_ankerdatum(self):
        """Voorstel bij H4: tellen vanaf een vaste maandag loopt gewoon door."""
        anker = "20251229"   # maandag van ISO-week 1 van 2026 (oneven)
        weken = ["20261214", "20261221", "20261228", "20270104", "20270111"]
        assert [tweewekelijks_klopt(anker, d) for d in weken] == [True, False, True, False, True]

    @pytest.mark.xfail(strict=True, reason="H2: Pat.nr moet in het Pat.nr-veld staan, niet ergens in de tekst")
    def test_patnr_alleen_in_patnr_veld(self):
        assert not dossier_bevestigd("Jansen, A", "123", "", "Pat.nr: 98765\nDorpsstraat 123", True)

    @pytest.mark.xfail(strict=True, reason="M9: Herhaal info exact 'ASB: Deelbaar'")
    def test_deelbaar_exact(self):
        assert kies_regel([{"ap": "AN", "herhaal": "ASB: Deelbaar niet"}], "AN", True) == -1

    def test_voorstel_csv_veilig(self):
        assert csv_veilig("=1+1") == "'=1+1"
        assert csv_veilig("Jansen, A") == "Jansen, A"
