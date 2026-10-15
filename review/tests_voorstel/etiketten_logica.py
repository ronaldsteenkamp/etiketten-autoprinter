"""
Python-port van de pure logica van de Etiketten autoprinter (v6.13), voor de review.

Elke functie volgt de AutoHotkey-code zo letterlijk mogelijk; het bronbestand en de
regel staan erbij. Tijdstempels zijn net als in AHK tekst in de vorm yyyyMMddHHmmss.

Niet geport: alles wat Pharmacom, de Java Access Bridge, vensters of bestanden raakt.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from datetime import datetime, timedelta


# --- Hulp -------------------------------------------------------------------

def _ts(s: str) -> datetime:
    """AHK-tijdstempel (yyyyMMdd[HH[mm[ss]]]) -> datetime. Ongeldig -> ValueError,
    net als DateDiff/DateAdd in AHK ('Parameter #n of DateDiff is invalid')."""
    s = (s + "000000")[:14]
    return datetime.strptime(s, "%Y%m%d%H%M%S")


def _fmt(d: datetime) -> str:
    return d.strftime("%Y%m%d%H%M%S")


def datediff_seconds(a: str, b: str) -> int:
    return int((_ts(a) - _ts(b)).total_seconds())


def datediff_days(a: str, b: str) -> int:
    """DateDiff(a, b, "Days"): hele dagen, afgekapt richting nul."""
    secs = (_ts(a) - _ts(b)).total_seconds()
    return int(secs / 86400)


# src/Hulp.ahk:41
def versie_nummer(v: str) -> int:
    d = v.split(".")
    n = 0
    for i in range(3):
        deel = d[i] if i < len(d) else ""
        n = n * 1000 + (int(deel) if re.fullmatch(r"\s*[+-]?\d+\s*", deel or "x") else 0)
    return n


# src/Hulp.ahk:36
def is_datum(v: str) -> bool:
    return re.fullmatch(r"(\d{1,2}[-/.]\d{1,2}[-/.](\d{2}|\d{4})|\d{4}-\d{2}-\d{2})", v) is not None


# src/Hulp.ahk:69
def titel_is_buffer(titel: str) -> bool:
    return not re.match(r"^Pharmacom\s+-\s+\S", titel) or "aanschrijfbuffer" in titel.lower()


# src/Hulp.ahk:170 - Opruimen: verwijderen als DateDiff(Nu, gewijzigd, "Days") > Dagen
def wordt_opgeruimd(nu: str, gewijzigd: str, dagen) -> bool:
    if not isinstance(dagen, int) or dagen < 1:
        return False
    return datediff_days(nu, gewijzigd) > dagen


# --- Planning (src/Planning.ahk) --------------------------------------------

def week_nr(t: str) -> int:
    """Planning.WeekNr: FormatTime(t, "YWeek") = ISO-jaar + ISO-week."""
    return _ts(t).isocalendar()[1]


def weekdag(t: str) -> int:
    """Planning.Weekdag: 1 = maandag ... 7 = zondag."""
    return _ts(t).isoweekday()


def week_klopt(weken: str, t: str) -> bool:
    even = week_nr(t) % 2 == 0
    return weken == "alle" or (weken == "even" and even) or (weken == "oneven" and not even)


@dataclass
class Planregel:
    id: str = "1"
    aan: int = 1
    computer: str = "PC1"
    dagen: str = "4"
    tijd: str = "08:00"
    weken: str = "even"


MAX_MINUTEN = 15
MAX_UITSTEL = 120
WAKKER_VOORAF = 30
TIJD_RE = re.compile(r"^(\d{1,2}):(\d{2})$")


def _moment(dag: str, tijd: re.Match) -> str:
    return dag[:8] + f"{int(tijd[1]):02}{int(tijd[2]):02}00"


# Planning.ahk:199
def nu_aan(it: Planregel, nu: str, laatst: str, computer: str = "PC1", max_min: int = MAX_MINUTEN) -> bool:
    if not it.aan or it.computer != computer or str(weekdag(nu)) not in it.dagen or not week_klopt(it.weken, nu):
        return False
    m = TIJD_RE.match(it.tijd)
    if not m:
        return False
    start = _moment(nu, m)
    verschil = datediff_seconds(nu, start)        # ValueError bij 25:00 (zoals AHK)
    if verschil < 0 or verschil >= max_min * 60:
        return False
    return laatst[:8] != nu[:8]


# Planning.ahk:218
def momenten(it: Planregel, van: str, tot: str) -> list[str]:
    res = []
    m = TIJD_RE.match(it.tijd)
    if not m:
        return res
    dag = _ts(van[:8])
    for _ in range(32):
        moment = _moment(_fmt(dag), m)
        if van < moment <= tot and str(weekdag(moment)) in it.dagen and week_klopt(it.weken, moment):
            res.append(moment)
        dag += timedelta(days=1)
        if _fmt(dag)[:8] > tot[:8]:
            break
    return res


# Planning.ahk:238
def gemist(it: Planregel, vorige: str, tot: str, laatst: str, computer: str = "PC1") -> list[str]:
    if not it.aan or it.computer != computer:
        return []
    return [m for m in momenten(it, vorige, tot) if laatst[:8] < m[:8]]


# Planning.ahk:335
def seconden_tot(it: Planregel, nu: str, computer: str = "PC1"):
    if not it.aan or it.computer != computer or str(weekdag(nu)) not in it.dagen or not week_klopt(it.weken, nu):
        return ""
    m = TIJD_RE.match(it.tijd)
    if not m:
        return ""
    return datediff_seconds(_moment(nu, m), nu)


# --- Voorstel (niet in de app): tweewekelijks op basis van een ankerdatum ---------
def tweewekelijks_klopt(anker_maandag: str, t: str) -> bool:
    """Voorstel: 'om de week' tellen vanaf een vaste maandag in plaats van het
    ISO-weeknummer. Loopt door over jaarwisselingen met week 53."""
    a = _ts(anker_maandag[:8])
    d = _ts(t[:8])
    maandag = d - timedelta(days=d.weekday())
    return ((maandag - a).days // 7) % 2 == 0


# --- Update (src/Update.ahk:167) ----------------------------------------------
EXE = "Etiketten_autoprinter.exe"


def lees_release(j: str):
    t = re.search(r'"tag_name"\s*:\s*"v?(\d+(?:\.\d+){0,3})"', j)
    if not t:
        return None
    exe = sha = ""
    for u in re.finditer(r'"browser_download_url"\s*:\s*"([^"]+)"', j):
        url = u.group(1)
        if re.search(r"/" + re.escape(EXE) + r"$", url, re.I):
            exe = url
        elif re.search(r"/" + re.escape(EXE + ".sha256") + r"$", url, re.I):
            sha = url
    return {"versie": t.group(1), "exe": exe, "sha": sha} if exe and sha else None


# Update.ahk:202 - verwachte controlewaarde uit het .sha256-bestand
def verwachte_sha(inhoud: str) -> str:
    v = inhoud.strip(" \t\r\n").lower()[:64]
    return v if re.fullmatch(r"[0-9a-f]{64}", v) else ""


# --- Patiëntcontroles (src/Pharmacom.ahk, src/Ronde.ahk) ----------------------

# Pharmacom.ahk:350
def patnr_patroon(patnr: str) -> str:
    return r"(?<!\d)" + re.escape(patnr) + r"(?!\d)" if patnr else ""


# Pharmacom.ahk:348-349
def geb_patroon(geb: str) -> str:
    g = re.fullmatch(r"(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})", geb)
    if not g:
        return ""
    return (r"(?<!\d)0?" + str(int(g[1])) + r"[-/.]0?" + str(int(g[2])) +
            r"[-/.](" + g[3] + "|" + g[3][-2:] + r")(?!\d)")


# Pharmacom.ahk:345-362 (zonder het wachten): True = dossier bevestigd
def dossier_bevestigd(naam: str, patnr: str, geb: str, tekst: str, alleen_patnr: bool) -> bool:
    achternaam = naam.split(",")[0].strip()
    heeft_patnr = bool(patnr) and re.search(patnr_patroon(patnr), tekst) is not None
    heeft_naam = bool(achternaam) and achternaam.lower() in tekst.lower()    # InStr: hoofdletterongevoelig
    gp = geb_patroon(geb)
    heeft_geb = bool(gp) and re.search(gp, tekst) is not None
    return heeft_patnr or (not alleen_patnr and heeft_naam and heeft_geb)


DEELBAAR = re.compile(r"^ASB:\s*Deelbaar", re.I)          # Pharmacom.ahk:24
APOTHEEK = re.compile(r"^\s*([A-Za-z0-9]{1,4})\s*-\s*\S+\s*-\s*\S+\s*$")   # Pharmacom.ahk:26


def lees_apotheek(label: str) -> str:
    m = APOTHEEK.match(label)
    return m[1] if m else ""


# Ronde.ahk:474-484: bovenste regel van de eigen apotheek
def kies_regel(regels: list[dict], apotheek: str, alleen_deelbaar: bool) -> int:
    for r, regel in enumerate(regels):
        if regel["ap"].lower() != apotheek.lower():        # AHK != is hoofdletterongevoelig
            continue
        if alleen_deelbaar and not DEELBAAR.search(regel.get("herhaal", "")):
            continue
        return r
    return -1


# Ronde.ahk:80-95: soort per regel in de aanschrijfbuffer
def soort(patnr: str, ontslag: str, vandaag_geprint: set[str]) -> str:
    if patnr == "":
        return "controle"
    if ontslag != "" and is_datum(ontslag):
        return "ontslag"
    if ontslag != "":
        return "controle"
    if patnr in vandaag_geprint:
        return "al"
    return "print"


# --- Rapport (src/Opslag.ahk:93) ---------------------------------------------
def csv_regel(waarden: list[str]) -> str:
    return ";".join('"' + v.replace('"', '""') + '"' for v in waarden)


def csv_veilig(v: str) -> str:
    """Voorstel: formule-injectie neutraliseren (OWASP): voorloop-' bij = + - @ tab CR."""
    return "'" + v if v[:1] in ("=", "+", "-", "@", "\t", "\r") else v


def register_bestand(nu: str) -> str:
    return _ts(nu).strftime("%Y-%m-%d") + ".txt"


def rapport_bestand(nu: str, proef: bool) -> str:
    return ("Proefronde " if proef else "Rapport ") + _ts(nu).strftime("%Y-%m-%d %H.%M.%S") + ".csv"
