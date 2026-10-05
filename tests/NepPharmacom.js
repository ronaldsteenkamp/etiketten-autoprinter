// =====================================================================
// Nep-Pharmacom: een klein Java-programma (Swing) dat de schermen van
// Pharmacom nadoet die de etiketten autoprinter gebruikt, zodat je hele
// rondes kunt testen zonder het echte Pharmacom en zonder echte patiënten.
//
// Draait met jjs.exe (JavaScript in Java 8) uit de Java-map van Pharmacom,
// dus zonder iets te installeren. Starten: "Test met nep-Pharmacom.cmd".
// De app herkent hem in testmodus aan jjs.exe (ETIKETTEN_TEST=1).
//
// Nagedaan (zoals de app ze ziet via de Java Access Bridge):
//  - hoofdvenster "Pharmacom - Apotheek dashboard"; Ctrl+F11 opent de
//    aanschrijfbuffer (leeg, zoals in Pharmacom)
//  - zoekvelden Instelling: en Afdeling: (paneel met code + omschrijving);
//    een onbekende code opent "Kies een code"
//  - Zoeken / Stoppen met zoeken; lege groep -> "Geen patiënten gevonden"
//  - tabel met Inst, Afd, Patiënt, Pat.nr, Geb. Datum, Ontslagdatum
//  - statusbalk "AN - RS - 183" (ingelogde apotheek)
//  - Ctrl+B: venster "Patiënt dossier"; F4: medicatiehistorie (twee tabellen
//    naast elkaar); Ctrl+P: afdrukmenu (Barcode etiket = B, Afleveretiket = A);
//    Escape: menu of dossier dicht
// Geprinte etiketten komen in nep_geprint.txt naast dit bestand.
//
// Alle patiënten zijn verzonnen (Pat.nr 9000xx). Alleen ASCII in dit bestand
// (jjs leest het met de standaard tekenset); ë = ë.
// =====================================================================

var Swing = {
    JFrame: Java.type("javax.swing.JFrame"), JDialog: Java.type("javax.swing.JDialog"),
    JPanel: Java.type("javax.swing.JPanel"), JLabel: Java.type("javax.swing.JLabel"),
    JButton: Java.type("javax.swing.JButton"), JTextField: Java.type("javax.swing.JTextField"),
    JTable: Java.type("javax.swing.JTable"), JScrollPane: Java.type("javax.swing.JScrollPane"),
    JPopupMenu: Java.type("javax.swing.JPopupMenu"), JMenuItem: Java.type("javax.swing.JMenuItem"),
    JOptionPane: Java.type("javax.swing.JOptionPane"), Timer: Java.type("javax.swing.Timer"),
    SwingUtilities: Java.type("javax.swing.SwingUtilities"), ListSelectionModel: Java.type("javax.swing.ListSelectionModel"),
    DefaultTableModel: Java.type("javax.swing.table.DefaultTableModel")
};
var AWT = {
    BorderLayout: Java.type("java.awt.BorderLayout"), CardLayout: Java.type("java.awt.CardLayout"),
    FlowLayout: Java.type("java.awt.FlowLayout"), GridLayout: Java.type("java.awt.GridLayout"),
    Dimension: Java.type("java.awt.Dimension"), KeyEvent: Java.type("java.awt.event.KeyEvent"),
    KeyboardFocusManager: Java.type("java.awt.KeyboardFocusManager"),
    FocusAdapter: Java.type("java.awt.event.FocusAdapter")
};
var Files = Java.type("java.nio.file.Files"), Paths = Java.type("java.nio.file.Paths");
var StandardOpenOption = Java.type("java.nio.file.StandardOpenOption");
var LocalTime = Java.type("java.time.LocalTime");

var E = "ë";   // ë
var MAP = (typeof __DIR__ !== "undefined") ? __DIR__ : ".";
var LOG = MAP + "nep_geprint.txt";

