; =====================================================================
; Toetsenbord en muis blokkeren tijdens het printen
;
; Werkt zonder beheerdersrechten: alle toetsen en muisknoppen krijgen
; tijdelijk een sneltoets die niets doet. Esc stopt de ronde. De eigen
; toetsaanslagen van de app gaan er gewoon langs ($ = via de
; toetsenbordhook, zodat Send niet wordt tegengehouden). Ctrl+Alt+Del werkt
; altijd. Volledig = false: alleen Esc als noodstop.
; =====================================================================

class Invoer {
    static Actief := false
    static Muis := ["LButton", "RButton", "MButton", "XButton1", "XButton2", "WheelUp", "WheelDown", "WheelLeft", "WheelRight"]

    static Blokkeer(Aan, Volledig := true) {
        if Aan {
            if this.Actief
                return
            try Hotkey "$*Esc", InvoerStop, "On"
            if Volledig {
                for k in this.Toetsen()
                    try Hotkey k, InvoerNiets, "On"
            }
            this.Actief := true
            Log(Volledig ? "Toetsenbord en muis geblokkeerd (Esc = stoppen)" : "Esc = stoppen")
            return
        }
        if !this.Actief
            return
        try Hotkey "$*Esc", "Off"
        for k in this.Toetsen()
            try Hotkey k, "Off"
        this.Actief := false
        Log("Toetsenbord en muis weer vrij")
    }

    ; Alle toetsen (behalve muisknoppen 1-6 en Esc) plus de muisknoppen
    static Toetsen() {
        static Lijst := ""
        if Lijst
            return Lijst
        Lijst := []
        loop 254 {
            if A_Index <= 6 || A_Index = 0x1B
                continue
            Lijst.Push("$*vk" Format("{:02X}", A_Index))
        }
        for k in this.Muis
            Lijst.Push("*" k)
        return Lijst
    }
}

InvoerNiets(*) {
}

InvoerStop(*) => Ronde.Stop()
