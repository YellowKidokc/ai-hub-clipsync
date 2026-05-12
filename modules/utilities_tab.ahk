; ============================================================
; Module: Utilities — Quick Toggles & Mini Scripts
; ============================================================

#Requires AutoHotkey v2.0+

; ---- Register tab (hub mode only) ----
if IsSet(HUB_CORE_LOADED)
    RegisterTab("Utilities", Build_UtilitiesTab, 45)

Build_UtilitiesTab() {
    global gShell, DARK_TEXT, DARK_BG, gAlwaysOnTop, gRememberPos
    global gSaveMarkdownAutoEnabled, gSaveMarkdownAsEnabled

    gShell.gui.SetFont("s10 Bold c" DARK_TEXT, "Segoe UI")
    gShell.gui.Add("Text", "xm+15 ym+50", "Quick Toggles")
    gShell.gui.SetFont("s9 Bold c" DARK_TEXT, "Segoe UI")
    gShell.gui.Add("Text", "xm+15 y+8 c888888", "Toggles that control AI-HUB window behavior. Also available as global hotkeys.")

    ; ---- Always On Top toggle ----
    gShell.gui.Add("Text", "xm+15 y+35 c" DARK_TEXT, "Window Always On Top")
    gShell.gui.Add("Text", "xm+15 y+5 c888888", "Keep AI-HUB above all other windows.  Hotkey: Ctrl+Alt+W")

    gShell.chkAlwaysOnTop := gShell.gui.Add("CheckBox", "xm+350 yp-18 c" DARK_TEXT, "ON")
    gShell.chkAlwaysOnTop.Value := gAlwaysOnTop ? 1 : 0
    gShell.chkAlwaysOnTop.OnEvent("Click", Util_ToggleAlwaysOnTop)

    ; ---- Remember Position toggle ----
    gShell.gui.Add("Text", "xm+15 y+35 c" DARK_TEXT, "Remember Window Position")
    gShell.gui.Add("Text", "xm+15 y+5 c888888", "Save position on close, restore on open.  Hotkey: Ctrl+Alt+Y")

    gShell.chkRememberPos := gShell.gui.Add("CheckBox", "xm+350 yp-18 c" DARK_TEXT, "ON")
    gShell.chkRememberPos.Value := gRememberPos ? 1 : 0
    gShell.chkRememberPos.OnEvent("Click", Util_ToggleRememberPos)

    ; ---- Separator ----
    gShell.gui.Add("Text", "xm+15 y+45 w500 h1 Background333333")

    ; ---- Mini Scripts ----
    gShell.gui.SetFont("s10 Bold c" DARK_TEXT, "Segoe UI")
    gShell.gui.Add("Text", "xm+15 y+20", "Mini Scripts")
    gShell.gui.SetFont("s9 Bold c" DARK_TEXT, "Segoe UI")
    gShell.gui.Add("Text", "xm+15 y+8 c888888", "Quick capture tools. Grabs your current selection and saves as Markdown using the window title.")

    ; ---- Save Markdown to Downloads ----
    gShell.gui.Add("Text", "xm+15 y+35 c" DARK_TEXT, "Quick Save Markdown")
    gShell.gui.Add("Text", "xm+15 y+5 c888888", "Save selection as .md to Downloads folder.  Hotkey: Ctrl+Alt+A")

    gShell.chkSaveMdAuto := gShell.gui.Add("CheckBox", "xm+350 yp-18 c" DARK_TEXT, "ON")
    gShell.chkSaveMdAuto.Value := gSaveMarkdownAutoEnabled ? 1 : 0
    gShell.chkSaveMdAuto.OnEvent("Click", Util_ToggleSaveMdAuto)

    ; ---- Save Markdown with Save As ----
    gShell.gui.Add("Text", "xm+15 y+35 c" DARK_TEXT, "Save Markdown As...")
    gShell.gui.Add("Text", "xm+15 y+5 c888888", "Save selection as .md with folder picker.  Hotkey: Ctrl+Alt+D")

    gShell.chkSaveMdAs := gShell.gui.Add("CheckBox", "xm+350 yp-18 c" DARK_TEXT, "ON")
    gShell.chkSaveMdAs.Value := gSaveMarkdownAsEnabled ? 1 : 0
    gShell.chkSaveMdAs.OnEvent("Click", Util_ToggleSaveMdAs)
}

Util_ToggleAlwaysOnTop(*) {
    global gShell, gAlwaysOnTop
    gAlwaysOnTop := gShell.chkAlwaysOnTop.Value ? true : false
    WinSetAlwaysOnTop(gAlwaysOnTop ? 1 : 0, "ahk_id " gShell.gui.Hwnd)
    gShell.chkAlwaysOnTop.Text := gAlwaysOnTop ? "ON" : "OFF"
    ToolTip(gAlwaysOnTop ? "Always on top ON" : "Always on top OFF")
    SetTimer(() => ToolTip(), -1500)
    SaveUtilityState()
}

Util_ToggleRememberPos(*) {
    global gShell, gRememberPos
    gRememberPos := gShell.chkRememberPos.Value ? true : false
    if gRememberPos
        SaveGuiPos()
    gShell.chkRememberPos.Text := gRememberPos ? "ON" : "OFF"
    ToolTip(gRememberPos ? "Remember position ON" : "Remember position OFF")
    SetTimer(() => ToolTip(), -1500)
    SaveUtilityState()
}

Util_ToggleSaveMdAuto(*) {
    global gShell, gSaveMarkdownAutoEnabled
    gSaveMarkdownAutoEnabled := gShell.chkSaveMdAuto.Value ? true : false
    gShell.chkSaveMdAuto.Text := gSaveMarkdownAutoEnabled ? "ON" : "OFF"
    ToolTip(gSaveMarkdownAutoEnabled ? "Quick Save Markdown ON" : "Quick Save Markdown OFF")
    SetTimer(() => ToolTip(), -1500)
    SaveUtilityState()
}

Util_ToggleSaveMdAs(*) {
    global gShell, gSaveMarkdownAsEnabled
    gSaveMarkdownAsEnabled := gShell.chkSaveMdAs.Value ? true : false
    gShell.chkSaveMdAs.Text := gSaveMarkdownAsEnabled ? "ON" : "OFF"
    ToolTip(gSaveMarkdownAsEnabled ? "Save Markdown As ON" : "Save Markdown As OFF")
    SetTimer(() => ToolTip(), -1500)
    SaveUtilityState()
}