// --- Gegevens ------------------------------------------------------------
var Instellingen = { "T1": "2 WEKELIJKS 1", "T2": "2 WEKELIJKS 2" };
var Afdelingen = {
    "T1": { "T1GUA": "T1 GUA", "T1HA": "T1 Halers" },
    "T2": { "T2GUA": "T2 GUA", "T2HA": "T2 Halers" }
};
// Per patiënt: soort bepaalt de medicatiehistorie:
//   ok = bovenste AN-regel met ASB: Deelbaar; geenAN = alleen andere apotheek;
//   leeg = lege historie; geenDeelbaar = AN zonder ASB: Deelbaar
var Patienten = [
    { inst: "T1", afd: "T1GUA", naam: "Testpersoon, A", patnr: "900001", geb: "01-02-1950", ontslag: "", soort: "ok" },
    { inst: "T1", afd: "T1GUA", naam: "Proefmans, B", patnr: "900002", geb: "12-03-1944", ontslag: "", soort: "ok" },
    { inst: "T1", afd: "T1GUA", naam: "Voorbeeld, C", patnr: "900003", geb: "23-04-1938", ontslag: "", soort: "geenAN" },
    { inst: "T1", afd: "T1GUA", naam: "Oefening, D", patnr: "900004", geb: "05-05-1960", ontslag: "", soort: "leeg" },
    { inst: "T1", afd: "T1GUA", naam: "Nepper, E", patnr: "900005", geb: "16-06-1955", ontslag: "01-10-2026", soort: "ok" },
    { inst: "T1", afd: "T1GUA", naam: "Schijn, F", patnr: "900006", geb: "27-07-1949", ontslag: "", soort: "geenDeelbaar" },
    { inst: "T1", afd: "T1GUA", naam: "Probeer, G", patnr: "900007", geb: "08-08-1958", ontslag: "", soort: "ok" },
    { inst: "T1", afd: "T1HA", naam: "Haler, H", patnr: "900011", geb: "19-09-1947", ontslag: "", soort: "ok" },
    { inst: "T1", afd: "T1HA", naam: "Haler, I", patnr: "900012", geb: "30-10-1952", ontslag: "", soort: "ok" },
    { inst: "T2", afd: "T2HA", naam: "Tweede, J", patnr: "900021", geb: "11-11-1941", ontslag: "", soort: "ok" }
    // T2 / T2GUA: geen patiënten (test "Geen patiënten gevonden")
];
function historie(p) {
    // [Laatste V/A, Etiketnaam, Labeler, CF, Ap, Th. einddatum, Herhaal info]
    if (p.soort === "leeg") return [];
    var r = [["01-09-2026", "PARACETAMOL 500MG TABLET", "AB", "12", "BG", "", "ASB: Deelbaar"]];
    if (p.soort === "ok") r.push(["02-09-2026", "METFORMINE 850MG TABLET", "CD", "34", "AN", "", "ASB: Deelbaar"]);
    if (p.soort === "geenDeelbaar") r.push(["03-09-2026", "OMEPRAZOL 20MG CAPSULE", "EF", "56", "AN", "", ""]);
    // Nog een AN-regel eronder (de app moet de BOVENSTE nemen)
    if (p.soort === "ok") r.push(["04-09-2026", "SIMVASTATINE 40MG TABLET", "GH", "78", "AN", "", "ASB: Deelbaar"]);
    return r;
}

// --- Hulpjes ---------------------------------------------------------------
function tabelModel(koppen) {
    var Cls = Java.extend(Swing.DefaultTableModel, { isCellEditable: function () { return false; } });
    return new Cls(Java.to(koppen, "java.lang.Object[]"), 0);
}
function regel(model, waarden) { model.addRow(Java.to(waarden, "java.lang.Object[]")); }
function later(ms, fn) { var t = new Swing.Timer(ms, function () { fn(); }); t.setRepeats(false); t.start(); }
function log(tekst) {
    var r = LocalTime.now().toString().substring(0, 8) + ";" + tekst + "\r\n";
    Files.write(Paths.get(LOG), r.getBytes("UTF-8"), StandardOpenOption.CREATE, StandardOpenOption.APPEND);
    print(r.trim());
}

// --- Hoofdvenster ------------------------------------------------------------
var frame = new Swing.JFrame("Pharmacom - Apotheek dashboard");
frame.setDefaultCloseOperation(Swing.JFrame.EXIT_ON_CLOSE);
frame.setSize(1000, 680);
var kaarten = new AWT.CardLayout();
var midden = new Swing.JPanel(kaarten);

var dash = new Swing.JPanel(new AWT.FlowLayout(AWT.FlowLayout.LEFT));
dash.add(new Swing.JLabel("Apotheekdashboard (nep). Ctrl+F11 = aanschrijfbuffer"));
midden.add(dash, "dashboard");

