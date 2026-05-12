; ============================================================
; MODULE: Quick Prompt Invoker (Slash Commands Only)
; Type "/" + shortcut to paste saved prompts
;
; Hotkeys:
;   /prompt_name = Paste prompt text at cursor
;
; Ctrl+Shift+Z menu is now in hotkey_menu.ahk
; ============================================================

RegisterTab("Quick Prompt", Build_QuickPromptTab, 35)

Build_QuickPromptTab() {
    global gShell, DARK_TEXT, gPrompts

    gShell.gui.SetFont("s11 c" DARK_TEXT, "Segoe UI")
    gShell.gui.Add("Text", "xm+15 ym+45", "Slash Commands")
    gShell.gui.SetFont("s9 c" DARK_TEXT, "Segoe UI")

    gShell.gui.Add("Text", "xm+15 y+15 c888888", "Type / + shortcut to paste prompt  (e.g., /new)")

    gShell.gui.Add("Text", "xm+15 y+20 c" DARK_TEXT, "Available Slash Commands")
    gShell.quickPromptLV := gShell.gui.Add("ListView", "xm+15 y+8 w1020 h350 -Multi +Grid VScroll",
        ["Trigger", "Preview"])
    ApplyDarkTheme(gShell.quickPromptLV)

    gShell.gui.Add("Text", "xm+15 y+15 c888888", "Prompts are managed in the Prompts tab  |  Ctrl+Shift+Z menu is in the Hotkey Menu tab")

    RefreshQuickPromptLV()
}

RefreshQuickPromptLV() {
    global gShell, gPrompts

    try {
        if !IsSet(gPrompts) || gPrompts.Length = 0
            return

        gShell.quickPromptLV.Delete()
        for i, p in gPrompts {
            shortcut := p.HasProp("shortcut") && p.shortcut != "" ? "/" p.shortcut : "(no shortcut)"
            preview := StrReplace(SubStr(p.template, 1, 80), "`n", " ")
            gShell.quickPromptLV.Add("", shortcut, preview)
        }
        gShell.quickPromptLV.ModifyCol(1, 150)
        gShell.quickPromptLV.ModifyCol(2, 800)
    }
}
