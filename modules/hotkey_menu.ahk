; ============================================================
; MODULE: Hotkey Prompt Menu
; Ctrl+Shift+Z quick-access menu for saved prompts
; Central place for non-slash hotkey behavior
;
; Hotkey:
;   Shift+Ctrl+Z  = Open quick prompt menu (select text first)
; ============================================================

RegisterTab("Hotkey Menu", Build_HotkeyMenuTab, 36)

Build_HotkeyMenuTab() {
    global gShell, DARK_TEXT

    gShell.gui.SetFont("s11 c" DARK_TEXT, "Segoe UI")
    gShell.gui.Add("Text", "xm+15 ym+45", "Hotkey Menu")
    gShell.gui.SetFont("s9 c" DARK_TEXT, "Segoe UI")

    gShell.gui.Add("Text", "xm+15 y+15 c888888", "Hotkey: Shift+Ctrl+Z — select text first, then press hotkey to pick a prompt")
    gShell.gui.Add("Text", "xm+15 y+8 c888888", "Ctrl+Alt+C = Clipboard HTML  |  Ctrl+Alt+O = Prompts HTML  |  Ctrl+Alt+L = Links HTML")
    gShell.gui.Add("Text", "xm+15 y+8 c888888", "Slash triggers live in the Prompts tab only")

    gShell.gui.Add("Text", "xm+15 y+20 c" DARK_TEXT, "Quick Templates")
    for i, tpl in [{n:"Fix Grammar", p:"Fix grammar/spelling. Return ONLY corrected text:"},
                   {n:"Summarize", p:"Summarize concisely:"},
                   {n:"Professional", p:"Rewrite professionally:"},
                   {n:"Simplify", p:"Simplify in plain English:"},
                   {n:"Expand", p:"Expand and elaborate in detail:"}] {
        btn := gShell.gui.Add("Button", (i=1 ? "xm+15 y+8" : "x+8") " w100", "+ " tpl.n)
        btn.OnEvent("Click", ((t) => (*) => AddQuickTemplate(t))(tpl))
    }

    gShell.gui.Add("Text", "xm+15 y+20 c" DARK_TEXT, "Available Prompts (for Ctrl+Shift+Z)")
    gShell.hkMenuLV := gShell.gui.Add("ListView", "xm+15 y+8 w1020 h300 -Multi +Grid VScroll",
        ["Trigger", "Preview"])
    ApplyDarkTheme(gShell.hkMenuLV)
    gShell.hkMenuLV.OnEvent("DoubleClick", HKMenuLV_OnDoubleClick)

    gShell.gui.Add("Text", "xm+15 y+15 c888888", "Double-click to test (requires selected text)")

    RefreshHKMenuLV()
}

RefreshHKMenuLV() {
    global gShell, gPrompts

    try {
        if !IsSet(gPrompts) || gPrompts.Length = 0
            return

        gShell.hkMenuLV.Delete()
        for i, p in gPrompts {
            shortcut := p.HasProp("shortcut") && p.shortcut != "" ? "/" p.shortcut : "(no shortcut)"
            preview := StrReplace(SubStr(p.template, 1, 80), "`n", " ")
            gShell.hkMenuLV.Add("", shortcut, preview)
        }
        gShell.hkMenuLV.ModifyCol(1, 150)
        gShell.hkMenuLV.ModifyCol(2, 800)
    }
}

HKMenuLV_OnDoubleClick(lv, row) {
    global gPrompts, gSelectedText

    if row <= 0 || row > gPrompts.Length
        return

    p := gPrompts[row]
    oldClip := A_Clipboard
    A_Clipboard := ""
    Send("^c")

    if !ClipWait(1) {
        A_Clipboard := oldClip
        ToolTip("Select text first!")
        SetTimer(() => ToolTip(), -1500)
        return
    }

    gSelectedText := A_Clipboard
    A_Clipboard := oldClip
    ProcessWithPrompt(p.template, p.HasProp("replace") ? p.replace : true, p.HasProp("popup") ? p.popup : false)
}

; Hotkey: Shift+Ctrl+Z opens quick menu
^+z:: {
    global gPrompts
    if !IsSet(gPrompts) || gPrompts.Length = 0 {
        ToolTip("No prompts saved yet")
        SetTimer(() => ToolTip(), -1500)
        return
    }
    HKMenu_ShowMenu()
}

HKMenu_ShowMenu() {
    global gPrompts, gSelectedText

    promptMenu := Menu()
    for i, p in gPrompts {
        label := p.name
        if p.HasProp("shortcut") && p.shortcut != ""
            label := label " (/" p.shortcut ")"
        promptMenu.Add(label, ((idx) => (*) => HKMenu_Execute(idx))(i))
    }
    promptMenu.Show()
}

HKMenu_Execute(index) {
    global gPrompts, gSelectedText

    if index <= 0 || index > gPrompts.Length
        return

    p := gPrompts[index]
    oldClip := A_Clipboard
    A_Clipboard := ""
    Send("^c")

    if !ClipWait(1) {
        A_Clipboard := oldClip
        ToolTip("Select text first!")
        SetTimer(() => ToolTip(), -1500)
        return
    }

    gSelectedText := A_Clipboard
    A_Clipboard := oldClip
    ProcessWithPrompt(p.template, p.HasProp("replace") ? p.replace : true, p.HasProp("popup") ? p.popup : false)
}
