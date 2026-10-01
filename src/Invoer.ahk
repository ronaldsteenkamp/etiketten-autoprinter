; =====================================================================
; Toetsenbord en muis blokkeren tijdens het printen
;
; Werkt zonder beheerdersrechten: alle toetsen en muisknoppen krijgen
; tijdelijk een sneltoets die niets doet. Esc stopt de ronde. De eigen
; toetsaanslagen van de app gaan er gewoon langs ($ = via de
; toetsenbordhook, zodat Send niet wordt tegengehouden). Ctrl+Alt+Del werkt
; altijd. Volledig = false: alleen Esc als noodstop.
;
; Klikken op het venster van de app zelf worden NIET geblokkeerd, zodat de
; knop Stop altijd werkt. Het venster wordt daarbij niet actief (zie
; Venster.GeenActivatie), zodat Pharmacom op de voorgrond blijft.
; =====================================================================

class Invoer {
    static Actief := false
    static Muis := ["LButton", "RButton", "MButton", "XButton1", "XButton2", "WheelUp", "WheelDown", "WheelLeft", "WheelRight"]
    static NietOpApp := (*) => !Invoer.MuisOpApp()

    static Blokkeer(Aan, Volledig := true) {
        if Aan {
            if this.Actief
                return
            try Hotkey "$*Esc", InvoerStop, "On"
            if Volledig {
                for k in this.Toetsen()
                    try Hotkey k, InvoerNiets, "On"
                HotIf this.NietOpApp
                for k in this.Muis
                    try Hotkey "*" k, InvoerNiets, "On"
                HotIf
            }
            this.Actief := true
            Log(Volledig ? "Toetsenbord en muis geblokkeerd (Esc of Stop = stoppen)" : "Esc = stoppen")
            return
        }
        if !this.Actief
            return
        try Hotkey "$*Esc", "Off"
        for k in this.Toetsen()
            try Hotkey k, "Off"
        HotIf this.NietOpApp
        for k in this.Muis
            try Hotkey "*" k, "Off"
        HotIf
        this.Actief := false
        Log("Toetsenbord en muis weer vrij")
    }

    ; Staat de muis boven het venster van de app?
    static MuisOpApp() {
        try {
            MouseGetPos , , &Win
            return Win = Venster.Hwnd
        }
        return false
    }

    ; Alle toetsen (behalve muisknoppen 1-6 en Esc)
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
        return Lijst
    }
}

InvoerNiets(*) {
}

InvoerStop(*) => Ronde.Stop()