// Zoekveld: paneel met als naam het label, met code, zoekknop, omschrijving
function maakVeld(label, lijst) {
    var paneel = new Swing.JPanel(new AWT.FlowLayout(AWT.FlowLayout.LEFT, 4, 0));
    paneel.getAccessibleContext().setAccessibleName(label);
    paneel.add(new Swing.JLabel(label));
    var code = new Swing.JTextField(7), knop = new Swing.JButton("..."), oms = new Swing.JTextField(16);
    oms.setEditable(false);
    paneel.add(code); paneel.add(knop); paneel.add(oms);
    var veld = { paneel: paneel, code: code, oms: oms };
    veld.controleer = function () {
        var v = String(code.getText()).trim().toUpperCase();
        code.setText(v);
        var l = lijst();
        if (v === "") { oms.setText(""); return; }
        if (l[v] !== undefined) { oms.setText(l[v]); return; }
        oms.setText("");
        Swing.SwingUtilities.invokeLater(function () { kiesCode(l); });
    };
    var Focus = Java.extend(AWT.FocusAdapter, { focusLost: function (e) { if (!e.isTemporary()) veld.controleer(); } });
    code.addFocusListener(new Focus());
    knop.addActionListener(function () { kiesCode(lijst()); });
    return veld;
}
function kiesCode(l) {
    var d = new Swing.JDialog(frame, "Kies een code", true);
    var m = tabelModel(["Code", "Omschrijving"]);
    for (var k in l) regel(m, [k, l[k]]);
    d.add(new Swing.JScrollPane(new Swing.JTable(m)));
    d.setSize(400, 250); d.setLocationRelativeTo(frame);
    d.setVisible(true);   // wacht (modaal) tot Escape
}

var inst = maakVeld("Instelling:", function () { return Instellingen; });
var afd = maakVeld("Afdeling:", function () {
    var i = String(inst.code.getText()).trim().toUpperCase();
    return Afdelingen[i] || {};
});
var zoeken = new Swing.JButton("Zoeken"), stoppen = new Swing.JButton("Stoppen met zoeken");
stoppen.setEnabled(false);
var criteria = new Swing.JPanel(new AWT.GridLayout(2, 2));
criteria.add(inst.paneel); criteria.add(zoeken); criteria.add(afd.paneel); criteria.add(stoppen);

var bufferModel = tabelModel(["Inst", "Afd", "Pati" + E + "nt", "Pat.nr", "Geb. Datum", "Ontslagdatum"]);
var bufferTabel = new Swing.JTable(bufferModel);
bufferTabel.setSelectionMode(Swing.ListSelectionModel.SINGLE_SELECTION);
var buffer = new Swing.JPanel(new AWT.BorderLayout());
buffer.add(criteria, AWT.BorderLayout.NORTH);
buffer.add(new Swing.JScrollPane(bufferTabel), AWT.BorderLayout.CENTER);
midden.add(buffer, "buffer");

var gevonden = [];
zoeken.addActionListener(function () {
    var i = String(inst.code.getText()).trim().toUpperCase(), a = String(afd.code.getText()).trim().toUpperCase();
    zoeken.setEnabled(false); stoppen.setEnabled(true);
    bufferModel.setRowCount(0); gevonden = [];
    later(800, function () {
        Patienten.forEach(function (p) {
            if (p.inst === i && (a === "" || p.afd === a)) {
                gevonden.push(p);
                regel(bufferModel, [p.inst, p.afd, p.naam, p.patnr, p.geb, p.ontslag]);
            }
        });
        stoppen.setEnabled(false); zoeken.setEnabled(true);
        print("Zoeken " + i + "/" + a + ": " + gevonden.length + " patienten");
        if (!gevonden.length)
            Swing.JOptionPane.showMessageDialog(frame, "Er worden geen pati" + E + "nten gevonden",
                "Geen pati" + E + "nten gevonden", Swing.JOptionPane.INFORMATION_MESSAGE);
    });
});

var status = new Swing.JPanel(new AWT.FlowLayout(AWT.FlowLayout.RIGHT));
status.add(new Swing.JLabel("AN - RS - 183"));
frame.add(midden, AWT.BorderLayout.CENTER);
frame.add(status, AWT.BorderLayout.SOUTH);

function openBuffer() {
    // Zoals Pharmacom: een nieuwe, lege aanschrijfbuffer
    inst.code.setText(""); inst.oms.setText(""); afd.code.setText(""); afd.oms.setText("");
    bufferModel.setRowCount(0); gevonden = [];
    kaarten.show(midden, "buffer");
    frame.setTitle("Pharmacom - Aanschrijfbuffer");
    inst.code.requestFocusInWindow();
}

// --- Dossier --------------------------------------------------------------
var dossier = null, histKaarten = null, histMidden = null, rechts = null, links = null, menu = null, dossierPat = null;
function openDossier(p) {
    dossierPat = p;
    dossier = new Swing.JDialog(frame, "Pati" + E + "nt dossier", false);
    dossier.setSize(820, 480); dossier.setLocationRelativeTo(frame);
    var kop = new Swing.JPanel(new AWT.FlowLayout(AWT.FlowLayout.LEFT));
    kop.add(new Swing.JLabel("Pat.nr: " + p.patnr));
    kop.add(new Swing.JLabel(p.naam));
    kop.add(new Swing.JLabel("Geboren: " + p.geb));
    histKaarten = new AWT.CardLayout();
    histMidden = new Swing.JPanel(histKaarten);
    histMidden.add(new Swing.JLabel("Dossier (F4 = medicatiehistorie)"), "leeg");
    var lm = tabelModel(["Laatste V/A", "Etiketnaam"]);
    var rm = tabelModel(["Labeler", "CF", "Ap", "Th. einddatum", "Herhaal info"]);
    links = new Swing.JTable(lm); rechts = new Swing.JTable(rm);
    links.setSelectionModel(rechts.getSelectionModel());   // zelfde regels, zelfde selectie
    var hist = new Swing.JPanel(new AWT.GridLayout(1, 2));
    hist.add(new Swing.JScrollPane(links)); hist.add(new Swing.JScrollPane(rechts));
    histMidden.add(hist, "historie");
    dossier.add(kop, AWT.BorderLayout.NORTH);
    dossier.add(histMidden, AWT.BorderLayout.CENTER);
    menu = new Swing.JPopupMenu();
    [["Barcode etiket", AWT.KeyEvent.VK_B], ["Afleveretiket", AWT.KeyEvent.VK_A]].forEach(function (it) {
        var mi = new Swing.JMenuItem(it[0]);
        mi.setMnemonic(it[1]);
        mi.addActionListener(function () { kies(it[0]); });
        menu.add(mi);
    });
    dossier.setVisible(true);
    print("Dossier " + p.patnr + " geopend");
}
function toonHistorie() {
    var lm = links.getModel(), rm = rechts.getModel();
    historie(dossierPat).forEach(function (r) { regel(lm, [r[0], r[1]]); regel(rm, [r[2], r[3], r[4], r[5], r[6]]); });
    histKaarten.show(histMidden, "historie");
}
function kies(item) {
    menu.setVisible(false);
    var rij = rechts.getSelectedRow();
    var etiket = rij >= 0 ? links.getModel().getValueAt(rij, 1) : "(geen regel geselecteerd)";
    log("GEPRINT;" + dossierPat.patnr + ";" + item + ";" + etiket);
}
function sluitDossier() {
    if (!dossier) return;
    dossier.dispose(); dossier = null; dossierPat = null;
    frame.toFront();
}

// --- Toetsen (alles centraal, ongeacht welk onderdeel de focus heeft) -------
var KE = AWT.KeyEvent;
AWT.KeyboardFocusManager.getCurrentKeyboardFocusManager().addKeyEventDispatcher(function (e) {
    if (e.getID() !== KE.KEY_PRESSED) return false;
    var k = e.getKeyCode(), ctrl = e.isControlDown(), alt = e.isAltDown();
    var actief = AWT.KeyboardFocusManager.getCurrentKeyboardFocusManager().getActiveWindow();
    // Afdrukmenu open: Escape sluit, letter (met of zonder Alt) kiest
    if (menu && menu.isVisible()) {
        if (k === KE.VK_ESCAPE) { menu.setVisible(false); return true; }
        if (k === KE.VK_B) { later(50, function () { kies("Barcode etiket"); }); return true; }
        if (k === KE.VK_A) { later(50, function () { kies("Afleveretiket"); }); return true; }
        return true;
    }
    // Keuzevenster of melding: Escape sluit
    if (actief && actief !== frame && actief !== dossier && k === KE.VK_ESCAPE) { actief.dispose(); return true; }
    if (actief === frame) {
        if (ctrl && k === KE.VK_F11) { later(300, openBuffer); return true; }
        if (ctrl && k === KE.VK_B) {
            var r = bufferTabel.getSelectedRow();
            if (r >= 0 && r < gevonden.length) { var p = gevonden[r]; later(400, function () { openDossier(p); }); }
            return true;
        }
    }
    if (dossier && actief === dossier) {
        if (k === KE.VK_F4) { later(300, toonHistorie); return true; }
        if (ctrl && k === KE.VK_P) {
            later(250, function () { if (dossier) menu.show(dossier.getContentPane(), 300, 120); });
            return true;
        }
        if (k === KE.VK_ESCAPE) { later(150, sluitDossier); return true; }
        if (k === KE.VK_UP || k === KE.VK_DOWN) return false;
    }
    return false;
});

Swing.SwingUtilities.invokeLater(function () { frame.setVisible(true); });
print("Nep-Pharmacom gestart. Geprinte etiketten: " + LOG);
