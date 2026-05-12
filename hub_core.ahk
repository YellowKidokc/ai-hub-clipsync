#Requires AutoHotkey v2.0+
#SingleInstance Force
#Warn LocalSameAsGlobal, Off
#Warn VarUnset, Off
#Include %A_ScriptDir%\WinCardinalMover.ahk

; ============================================================
; AI-HUB v2 — Dark Mode Hotkeys, Hotstrings & AI Assistant
; ============================================================
; Features: Hotkeys, Hotstrings, AI Chat (Claude + OpenAI), Custom Prompts
; Global Hotkeys:
;   Ctrl+Alt+Z    = Prompt Menu (select text first)
;   Ctrl+Alt+Space = Smart Fix (select all, fix grammar/spelling/coherence)
;   Ctrl+Alt+G    = Show/Hide GUI (non-negotiable)
;   Ctrl+Alt+A    = Quick AI Chat with selected text
;   Alt+H         = Dictation mic toggle (Win+H)
;   Ctrl+Alt+W    = Toggle Always On Top
;   Ctrl+Alt+Y    = Toggle Remember Position
;   Ctrl+Shift+Q  = Save selection as Markdown (Downloads)
;   Ctrl+Shift+W  = Save selection as Markdown (Save As)
; ============================================================

; ---------- HUB LOADED FLAG (modules check this) ----------
global HUB_CORE_LOADED := true

; ---------- DARK MODE COLORS (Deep Black) ----------
global DARK_BG := "0f0f0f"        ; Deep black background
global DARK_CTRL := "181818"      ; Control background
global DARK_BORDER := "2a2a2a"    ; Border color
global DARK_TEXT := "DDDDDD"      ; Bright text for contrast on deep black
global DARK_ACCENT := "3d5afe"    ; Accent color
global INPUT_BG := "1a1a1a"       ; Dark input fields
global INPUT_TEXT := "E0E0E0"     ; Light text on dark inputs

; ---------- CONFIG & STATE ----------
global CFG_DIR := A_ScriptDir "\config"
global HOTKEY_FILE := CFG_DIR "\hotkeys.ini"
global HOTSTR_FILE := CFG_DIR "\hotstrings.sav"
global DATA_FILE := CFG_DIR "\storage.json"
global CONFIG_FILE := CFG_DIR "\settings.ini"
global PROMPTS_FILE := CFG_DIR "\prompts.json"

global gItems := []               ; unified hotkey/hotstring list
global gHKMap := Map()            ; hotkey -> item mapping
global gHSMap := Map()            ; hotstring sig -> replacement
global gStoredData := []          ; data storage entries
global gChatHistory := []         ; AI chat history
global gSystemPrompts := []       ; saved system prompts [{name, content}]
global gActiveSystemPrompt := ""  ; currently active system prompt text
global SYSPROMPT_FILE := CFG_DIR "\sysprompts.json"
global gEditingIndex := 0         ; current editing row
global gShell := {}               ; GUI controls (Object, not Map!)
global gSelectedText := ""        ; text selected for prompt menu
global gPrompts := []             ; custom prompts list
global gEditingPromptIndex := 0   ; current editing prompt
global gPromptShortcuts := Map()  ; shortcut -> prompt index mapping
global gPopupMode := false        ; toggle for popup display
global gRememberPos := false      ; remember window position toggle
global gSavedX := ""              ; saved window X position
global gSavedY := ""              ; saved window Y position
global gAlwaysOnTop := false      ; always-on-top toggle
global gSaveMarkdownAutoEnabled := true   ; Ctrl+Shift+Q toggle
global gSaveMarkdownAsEnabled := true     ; Ctrl+Shift+W toggle

; ---------- TAB REGISTRY (modular tabs) ----------
; Tabs register themselves via RegisterTab(). The GUI builds tab order dynamically.
global gTabRegistry := []          ; Array of {name, buildFn, order}
global gTabIndex := Map()          ; name -> 1-based index

RegisterTab(name, buildFn, order := 100) {
    global gTabRegistry
    gTabRegistry.Push({ name: name, buildFn: buildFn, order: order })
}

TabIndex(name) {
    global gTabIndex
    return gTabIndex.Has(name) ? gTabIndex[name] : 0
}

SetActiveTabByName(name) {
    global gShell
    idx := TabIndex(name)
    if idx > 0
        gShell.tabs.Value := idx
}

RegisterBuiltInTabs() {
    ; Keep these orders stable so user modules can insert between them.
    RegisterTab("Shortcuts", BuildShortcutsTab, 10)
    RegisterTab("Prompts",   BuildPromptsTab,   20)
    RegisterTab("AI Chat",   BuildAIChatTab,    30)
    RegisterTab("Data",      BuildDataTab,      40)
    RegisterTab("Settings",  BuildSettingsTab,  99)
}

; ============================================================
; BOOTSTRAP (called from entry script)
; ============================================================

Hub_Boot() {
    ; Ensure directories and files exist
    EnsureConfig()
    try Hub_RunBackup()
    try Sync_Import()

    ; Load and register
    Load_All()
    LoadPrompts()
    Register_All()

    ; Register built-in tabs (core)
    RegisterBuiltInTabs()

    ; Let external modules register tabs/hotkeys/etc.
    ; (modules are #included by the entry script BEFORE Hub_Boot is called)

    ; Build and show GUI
    CreateMainGUI()
    ApplyLoadedUtilitySettings()
    SetupTray()

    ; Config sync: export on exit + every 30 minutes
    OnExit((*) => Sync_Export())
    SetTimer(() => Sync_Export(), 1800000)

    ; Pick up prompts saved from the standalone HTML without restarting AI-HUB.
    WatchPromptFile()
    SetTimer(WatchPromptFile, 5000)
}
; ============================================================
; CONFIGURATION SETUP
; ============================================================

EnsureConfig() {
    global CFG_DIR, HOTKEY_FILE, HOTSTR_FILE, DATA_FILE, CONFIG_FILE, PROMPTS_FILE

    if !DirExist(CFG_DIR)
        DirCreate(CFG_DIR)
    if !FileExist(HOTKEY_FILE)
        FileAppend("", HOTKEY_FILE)
    if !FileExist(HOTSTR_FILE)
        FileAppend("", HOTSTR_FILE)
    if !FileExist(DATA_FILE)
        FileAppend("[]", DATA_FILE)
    if !FileExist(CONFIG_FILE) {
        defaultCfg := "[Settings]`n"
        defaultCfg .= "provider=OpenAI`n"
        defaultCfg .= "apiKey=`n"
        defaultCfg .= "openaiKey=`n"
        defaultCfg .= "claudeKey=`n"
        defaultCfg .= "claudeEndpoint=https://api.anthropic.com/v1/messages`n"
        defaultCfg .= "openaiEndpoint=https://api.openai.com/v1/chat/completions`n"
        defaultCfg .= "claudeModel=claude-sonnet-4-20250514`n"
        defaultCfg .= "openaiModel=gpt-4o-mini`n"
        FileAppend(defaultCfg, CONFIG_FILE)
    }
    if !FileExist(PROMPTS_FILE) {
        FileAppend("[]", PROMPTS_FILE)
    }
}

; ============================================================
; MAIN GUI - DARK MODE STYLING
; ============================================================

CreateMainGUI() {
    global gShell, gTabRegistry, gTabIndex

    ; Create main window with dark background
    gShell.gui := Gui("+Resize", "AI-HUB v2 — Hotkeys, Hotstrings & AI")
    gShell.gui.SetFont("s10", "Segoe UI")
    gShell.gui.BackColor := DARK_BG

    ; Enable Windows dark mode for title bar
    if (VerCompare(A_OSVersion, "10.0.17763") >= 0) {
        DWMWA_USE_IMMERSIVE_DARK_MODE := 19
        if (VerCompare(A_OSVersion, "10.0.18985") >= 0)
            DWMWA_USE_IMMERSIVE_DARK_MODE := 20
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", gShell.gui.hWnd, "Int", DWMWA_USE_IMMERSIVE_DARK_MODE, "Int*", true, "Int", 4)
    }

    ; Sort registered tabs by order, then name (AHK v2 Arrays lack .Sort)
    SortTabRegistry()

    tabNames := []
    gTabIndex := Map()
    for i, t in gTabRegistry {
        tabNames.Push(t.name)
        gTabIndex[t.name] := i
    }

    ; Build tabs dynamically — NO bold on tab headers (7 tabs overflow with bold)
    gShell.gui.SetFont("s10 cWhite", "Segoe UI")
    gShell.tabs := gShell.gui.Add("Tab3", "xm ym w1120 h760", tabNames)
    ApplyDarkTheme(gShell.tabs)
    ; Switch to bold for tab CONTENT
    gShell.gui.SetFont("s10 Bold c" DARK_TEXT, "Segoe UI")

    ; Build each tab (call its builder while that tab is selected)
    for i, t in gTabRegistry {
        gShell.tabs.UseTab(i)
        try t.buildFn.Call()
        catch as e {
            MsgBox("Failed building tab: " t.name "`n`n" e.Message, "AI-HUB Tab Error", "Icon!")
        }
    }

    gShell.tabs.UseTab(0)
    ; Force dark backgrounds on controls that resist DarkMode_Explorer
    ApplyDarkToAllControls(gShell.gui)
    ; Events
    gShell.gui.OnEvent("Close", (*) => HideGui())
    gShell.gui.OnEvent("Size", OnGuiResize)

    ; Show
    gShell.gui.Show("w1140 h840")

    ; Load settings after GUI is visible
    LoadSettings()
}

SortTabRegistry() {
    global gTabRegistry
    n := gTabRegistry.Length
    if n <= 1
        return
    ; Bubble sort by .order, then .name
    loop n - 1 {
        swapped := false
        loop n - A_Index {
            j := A_Index
            a := gTabRegistry[j]
            b := gTabRegistry[j + 1]
            if (a.order > b.order) || (a.order = b.order && StrCompare(a.name, b.name) > 0) {
                gTabRegistry[j] := b
                gTabRegistry[j + 1] := a
                swapped := true
            }
        }
        if !swapped
            break
    }
}

ApplyDarkTheme(ctrl) {
    try DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
}

; Set ListView row text and background colors for dark mode
ApplyDarkListView(lv) {
    ApplyDarkTheme(lv)
    ; LVM_SETTEXTCOLOR = 0x1024, LVM_SETTEXTBKCOLOR = 0x1026, LVM_SETBKCOLOR = 0x1001
    ; COLORREF = 0x00BBGGRR
    textColor := 0x00DDDDDD    ; bright text
    bgColor   := 0x00151515    ; near-black background
    SendMessage(0x1024, 0, textColor, lv.hWnd)
    SendMessage(0x1026, 0, bgColor, lv.hWnd)
    SendMessage(0x1001, 0, bgColor, lv.hWnd)
}

ApplyInputTheme(ctrl) {
    global INPUT_BG, INPUT_TEXT
    try ctrl.Opt("Background" INPUT_BG)
    try ctrl.SetFont("c" INPUT_TEXT)
}

; Hide a window from the taskbar by toggling extended window styles
; Uses GetWindowLongPtr/SetWindowLongPtr for 64-bit compatibility (Windows 11)
HideFromTaskbar(hwnd) {
    GWL_EXSTYLE := -20
    WS_EX_APPWINDOW  := 0x40000
    WS_EX_TOOLWINDOW := 0x80
    exStyle := DllCall("GetWindowLongPtr", "Ptr", hwnd, "Int", GWL_EXSTYLE, "Ptr")
    exStyle := (exStyle | WS_EX_TOOLWINDOW) & ~WS_EX_APPWINDOW
    DllCall("SetWindowLongPtr", "Ptr", hwnd, "Int", GWL_EXSTYLE, "Ptr", exStyle)
    ; Force Windows to refresh the taskbar entry
    DllCall("ShowWindow", "Ptr", hwnd, "Int", 0)  ; SW_HIDE
    DllCall("ShowWindow", "Ptr", hwnd, "Int", 5)  ; SW_SHOW
}

; Force dark background on all child controls that resist DarkMode_Explorer
ApplyDarkToAllControls(guiObj) {
    global DARK_BG, DARK_CTRL, INPUT_BG, DARK_TEXT
    for hwnd, ctrl in guiObj {
        try {
            ctrlType := ctrl.Type
            if (ctrlType = "Edit" || ctrlType = "ComboBox" || ctrlType = "DDL" || ctrlType = "DropDownList") {
                ctrl.Opt("Background" INPUT_BG)
                ctrl.SetFont("c" DARK_TEXT)
            } else if (ctrlType = "Button" || ctrlType = "CheckBox") {
                ctrl.Opt("Background" DARK_CTRL)
            } else if (ctrlType = "ListBox") {
                ctrl.Opt("Background" INPUT_BG)
                ctrl.SetFont("c" DARK_TEXT)
            }
        }
    }
}

SetupTray() {
    ; Distinct hub icon (green circuit board = automation hub)
    try TraySetIcon("shell32.dll", 16)
    A_IconTip := "AI Hub v2"
    A_TrayMenu.Delete()
    A_TrayMenu.Add("Show GUI", (*) => ShowGui())
    A_TrayMenu.Add("Hide GUI", (*) => HideGui())
    A_TrayMenu.Add()
    A_TrayMenu.Add("Clipboard", (*) => LaunchHtmlPanel("http://127.0.0.1:3456/clipboard", "POF-Clipboard"))
    A_TrayMenu.Add("Prompts", (*) => LaunchHtmlPanel(FileUrl(A_ScriptDir "\modules\prompt_picker.html"), "POF-Prompts"))
    A_TrayMenu.Add("Links", (*) => LaunchHtmlPanel(FileUrl(A_ScriptDir "\modules\research_links.html"), "POF-Links"))
    A_TrayMenu.Add("DeepCrawl", (*) => LaunchHtmlPanel("https://7c0baad5.deepcrawl-gui.pages.dev/", "POF-DeepCrawl"))
    A_TrayMenu.Add("Show BetterTTS", (*) => TTS_TrayShow())
    A_TrayMenu.Add()
    A_TrayMenu.Add("Always On Top", TrayToggleAOT)
    A_TrayMenu.Add()
    A_TrayMenu.Add("Exit", (*) => ExitApp())
    A_TrayMenu.Default := "Show GUI"
    try A_TrayMenu.ClickCount := 1
}

TrayToggleAOT(*) {
    ToggleAlwaysOnTop()
    if gAlwaysOnTop
        A_TrayMenu.Check("Always On Top")
    else
        A_TrayMenu.Uncheck("Always On Top")
}


TTS_TrayShow(*) {
    try {
        DetectHiddenWindows(true)
        if WinExist("Better TTS")
            WinActivate("Better TTS")
        else
            try Run(A_ScriptDir "\BetterTTS\BetterTTS.ahk")
        DetectHiddenWindows(false)
    }
}

SaveGuiPos() {
    global gShell, gSavedX, gSavedY
    if WinExist("ahk_id " gShell.gui.Hwnd) {
        WinGetPos(&x, &y, , , "ahk_id " gShell.gui.Hwnd)
        ; Skip minimized coordinates (-32000) — Windows parks minimized windows there
        if (x > -10000 && y > -10000) {
            gSavedX := x
            gSavedY := y
        }
    }
}

SaveGuiPosIfRemember() {
    global gRememberPos
    if gRememberPos {
        SaveGuiPos()
        SaveUtilityState()
    }
}

ShowGui() {
    global gShell, gRememberPos, gSavedX, gSavedY
    if gRememberPos && gSavedX != "" && gSavedY != "" && gSavedX > -10000 && gSavedY > -10000
        gShell.gui.Show("x" gSavedX " y" gSavedY)
    else
        gShell.gui.Show()
}

HideGui() {
    SaveGuiPosIfRemember()
    gShell.gui.Hide()
}

ToggleGui() {
    global gShell
    ; Must detect hidden windows or toggle fails after HideGui()
    DetectHiddenWindows(true)
    if WinExist("ahk_id " gShell.gui.Hwnd) {
        if !DllCall("IsWindowVisible", "Ptr", gShell.gui.Hwnd)
            ShowGui()
        else if WinActive("ahk_id " gShell.gui.Hwnd)
            HideGui()
        else
            ShowGui()
    }
    DetectHiddenWindows(false)
}

ToggleAlwaysOnTop() {
    global gShell, gAlwaysOnTop
    gAlwaysOnTop := !gAlwaysOnTop
    WinSetAlwaysOnTop(gAlwaysOnTop ? 1 : 0, "ahk_id " gShell.gui.Hwnd)
    ; Sync Utilities tab checkbox if it exists
    try {
        gShell.chkAlwaysOnTop.Value := gAlwaysOnTop ? 1 : 0
        gShell.chkAlwaysOnTop.Text := gAlwaysOnTop ? "ON" : "OFF"
    }
    ; Sync tray menu checkmark
    try {
        if gAlwaysOnTop
            A_TrayMenu.Check("Always On Top")
        else
            A_TrayMenu.Uncheck("Always On Top")
    }
    ToolTip(gAlwaysOnTop ? "Always on top ON" : "Always on top OFF")
    SetTimer(() => ToolTip(), -1500)
    SaveUtilityState()
}

ToggleRememberPos() {
    global gRememberPos, gShell
    gRememberPos := !gRememberPos
    if gRememberPos
        SaveGuiPos()
    ; Sync Utilities tab checkbox if it exists
    try {
        gShell.chkRememberPos.Value := gRememberPos ? 1 : 0
        gShell.chkRememberPos.Text := gRememberPos ? "ON" : "OFF"
    }
    ToolTip(gRememberPos ? "Remember position ON" : "Remember position OFF")
    SetTimer(() => ToolTip(), -1500)
    SaveUtilityState()
}

; Quick-save just the [Utilities] section without touching API keys
SaveUtilityState() {
    global CONFIG_FILE, gAlwaysOnTop, gRememberPos
    global gSaveMarkdownAutoEnabled, gSaveMarkdownAsEnabled
    global gSavedX, gSavedY
    try {
        IniWrite(gAlwaysOnTop ? "1" : "0", CONFIG_FILE, "Utilities", "alwaysOnTop")
        IniWrite(gRememberPos ? "1" : "0", CONFIG_FILE, "Utilities", "rememberPos")
        IniWrite(gSaveMarkdownAutoEnabled ? "1" : "0", CONFIG_FILE, "Utilities", "saveMdAuto")
        IniWrite(gSaveMarkdownAsEnabled ? "1" : "0", CONFIG_FILE, "Utilities", "saveMdAs")
        IniWrite(gSavedX, CONFIG_FILE, "Utilities", "savedX")
        IniWrite(gSavedY, CONFIG_FILE, "Utilities", "savedY")
    }
}

; Apply loaded utility settings at startup
ApplyLoadedUtilitySettings() {
    global gShell, gAlwaysOnTop, gRememberPos
    try {
        if gAlwaysOnTop
            WinSetAlwaysOnTop(1, "ahk_id " gShell.gui.Hwnd)
    }
}

GetSelectedTextSelectAll() {
    oldClip := A_Clipboard
    A_Clipboard := ""
    Send("^a")
    Sleep(50)
    Send("^c")
    if !ClipWait(1) {
        A_Clipboard := oldClip
        return ""
    }
    text := A_Clipboard
    A_Clipboard := oldClip
    return text
}

MakeSafeFilename(text) {
    line := Trim(StrSplit(text, "`n", "`r")[1])
    line := RegExReplace(line, '[\\/:*?"<>|]', "")
    line := RegExReplace(line, "[^A-Za-z0-9 _-]", "")
    line := RegExReplace(line, "\s+", " ")
    line := Trim(line)
    if line = ""
        line := "note"
    if StrLen(line) > 60
        line := SubStr(line, 1, 60)
    return line
}

MakeMarkdownPath(text, baseDir) {
    name := MakeSafeFilename(text)
    ts := FormatTime(A_Now, "yyyyMMdd-HHmmss")
    path := baseDir "\" name "_" ts ".md"
    if !FileExist(path)
        return path
    idx := 2
    loop {
        path := baseDir "\" name "_" ts "_" idx ".md"
        if !FileExist(path)
            return path
        idx++
    }
}

SaveMarkdownAuto() {
    text := GetSelectedTextSelectAll()
    if text = "" {
        ToolTip("No text to save")
        SetTimer(() => ToolTip(), -1500)
        return
    }
    baseDir := EnvGet("USERPROFILE") "\Downloads"
    if !DirExist(baseDir)
        baseDir := A_ScriptDir
    path := MakeMarkdownPath(text, baseDir)
    try FileDelete(path)
    FileAppend(text, path, "UTF-8")
    ToolTip("Saved: " path)
    SetTimer(() => ToolTip(), -2000)
}

SaveMarkdownAs() {
    text := GetSelectedTextSelectAll()
    if text = "" {
        ToolTip("No text to save")
        SetTimer(() => ToolTip(), -1500)
        return
    }
    baseDir := EnvGet("USERPROFILE") "\Downloads"
    if !DirExist(baseDir)
        baseDir := A_ScriptDir
    defaultName := MakeSafeFilename(text) ".md"
    path := FileSelect("S16", baseDir "\" defaultName, "Save Markdown", "Markdown (*.md)")
    if !path
        return
    if !RegExMatch(path, "\.md$")
        path .= ".md"
    try FileDelete(path)
    FileAppend(text, path, "UTF-8")
    ToolTip("Saved: " path)
    SetTimer(() => ToolTip(), -2000)
}

; ============================================================
; TAB 1: SHORTCUTS (Hotkeys & Hotstrings)
; ============================================================

BuildShortcutsTab() {
    global gShell, gItems

    ; --- LEFT COLUMN: Editor ---
    gShell.gui.Add("Text", "xm+15 ym+45 c" DARK_TEXT, "Type:")
    gShell.typeDDL := gShell.gui.Add("DropDownList", "x+10 w140 Choose1", ["Hotkey", "Hotstring"])
    gShell.typeDDL.OnEvent("Change", (*) => UI_SwitchType())
    ApplyDarkTheme(gShell.typeDDL)
    ApplyInputTheme(gShell.typeDDL)

    gShell.gui.Add("Text", "xm+15 y+12 c" DARK_TEXT, "Action:")
    gShell.actionDDL := gShell.gui.Add("DropDownList", "x+10 w140 Choose1", ["Send Text", "Run Program/URL"])
    ApplyDarkTheme(gShell.actionDDL)
    ApplyInputTheme(gShell.actionDDL)

    gShell.gui.Add("Text", "xm+15 y+15 c" DARK_TEXT, "Modifiers:")
    gShell.chkCtrl := gShell.gui.Add("CheckBox", "x+10 c" DARK_TEXT, "Ctrl")
    gShell.chkAlt := gShell.gui.Add("CheckBox", "x+8 c" DARK_TEXT, "Alt")
    gShell.chkShift := gShell.gui.Add("CheckBox", "x+8 c" DARK_TEXT, "Shift")
    gShell.chkWin := gShell.gui.Add("CheckBox", "x+8 c" DARK_TEXT, "Win")
    gShell.chkCaps := gShell.gui.Add("CheckBox", "xm+15 y+5 c" DARK_TEXT, "CapsLock (as modifier)")

    gShell.gui.Add("Text", "xm+15 y+12 c" DARK_TEXT, "Key:")
    gShell.hotkeyCtrl := gShell.gui.Add("Hotkey", "x+30 w180")
    ApplyDarkTheme(gShell.hotkeyCtrl)
    ApplyInputTheme(gShell.hotkeyCtrl)

    gShell.lblHsTrigger := gShell.gui.Add("Text", "xm+15 y+12 c" DARK_TEXT " Hidden", "Trigger (CAPS 1-32):")
    gShell.hsTriggerEdit := gShell.gui.Add("Edit", "x+10 w180 Hidden", "")
    ApplyDarkTheme(gShell.hsTriggerEdit)
    ApplyInputTheme(gShell.hsTriggerEdit)

    gShell.gui.Add("Text", "xm+15 y+12 c" DARK_TEXT, "Description:")
    gShell.descEdit := gShell.gui.Add("Edit", "x+10 w280", "")
    ApplyDarkTheme(gShell.descEdit)
    ApplyInputTheme(gShell.descEdit)

    gShell.gui.Add("Text", "xm+15 y+12 c" DARK_TEXT, "Output / Payload:")
    gShell.outputEdit := gShell.gui.Add("Edit", "xm+15 y+5 w390 r5", "")
    ApplyDarkTheme(gShell.outputEdit)
    ApplyInputTheme(gShell.outputEdit)

    gShell.btnSave := gShell.gui.Add("Button", "xm+15 y+15 w90", "Add/Save")
    gShell.btnSave.OnEvent("Click", (*) => UI_AddOrSave())
    ApplyDarkTheme(gShell.btnSave)

    gShell.btnTest := gShell.gui.Add("Button", "x+8 w70", "Test")
    gShell.btnTest.OnEvent("Click", (*) => UI_Test())
    ApplyDarkTheme(gShell.btnTest)

    gShell.btnDelete := gShell.gui.Add("Button", "x+8 w70", "Delete")
    gShell.btnDelete.OnEvent("Click", (*) => UI_Delete())
    ApplyDarkTheme(gShell.btnDelete)

    gShell.btnExport := gShell.gui.Add("Button", "x+8 w100", "Export .ahk")
    gShell.btnExport.OnEvent("Click", (*) => UI_Export())
    ApplyDarkTheme(gShell.btnExport)

    gShell.enableHK := gShell.gui.Add("CheckBox", "xm+15 y+20 c" DARK_TEXT " Checked", "Enable Hotkeys")
    gShell.enableHS := gShell.gui.Add("CheckBox", "x+20 c" DARK_TEXT " Checked", "Enable Hotstrings")
    gShell.enableHK.OnEvent("Click", (*) => ReRegister())
    gShell.enableHS.OnEvent("Click", (*) => ReRegister())

    gShell.statusTxt := gShell.gui.Add("Text", "xm+15 y+15 w390 c888888", "Ready - " gItems.Length " items loaded")

    ; --- RIGHT COLUMN: Library ListView ---
    gShell.gui.Add("Text", "x440 ym+45 c" DARK_TEXT, "Library")
    gShell.libraryLV := gShell.gui.Add("ListView", "x440 y+8 w600 h400 -Multi +Grid VScroll",
        ["Type", "Trigger", "Description", "Output Preview"])
    gShell.libraryLV.OnEvent("Click", LV_OnClick)
    gShell.libraryLV.OnEvent("DoubleClick", LV_OnDoubleClick)
    ApplyDarkListView(gShell.libraryLV)

    UI_SwitchType()
    UI_Populate()
}

UI_SwitchType() {
    global gShell
    isHK := (gShell.typeDDL.Text = "Hotkey")
    for , ctrl in [gShell.actionDDL, gShell.chkCtrl, gShell.chkAlt, gShell.chkShift, gShell.chkWin, gShell.chkCaps, gShell.hotkeyCtrl]
        ctrl.Visible := isHK
    gShell.lblHsTrigger.Visible := !isHK
    gShell.hsTriggerEdit.Visible := !isHK
}

UI_Populate() {
    global gShell, gItems
    gShell.libraryLV.Delete()
    for it in gItems {
        preview := StrReplace(SubStr(it.Output, 1, 50), "`n", " | ")
        if StrLen(it.Output) > 50
            preview .= "..."
        gShell.libraryLV.Add("", it.Kind, it.Trigger, it.Desc, preview)
    }
    gShell.libraryLV.ModifyCol(1, 80)
    gShell.libraryLV.ModifyCol(2, 120)
    gShell.libraryLV.ModifyCol(3, 150)
    gShell.libraryLV.ModifyCol(4, 160)
    gShell.statusTxt.Text := "Ready - " gItems.Length " items loaded"
}

LV_OnClick(lv, row) {
    if row > 0 {
        UI_LoadRow(row)
        ; Copy output to clipboard ready to paste
        global gItems
        it := gItems[row]
        A_Clipboard := it.Output
        UI_Status("Copied output: " SubStr(it.Output, 1, 40) (StrLen(it.Output) > 40 ? "..." : ""))
    }
}

LV_OnDoubleClick(lv, row) {
    global gItems
    if row <= 0
        return
    it := gItems[row]
    text := GetKeyState("Shift") ? it.Trigger : it.Output
    A_Clipboard := text
    UI_Status("Copied " (GetKeyState("Shift") ? "trigger" : "output"))
}

UI_LoadRow(row) {
    global gShell, gItems, gEditingIndex
    it := gItems[row]
    gEditingIndex := row
    gShell.typeDDL.Text := it.Kind
    UI_SwitchType()
    gShell.descEdit.Value := it.Desc
    gShell.outputEdit.Value := it.Output
    if it.Kind = "Hotstring" {
        gShell.hsTriggerEdit.Value := it.Trigger
    } else {
        gShell.actionDDL.Text := (it.HasProp("Action") && it.Action = "run") ? "Run Program/URL" : "Send Text"
        gShell.chkCtrl.Value := InStr(it.Trigger, "^") ? 1 : 0
        gShell.chkAlt.Value := InStr(it.Trigger, "!") ? 1 : 0
        gShell.chkShift.Value := InStr(it.Trigger, "+") ? 1 : 0
        gShell.chkWin.Value := InStr(it.Trigger, "#") ? 1 : 0
        gShell.chkCaps.Value := InStr(it.Trigger, "CapsLock & ") ? 1 : 0
        base := it.Trigger
        base := StrReplace(base, "CapsLock & ")
        base := RegExReplace(base, "[\^\+!#]")
        gShell.hotkeyCtrl.Value := base
    }
}

UI_AddOrSave() {
    global gShell, gItems, gEditingIndex
    kind := gShell.typeDDL.Text
    desc := Trim(gShell.descEdit.Value)
    out := gShell.outputEdit.Value

    if kind = "Hotstring" {
        trig := Trim(gShell.hsTriggerEdit.Value)
        if trig = "" {
            UI_Status("Enter hotstring trigger")
            return
        }
        trig := StrUpper(trig)
        if StrLen(trig) > 32 {
            MsgBox("Max 32 chars for trigger.", "Limit", "Icon!")
            return
        }
        if !RegExMatch(trig, "^[A-Z0-9._-]{1,32}$") {
            UI_Status("Use A-Z, 0-9, . _ - only")
            return
        }
        item := {Kind: "Hotstring", Trigger: trig, Desc: desc, Output: out, Opts: "*C"}
    } else {
        if !gShell.hotkeyCtrl.Value {
            UI_Status("Pick a hotkey")
            return
        }
        trig := ""
        if gShell.chkCtrl.Value
            trig .= "^"
        if gShell.chkAlt.Value
            trig .= "!"
        if gShell.chkShift.Value
            trig .= "+"
        if gShell.chkWin.Value
            trig .= "#"
        if gShell.chkCaps.Value
            trig .= "CapsLock & "
        trig .= gShell.hotkeyCtrl.Value
        act := (gShell.actionDDL.Text = "Run Program/URL") ? "run" : "send"
        item := {Kind: "Hotkey", Trigger: trig, Desc: desc, Output: out, Action: act}
    }

    if gEditingIndex {
        gItems[gEditingIndex] := item
        gEditingIndex := 0
    } else {
        gItems.Push(item)
    }

    Save_All()
    ReRegister()
    UI_Populate()
    UI_ClearEditor()
    UI_Status("Saved!")
}

UI_Delete() {
    global gShell, gItems, gEditingIndex
    row := gShell.libraryLV.GetNext()
    if row = 0 {
        UI_Status("Select a row to delete")
        return
    }
    if MsgBox("Delete selected entry?", "Confirm", "YesNo Icon! 4096") = "Yes" {
        gItems.RemoveAt(row)
        gEditingIndex := 0
        Save_All()
        ReRegister()
        UI_Populate()
        UI_Status("Deleted")
    }
}

UI_Test() {
    global gShell
    text := gShell.outputEdit.Value
    if text = "" {
        UI_Status("No output to test")
        return
    }
    SafePaste(text)
    UI_Status("Sent to active window")
}

UI_Export() {
    global gShell, gItems
    code := "#Requires AutoHotkey v2.0+`n#SingleInstance Force`n`n"
    code .= "; Exported from AI-HUB v2`n"
    code .= "; " FormatTime(A_Now, "yyyy-MM-dd HH:mm") "`n`n"
    for it in gItems {
        if it.Kind = "Hotkey" {
            if it.HasProp("Action") && it.Action = "run"
                code .= it.Trigger ":: {`n    Run " Dq(it.Output) "`n}`n`n"
            else
                code .= it.Trigger ":: {`n    SendText(" Dq(it.Output) ")`n}`n`n"
        } else {
            opts := it.HasProp("Opts") ? it.Opts : "*C"
            code .= ":" opts ":" it.Trigger "::" it.Output "`n"
        }
    }
    gShell.gui.Opt("+OwnDialogs")
    path := FileSelect("S16", A_ScriptDir "\exported_shortcuts.ahk", "Export AHK", "AHK (*.ahk)")
    if !path
        return
    try FileDelete(path)
    FileAppend(code, path)
    UI_Status("Exported: " path)
}

UI_ClearEditor() {
    global gShell
    gShell.descEdit.Value := ""
    gShell.outputEdit.Value := ""
    gShell.hsTriggerEdit.Value := ""
    gShell.hotkeyCtrl.Value := ""
    gShell.chkCtrl.Value := 0
    gShell.chkAlt.Value := 0
    gShell.chkShift.Value := 0
    gShell.chkWin.Value := 0
    gShell.chkCaps.Value := 0
}

UI_Status(msg) {
    global gShell
    gShell.statusTxt.Text := msg
    SetTimer(() => (gShell.statusTxt.Text := "Ready - " gItems.Length " items loaded"), -3000)
}

; ============================================================
; TAB 2: PROMPTS (Custom AI Prompts)
; ============================================================

BuildPromptsTab() {
    global gShell, gPrompts

    gShell.gui.Add("Text", "xm+15 ym+45 c" DARK_TEXT, "Create/Edit prompts for /slash commands")
    gShell.gui.SetFont("s9 Bold", "Segoe UI")

    gShell.gui.Add("Text", "xm+15 y+25 c" DARK_TEXT, "Command:")
    gShell.promptNameEdit := gShell.gui.Add("Edit", "x+10 w150 Lowercase", "")
    ApplyDarkTheme(gShell.promptNameEdit)
    ApplyInputTheme(gShell.promptNameEdit)
    gShell.gui.Add("Text", "x+10 c888888", "(name + /slash trigger, e.g. fix → /fix)")
    ; Hidden shortcut edit kept in sync with name for backward compat
    gShell.promptShortcutEdit := gShell.gui.Add("Edit", "x+0 w0 h0 Hidden", "")

    gShell.gui.Add("Text", "xm+15 y+25 c" DARK_TEXT, "Prompt Template:")
    gShell.gui.Add("Text", "xm+15 y+5 c888888", "Use {text} where selected text goes, or leave empty to append at end")
    gShell.promptTemplateEdit := gShell.gui.Add("Edit", "xm+15 y+8 w440 r14 VScroll", "")
    ApplyDarkTheme(gShell.promptTemplateEdit)
    ApplyInputTheme(gShell.promptTemplateEdit)

    gShell.gui.Add("Text", "xm+15 y+15 c" DARK_TEXT, "Options:")
    gShell.promptReplaceChk := gShell.gui.Add("CheckBox", "x+10 c" DARK_TEXT " Checked", "Replace selected text")
    gShell.promptPopupChk := gShell.gui.Add("CheckBox", "x+15 c" DARK_TEXT, "Show in popup instead")

    gShell.btnSavePrompt := gShell.gui.Add("Button", "xm+15 y+20 w100", "Add/Save")
    gShell.btnSavePrompt.OnEvent("Click", (*) => SavePrompt())
    ApplyDarkTheme(gShell.btnSavePrompt)

    gShell.btnNewPrompt := gShell.gui.Add("Button", "x+10 w100", "New")
    gShell.btnNewPrompt.OnEvent("Click", (*) => ClearPromptEditor())
    ApplyDarkTheme(gShell.btnNewPrompt)

    gShell.btnDeletePrompt := gShell.gui.Add("Button", "x+10 w100", "Delete")
    gShell.btnDeletePrompt.OnEvent("Click", (*) => DeletePrompt())
    ApplyDarkTheme(gShell.btnDeletePrompt)

    gShell.btnSendToChat := gShell.gui.Add("Button", "x+10 w100", "Send to Chat")
    gShell.btnSendToChat.OnEvent("Click", (*) => SendPromptToChat())
    ApplyDarkTheme(gShell.btnSendToChat)

    gShell.btnMoveUp := gShell.gui.Add("Button", "xm+15 y+10 w120", "Move Up")
    gShell.btnMoveUp.OnEvent("Click", (*) => MovePrompt(-1))
    ApplyDarkTheme(gShell.btnMoveUp)

    gShell.btnMoveDown := gShell.gui.Add("Button", "x+10 w120", "Move Down")
    gShell.btnMoveDown.OnEvent("Click", (*) => MovePrompt(1))
    ApplyDarkTheme(gShell.btnMoveDown)

    gShell.promptStatusTxt := gShell.gui.Add("Text", "xm+15 y+18 w440 c888888", "")

    ; --- RIGHT COLUMN: Prompt Library (scrollable) ---
    gShell.gui.Add("Text", "x520 ym+45 c" DARK_TEXT, "Your Prompts")
    gShell.promptsLV := gShell.gui.Add("ListView", "x520 y+8 w540 h630 -Multi +Grid VScroll",
        ["Command", "Preview"])
    gShell.promptsLV.OnEvent("Click", PromptLV_OnClick)
    gShell.promptsLV.OnEvent("DoubleClick", PromptLV_OnDoubleClick)
    ApplyDarkListView(gShell.promptsLV)

    RefreshPromptsLV()
}

AddQuickTemplate(tpl, *) {
    global gShell, gPrompts
    prompt := {
        name: StrReplace(tpl.name, "+ ", ""),
        template: tpl.prompt,
        replace: true,
        popup: false
    }
    gPrompts.Push(prompt)
    SavePrompts()
    RefreshPromptsLV()
    gShell.promptStatusTxt.Text := "Added: " prompt.name
    SetTimer(() => (gShell.promptStatusTxt.Text := ""), -2000)
}

SavePrompt(*) {
    global gShell, gPrompts, gEditingPromptIndex
    name := Trim(gShell.promptNameEdit.Value)
    template := gShell.promptTemplateEdit.Value
    name := RegExReplace(name, "^/+", "")
    if name != ""
        name := "/" name
    shortcut := RegExReplace(StrLower(name), "[^a-z0-9]", "")  ; Auto-derive slash trigger from name
    shortcut := RegExReplace(shortcut, "[^a-z0-9]", "")  ; Only allow letters and numbers
    if name = "" {
        gShell.promptStatusTxt.Text := "Enter a command name"
        return
    }
    if template = "" {
        gShell.promptStatusTxt.Text := "Enter a prompt template"
        return
    }
    if shortcut != "" && StrLen(shortcut) > 10 {
        gShell.promptStatusTxt.Text := "Shortcut max 10 characters"
        return
    }
    prompt := {
        name: name,
        template: template,
        shortcut: shortcut,
        replace: gShell.promptReplaceChk.Value ? true : false,
        popup: gShell.promptPopupChk.Value ? true : false
    }
    if gEditingPromptIndex > 0 {
        gPrompts[gEditingPromptIndex] := prompt
        gEditingPromptIndex := 0
    } else {
        gPrompts.Push(prompt)
    }
    SavePrompts()
    RegisterPromptShortcuts()
    RefreshPromptsLV()
    ClearPromptEditor()
    gShell.promptStatusTxt.Text := "Saved: " name
    SetTimer(() => (gShell.promptStatusTxt.Text := ""), -2000)
}

DeletePrompt(*) {
    global gShell, gPrompts, gEditingPromptIndex
    row := gShell.promptsLV.GetNext()
    if row <= 0 {
        gShell.promptStatusTxt.Text := "Select a prompt to delete"
        return
    }
    if MsgBox("Delete this prompt?", "Confirm", "YesNo Icon!") = "Yes" {
        gPrompts.RemoveAt(row)
        gEditingPromptIndex := 0
        SavePrompts()
        RefreshPromptsLV()
        ClearPromptEditor()
        gShell.promptStatusTxt.Text := "Deleted"
    }
}

MovePrompt(direction) {
    global gShell, gPrompts
    row := gShell.promptsLV.GetNext()
    if row <= 0
        return
    newPos := row + direction
    if newPos < 1 || newPos > gPrompts.Length
        return
    temp := gPrompts[row]
    gPrompts[row] := gPrompts[newPos]
    gPrompts[newPos] := temp
    SavePrompts()
    RefreshPromptsLV()
    gShell.promptsLV.Modify(newPos, "Select Focus")
}

ClearPromptEditor(*) {
    global gShell, gEditingPromptIndex
    gEditingPromptIndex := 0
    gShell.promptNameEdit.Value := ""
    gShell.promptShortcutEdit.Value := ""  ; hidden, kept in sync
    gShell.promptTemplateEdit.Value := ""
    gShell.promptReplaceChk.Value := 1
    gShell.promptPopupChk.Value := 0
}

RefreshPromptsLV() {
    global gShell, gPrompts
    gShell.promptsLV.Delete()
    for i, p in gPrompts {
        preview := StrReplace(SubStr(p.template, 1, 80), "`n", " ")
        cmdName := p.HasProp("shortcut") && p.shortcut != "" ? "/" p.shortcut : p.name
        gShell.promptsLV.Add("", cmdName, preview)
    }
    gShell.promptsLV.ModifyCol(1, 120)
    gShell.promptsLV.ModifyCol(2, 390)
}

PromptLV_OnClick(lv, row) {
    global gShell, gPrompts, gEditingPromptIndex
    if row <= 0 || row > gPrompts.Length
        return
    p := gPrompts[row]
    gEditingPromptIndex := row
    gShell.promptNameEdit.Value := p.name
    gShell.promptShortcutEdit.Value := ""  ; hidden, auto-derived on save
    gShell.promptTemplateEdit.Value := p.template
    gShell.promptReplaceChk.Value := p.HasProp("replace") ? p.replace : true
    gShell.promptPopupChk.Value := p.HasProp("popup") ? p.popup : false
    ; Copy template to clipboard ready to paste
    A_Clipboard := p.template
    gShell.promptStatusTxt.Text := "Copied: " p.name " (ready to paste)"
    SetTimer(() => (gShell.promptStatusTxt.Text := ""), -2000)
}

PromptLV_OnDoubleClick(lv, row) {
    global gPrompts
    if row <= 0 || row > gPrompts.Length
        return
    TestPromptWithClipboard(row)
}

TestPromptWithClipboard(index) {
    global gPrompts
    if index <= 0 || index > gPrompts.Length
        return
    p := gPrompts[index]
    testText := A_Clipboard
    if testText = "" {
        MsgBox("Copy some text to clipboard first, then double-click to test.", "Test Prompt", "Icon!")
        return
    }
    if InStr(p.template, "{text}")
        fullPrompt := StrReplace(p.template, "{text}", testText)
    else
        fullPrompt := p.template "`n`n" testText
    ToolTip("Testing prompt...")
    response := CallAI(fullPrompt, [])
    ToolTip()
    MsgBox("Result:`n`n" response, "Prompt Test: " p.name, "Iconi")
}

LoadPrompts() {
    global gPrompts, PROMPTS_FILE
    gPrompts := []
    if !FileExist(PROMPTS_FILE)
        return
    try {
        jsonStr := FileRead(PROMPTS_FILE, "UTF-8")
        if jsonStr = "" || jsonStr = "[]"
            return
        jsonStr := Trim(jsonStr)
        if SubStr(jsonStr, 1, 1) != "["
            return
        pattern := '\{"name":"([^"]*)".*?"template":"((?:[^"\\]|\\.)*)"'
        pos := 1
        while RegExMatch(jsonStr, pattern, &m, pos) {
            ; Find the end of this object
            objStart := m.Pos
            objEnd := InStr(jsonStr, "}", , objStart)
            objStr := SubStr(jsonStr, objStart, objEnd - objStart + 1)

            ; Extract optional fields
            shortcut := ""
            if RegExMatch(objStr, '"shortcut"\s*:\s*"([^"]*)"', &sm)
                shortcut := sm[1]
            replaceVal := true
            if RegExMatch(objStr, '"replace"\s*:\s*(true|false)', &rm)
                replaceVal := (rm[1] = "true")
            popupVal := false
            if RegExMatch(objStr, '"popup"\s*:\s*(true|false)', &pm)
                popupVal := (pm[1] = "true")

            gPrompts.Push({
                name: UnescapeJSON(m[1]),
                template: UnescapeJSON(m[2]),
                shortcut: shortcut,
                replace: replaceVal,
                popup: popupVal
            })
            pos := objEnd + 1
        }
    }
    RegisterPromptShortcuts()
}

SavePrompts() {
    global gPrompts, PROMPTS_FILE
    jsonStr := "["
    for i, p in gPrompts {
        jsonStr .= "`n  {"
        jsonStr .= '"name":"' EscapeJSON(p.name) '", '
        jsonStr .= '"template":"' EscapeJSON(p.template) '", '
        jsonStr .= '"shortcut":"' (p.HasProp("shortcut") ? p.shortcut : "") '", '
        jsonStr .= '"replace":' (p.replace ? "true" : "false") ', '
        jsonStr .= '"popup":' (p.popup ? "true" : "false")
        jsonStr .= "}" (i < gPrompts.Length ? "," : "")
    }
    jsonStr .= "`n]"
    try FileDelete(PROMPTS_FILE)
    FileAppend(jsonStr, PROMPTS_FILE, "UTF-8")
}

; Register /slash command shortcuts for prompts
RegisterPromptShortcuts() {
    global gPrompts, gPromptShortcuts
    
    ; First unregister any existing prompt shortcuts
    for sig, _ in gPromptShortcuts {
        try Hotstring(sig, , false)
    }
    gPromptShortcuts.Clear()
    
    ; Register new shortcuts
    for i, p in gPrompts {
        if !p.HasProp("shortcut") || p.shortcut = ""
            continue
        
        ; Register immediate slash commands like /probe without requiring a trailing space.
        shortcut := "/" p.shortcut
        sig := ":*?:" shortcut
        
        ; Store the index and use a handler that looks it up
        try {
            Hotstring(sig, RunPromptShortcut.Bind(i), true)
            gPromptShortcuts[sig] := i
        }
    }
}

; Handler for /slash shortcuts — pastes the prompt template at cursor
RunPromptShortcut(index, *) {
    global gPrompts

    if index <= 0 || index > gPrompts.Length
        return

    p := gPrompts[index]

    ; Clear the typed shortcut by backspacing
    shortcutLen := StrLen("/" p.shortcut)
    Send("{Backspace " shortcutLen "}")
    Sleep(50)

    ; Paste the template directly at cursor
    SafePaste(p.template)
}

WatchPromptFile() {
    global PROMPTS_FILE, gShell
    static lastMTime := ""

    if !FileExist(PROMPTS_FILE)
        return

    mtime := FileGetTime(PROMPTS_FILE, "M")
    if (lastMTime = "") {
        lastMTime := mtime
        return
    }
    if (mtime = lastMTime)
        return

    lastMTime := mtime
    LoadPrompts()
    try RefreshPromptsLV()
    try gShell.promptStatusTxt.Text := "Prompts synced from HTML"
    try SetTimer(() => (gShell.promptStatusTxt.Text := ""), -2000)
}

; ============================================================
; TAB 3: AI CHAT
; ============================================================

BuildAIChatTab() {
    global gShell, gSystemPrompts, gActiveSystemPrompt

    ; --- System Prompt Section ---
    gShell.gui.Add("Text", "xm+15 ym+45 c" DARK_TEXT, "System Prompt:")
    gShell.syspromptDDL := gShell.gui.Add("DropDownList", "x+10 w200 Choose1", ["(none)"])
    gShell.syspromptDDL.OnEvent("Change", (*) => SysPromptDDL_OnChange())
    ApplyDarkTheme(gShell.syspromptDDL)

    gShell.btnSaveSysPrompt := gShell.gui.Add("Button", "x+10 w60", "Save")
    gShell.btnSaveSysPrompt.OnEvent("Click", (*) => SaveSysPrompt())
    ApplyDarkTheme(gShell.btnSaveSysPrompt)

    gShell.btnDeleteSysPrompt := gShell.gui.Add("Button", "x+5 w60", "Delete")
    gShell.btnDeleteSysPrompt.OnEvent("Click", (*) => DeleteSysPrompt())
    ApplyDarkTheme(gShell.btnDeleteSysPrompt)

    gShell.gui.Add("Text", "x+20 c888888", "Name:")
    gShell.syspromptNameEdit := gShell.gui.Add("Edit", "x+5 w150", "")
    ApplyDarkTheme(gShell.syspromptNameEdit)
    ApplyInputTheme(gShell.syspromptNameEdit)

    gShell.syspromptEdit := gShell.gui.Add("Edit", "xm+15 y+5 w1020 r3", "")
    ApplyDarkTheme(gShell.syspromptEdit)
    ApplyInputTheme(gShell.syspromptEdit)

    ; --- Conversation ---
    gShell.gui.Add("Text", "xm+15 y+10 c" DARK_TEXT, "Conversation")
    gShell.chatDisplay := gShell.gui.Add("Edit", "xm+15 y+5 w1020 h290 ReadOnly Multi VScroll",
        "Welcome to AI-HUB Chat!`n`n" .
        "Configure your API key in Settings tab.`n`n" .
        "HOTKEYS:`n" .
        "  Ctrl+Alt+Z = PROMPT MENU (select text first)`n" .
        "  Ctrl+Alt+Space = Smart Fix (selects all, fixes everything)`n" .
        "  Ctrl+Alt+G = Show/Hide this window`n" .
        "  Ctrl+Alt+A = Quick chat with selected text`n`n" .
        "---------------------------------------`n")
    ApplyDarkTheme(gShell.chatDisplay)
    try gShell.chatDisplay.Opt("Background" DARK_CTRL)
    try gShell.chatDisplay.SetFont("c" DARK_TEXT)

    gShell.gui.Add("Text", "xm+15 y+10 c" DARK_TEXT, "Your Message:")
    gShell.chatInput := gShell.gui.Add("Edit", "xm+15 y+5 w900 r3", "")
    ApplyDarkTheme(gShell.chatInput)
    ApplyInputTheme(gShell.chatInput)

    gShell.btnSend := gShell.gui.Add("Button", "x+10 yp w100 h50", "Send")
    gShell.btnSend.OnEvent("Click", (*) => SendChatMessage())
    ApplyDarkTheme(gShell.btnSend)

    gShell.btnClearChat := gShell.gui.Add("Button", "xp y+5 w100", "Clear")
    gShell.btnClearChat.OnEvent("Click", (*) => ClearChat())
    ApplyDarkTheme(gShell.btnClearChat)

    gShell.btnExportChat := gShell.gui.Add("Button", "xp y+5 w100", "Export .md")
    gShell.btnExportChat.OnEvent("Click", (*) => ExportChatMarkdown())
    ApplyDarkTheme(gShell.btnExportChat)

    gShell.btnSaveAsPrompt := gShell.gui.Add("Button", "xp y+5 w100", "Save Prompt")
    gShell.btnSaveAsPrompt.OnEvent("Click", (*) => SaveLastUserMsgAsPrompt())
    ApplyDarkTheme(gShell.btnSaveAsPrompt)

    gShell.gui.Add("Text", "xm+15 y+15 c" DARK_TEXT, "Quick Prompts:")
    prompts := [
        {name: "Fix Grammar", prefix: "Fix the grammar and spelling, return only the corrected text:"},
        {name: "Summarize", prefix: "Summarize this concisely:"},
        {name: "Explain", prefix: "Explain this in simple terms:"},
        {name: "Translate>EN", prefix: "Translate this to English:"},
        {name: "Code Review", prefix: "Review this code and suggest improvements:"}
    ]
    for i, p in prompts {
        xPos := (i = 1) ? "x+10" : "x+5"
        btn := gShell.gui.Add("Button", xPos " w100", p.name)
        btn.OnEvent("Click", QuickPrompt.Bind(p.prefix))
        ApplyDarkTheme(btn)
    }

    LoadSysPrompts()
}

SendChatMessage(*) {
    global gShell, gChatHistory
    userMsg := gShell.chatInput.Value
    if userMsg = ""
        return
    current := gShell.chatDisplay.Value
    current .= "`nYou: " userMsg "`n"
    gShell.chatDisplay.Value := current
    gChatHistory.Push({role: "user", content: userMsg})
    gShell.chatInput.Value := ""
    gShell.chatDisplay.Value .= "`nProcessing...`n"
    sysPrompt := ""
    try sysPrompt := gShell.syspromptEdit.Value
    response := CallAI(userMsg, gChatHistory, sysPrompt)
    current := gShell.chatDisplay.Value
    current := StrReplace(current, "`nProcessing...`n", "")
    current .= "`nAI: " response "`n`n---------------------------------------`n"
    gShell.chatDisplay.Value := current
    gChatHistory.Push({role: "assistant", content: response})
    SendMessage(0x115, 7, 0, gShell.chatDisplay.Hwnd)
}

QuickPrompt(prefix, *) {
    global gShell
    current := gShell.chatInput.Value
    gShell.chatInput.Value := prefix "`n`n" current
}

ClearChat(*) {
    global gShell, gChatHistory
    gChatHistory := []
    gShell.chatDisplay.Value := "Chat cleared.`n`n---------------------------------------`n"
}

; ============================================================
; CHAT EXPORT — Save conversation as Markdown
; ============================================================
ExportChatMarkdown(*) {
    global gShell, gChatHistory
    if gChatHistory.Length = 0 {
        ToolTip("No conversation to export")
        SetTimer(() => ToolTip(), -1500)
        return
    }

    ; Build markdown content
    ts := FormatTime(A_Now, "yyyy-MM-dd HH:mm")
    md := "# AI-HUB Chat Export`n"
    md .= "**Date:** " ts "`n"
    md .= "**Messages:** " gChatHistory.Length "`n`n"
    md .= "---`n`n"

    for i, msg in gChatHistory {
        role := (msg.role = "user") ? "**You**" : "**AI**"
        md .= role "`n`n" msg.content "`n`n---`n`n"
    }

    ; Save to Downloads
    baseDir := EnvGet("USERPROFILE") "\Downloads"
    if !DirExist(baseDir)
        baseDir := A_ScriptDir
    name := "chat_" FormatTime(A_Now, "yyyyMMdd_HHmmss") ".md"
    path := baseDir "\" name
    try FileDelete(path)
    FileAppend(md, path, "UTF-8")

    ; Also try to save to Obsidian vault if it exists
    vaultPath := "O:\_Theophysics_v3\04_THEOPYHISCS\AI_CHAT_LOGS"
    if DirExist("O:\_Theophysics_v3\04_THEOPYHISCS") {
        if !DirExist(vaultPath)
            DirCreate(vaultPath)
        vaultFile := vaultPath "\" name
        try FileDelete(vaultFile)
        try FileAppend(md, vaultFile, "UTF-8")
    }

    ToolTip("Chat exported: " name)
    SetTimer(() => ToolTip(), -2500)

    ; Toast notification
    try TrayTip("Chat Exported", name, "Iconi")
}

; ============================================================
; SAVE LAST USER MESSAGE AS PROMPT
; ============================================================
SaveLastUserMsgAsPrompt(*) {
    global gShell, gChatHistory, gPrompts

    ; Find last user message
    lastMsg := ""
    loop gChatHistory.Length {
        idx := gChatHistory.Length - A_Index + 1
        if gChatHistory[idx].role = "user" {
            lastMsg := gChatHistory[idx].content
            break
        }
    }

    if lastMsg = "" {
        ToolTip("No user message to save")
        SetTimer(() => ToolTip(), -1500)
        return
    }

    ; Ask for a name
    result := InputBox("Name this prompt:", "Save as Prompt", "w300 h120", "")
    if result.Result != "OK" || Trim(result.Value) = ""
        return

    name := Trim(result.Value)
    shortcut := RegExReplace(StrLower(name), "[^a-z0-9]", "")

    gPrompts.Push({
        name: name,
        template: lastMsg,
        shortcut: shortcut,
        replace: true,
        popup: false
    })
    SavePrompts()
    RegisterPromptShortcuts()
    try RefreshPromptsLV()

    ToolTip("Saved prompt: " name)
    SetTimer(() => ToolTip(), -2000)
}

; ============================================================
; SEND PROMPT TO CHAT — Load prompt template into chat input
; ============================================================
SendPromptToChat(*) {
    global gShell, gPrompts, gEditingPromptIndex

    idx := gEditingPromptIndex
    if idx <= 0 || idx > gPrompts.Length {
        ; Try selected row
        try {
            row := gShell.promptsLV.GetNext()
            if row > 0
                idx := row
        }
    }
    if idx <= 0 || idx > gPrompts.Length {
        ToolTip("Select a prompt first")
        SetTimer(() => ToolTip(), -1500)
        return
    }

    p := gPrompts[idx]

    ; Switch to AI Chat tab and load template into input
    SetActiveTabByName("AI Chat")
    gShell.chatInput.Value := p.template
    gShell.chatInput.Focus()

    ToolTip("Loaded '" p.name "' into chat — edit and send")
    SetTimer(() => ToolTip(), -2000)
}

; ---------- SYSTEM PROMPT MANAGEMENT ----------
LoadSysPrompts() {
    global gSystemPrompts, gShell, SYSPROMPT_FILE
    gSystemPrompts := []
    if !FileExist(SYSPROMPT_FILE) {
        RefreshSysPromptDDL()
        return
    }
    try {
        raw := FileRead(SYSPROMPT_FILE, "UTF-8")
        if raw = "" || raw = "[]" {
            RefreshSysPromptDDL()
            return
        }
        pattern := '\{"name":"((?:[^"\\]|\\.)*)".*?"content":"((?:[^"\\]|\\.)*)"'
        pos := 1
        while RegExMatch(raw, pattern, &m, pos) {
            objEnd := InStr(raw, "}", , m.Pos)
            gSystemPrompts.Push({name: UnescapeJSON(m[1]), content: UnescapeJSON(m[2])})
            pos := objEnd + 1
        }
    }
    RefreshSysPromptDDL()
}

RefreshSysPromptDDL() {
    global gShell, gSystemPrompts
    names := ["(none)"]
    for i, sp in gSystemPrompts
        names.Push(sp.name)
    gShell.syspromptDDL.Delete()
    gShell.syspromptDDL.Add(names)
    gShell.syspromptDDL.Choose(1)
}

SysPromptDDL_OnChange() {
    global gShell, gSystemPrompts, gActiveSystemPrompt
    idx := gShell.syspromptDDL.Value
    if idx <= 1 {
        gShell.syspromptEdit.Value := ""
        gActiveSystemPrompt := ""
    } else {
        sp := gSystemPrompts[idx - 1]
        gShell.syspromptEdit.Value := sp.content
        gActiveSystemPrompt := sp.content
    }
}

SaveSysPrompt(*) {
    global gShell, gSystemPrompts, SYSPROMPT_FILE
    name := Trim(gShell.syspromptNameEdit.Value)
    content := gShell.syspromptEdit.Value
    if name = "" {
        MsgBox("Enter a name for the system prompt.", "Save", "Icon!")
        return
    }
    if content = "" {
        MsgBox("Enter system prompt content.", "Save", "Icon!")
        return
    }
    ; Update existing or add new
    found := false
    for i, sp in gSystemPrompts {
        if sp.name = name {
            gSystemPrompts[i] := {name: name, content: content}
            found := true
            break
        }
    }
    if !found
        gSystemPrompts.Push({name: name, content: content})
    PersistSysPrompts()
    RefreshSysPromptDDL()
    ; Select the saved one
    for i, sp in gSystemPrompts {
        if sp.name = name {
            gShell.syspromptDDL.Choose(i + 1)
            break
        }
    }
}

DeleteSysPrompt(*) {
    global gShell, gSystemPrompts
    idx := gShell.syspromptDDL.Value
    if idx <= 1
        return
    if MsgBox("Delete system prompt?", "Confirm", "YesNo Icon!") = "Yes" {
        gSystemPrompts.RemoveAt(idx - 1)
        PersistSysPrompts()
        RefreshSysPromptDDL()
        gShell.syspromptEdit.Value := ""
    }
}

PersistSysPrompts() {
    global gSystemPrompts, SYSPROMPT_FILE
    jsonStr := "["
    for i, sp in gSystemPrompts {
        jsonStr .= '`n  {"name":"' EscapeJSON(sp.name) '", "content":"' EscapeJSON(sp.content) '"}'
        jsonStr .= (i < gSystemPrompts.Length ? "," : "")
    }
    jsonStr .= "`n]"
    try FileDelete(SYSPROMPT_FILE)
    FileAppend(jsonStr, SYSPROMPT_FILE, "UTF-8")
}

; ============================================================
; TAB 4: DATA STORAGE
; ============================================================

BuildDataTab() {
    global gShell
    gShell.gui.Add("Text", "xm+15 ym+45 c" DARK_TEXT, "Add New Entry")

    gShell.gui.Add("Text", "xm+15 y+15 c" DARK_TEXT, "Category:")
    gShell.dataCatDDL := gShell.gui.Add("DropDownList", "x+10 w200 Choose1", [
        "General", "Personal", "API Keys", "Phone",
        "Email", "Address", "Dates", "Passwords", "Notes"
    ])
    ApplyDarkTheme(gShell.dataCatDDL)
    ApplyInputTheme(gShell.dataCatDDL)

    gShell.gui.Add("Text", "xm+15 y+12 c" DARK_TEXT, "Name:")
    gShell.dataNameEdit := gShell.gui.Add("Edit", "x+35 w250", "")
    ApplyDarkTheme(gShell.dataNameEdit)
    ApplyInputTheme(gShell.dataNameEdit)

    gShell.gui.Add("Text", "xm+15 y+12 c" DARK_TEXT, "Value:")
    gShell.dataValueEdit := gShell.gui.Add("Edit", "x+35 w250 r4", "")
    ApplyDarkTheme(gShell.dataValueEdit)
    ApplyInputTheme(gShell.dataValueEdit)

    gShell.gui.Add("Text", "xm+15 y+12 c" DARK_TEXT, "Tags:")
    gShell.dataTagsEdit := gShell.gui.Add("Edit", "x+40 w250", "")
    ApplyDarkTheme(gShell.dataTagsEdit)
    ApplyInputTheme(gShell.dataTagsEdit)

    gShell.btnAddData := gShell.gui.Add("Button", "xm+15 y+15 w120", "Add Entry")
    gShell.btnAddData.OnEvent("Click", (*) => AddDataEntry())
    ApplyDarkTheme(gShell.btnAddData)

    gShell.btnPasteData := gShell.gui.Add("Button", "x+10 w120", "Paste Value")
    gShell.btnPasteData.OnEvent("Click", (*) => (gShell.dataValueEdit.Value := A_Clipboard))
    ApplyDarkTheme(gShell.btnPasteData)

    gShell.gui.Add("Text", "x420 ym+45 c" DARK_TEXT, "Stored Data")
    gShell.gui.Add("Text", "x420 y+10 c888888", "Filter:")
    gShell.dataFilterDDL := gShell.gui.Add("DropDownList", "x+5 w120 Choose1", [
        "All", "General", "Personal", "API Keys", "Phone",
        "Email", "Address", "Dates", "Passwords", "Notes"
    ])
    gShell.dataFilterDDL.OnEvent("Change", (*) => RefreshDataList())
    ApplyDarkTheme(gShell.dataFilterDDL)
    ApplyInputTheme(gShell.dataFilterDDL)

    gShell.dataSearchEdit := gShell.gui.Add("Edit", "x+10 w150", "")
    gShell.dataSearchEdit.OnEvent("Change", (*) => RefreshDataList())
    ApplyDarkTheme(gShell.dataSearchEdit)
    ApplyInputTheme(gShell.dataSearchEdit)
    gShell.gui.Add("Text", "x+5 c888888", "Search")

    gShell.dataLV := gShell.gui.Add("ListView", "x420 y+10 w540 h350 -Multi +Grid VScroll",
        ["Category", "Name", "Value", "Tags"])
    gShell.dataLV.OnEvent("DoubleClick", CopyDataValue)
    ApplyDarkListView(gShell.dataLV)

    gShell.btnCopyData := gShell.gui.Add("Button", "x420 y+10 w80", "Copy")
    gShell.btnCopyData.OnEvent("Click", (*) => CopySelectedData())
    ApplyDarkTheme(gShell.btnCopyData)

    gShell.btnEditData := gShell.gui.Add("Button", "x+5 w80", "Edit")
    gShell.btnEditData.OnEvent("Click", (*) => EditDataEntry())
    ApplyDarkTheme(gShell.btnEditData)

    gShell.btnDelData := gShell.gui.Add("Button", "x+5 w80", "Delete")
    gShell.btnDelData.OnEvent("Click", (*) => DeleteDataEntry())
    ApplyDarkTheme(gShell.btnDelData)

    LoadStoredData()
    RefreshDataList()
}

AddDataEntry(*) {
    global gShell, gStoredData
    cat := gShell.dataCatDDL.Text
    name := gShell.dataNameEdit.Value
    value := gShell.dataValueEdit.Value
    tags := gShell.dataTagsEdit.Value
    if name = "" || value = "" {
        MsgBox("Enter both name and value.", "Missing Data", "Icon!")
        return
    }
    entry := {
        id: A_Now . A_MSec,
        category: cat,
        name: name,
        value: value,
        tags: tags,
        created: FormatTime(A_Now, "yyyy-MM-dd HH:mm"),
        modified: FormatTime(A_Now, "yyyy-MM-dd HH:mm")
    }
    gStoredData.Push(entry)
    SaveStoredData()
    RefreshDataList()
    gShell.dataNameEdit.Value := ""
    gShell.dataValueEdit.Value := ""
    gShell.dataTagsEdit.Value := ""
}

RefreshDataList(*) {
    global gShell, gStoredData
    gShell.dataLV.Delete()
    filterCat := gShell.dataFilterDDL.Text
    searchTerm := gShell.dataSearchEdit.Value
    for entry in gStoredData {
        if filterCat != "All" && entry.category != filterCat
            continue
        if searchTerm != "" {
            if !InStr(entry.name, searchTerm) && !InStr(entry.value, searchTerm) && !InStr(entry.tags, searchTerm)
                continue
        }
        displayValue := StrLen(entry.value) > 30 ? SubStr(entry.value, 1, 30) "..." : entry.value
        gShell.dataLV.Add("", entry.category, entry.name, displayValue, entry.tags)
    }
    gShell.dataLV.ModifyCol(1, 90)
    gShell.dataLV.ModifyCol(2, 120)
    gShell.dataLV.ModifyCol(3, 200)
    gShell.dataLV.ModifyCol(4, 120)
}

CopyDataValue(lv, row) {
    global gStoredData
    if row > 0 && row <= gStoredData.Length {
        A_Clipboard := gStoredData[row].value
        ToolTip("Copied!")
        SetTimer(() => ToolTip(), -1500)
    }
}

CopySelectedData(*) {
    global gShell, gStoredData
    row := gShell.dataLV.GetNext()
    if row > 0 {
        A_Clipboard := gStoredData[row].value
        ToolTip("Copied!")
        SetTimer(() => ToolTip(), -1500)
    }
}

EditDataEntry(*) {
    global gShell, gStoredData
    row := gShell.dataLV.GetNext()
    if row <= 0 {
        MsgBox("Select an entry to edit.", "No Selection", "Icon!")
        return
    }
    entry := gStoredData[row]
    gShell.dataCatDDL.Text := entry.category
    gShell.dataNameEdit.Value := entry.name
    gShell.dataValueEdit.Value := entry.value
    gShell.dataTagsEdit.Value := entry.tags
    gStoredData.RemoveAt(row)
    RefreshDataList()
}

DeleteDataEntry(*) {
    global gShell, gStoredData
    row := gShell.dataLV.GetNext()
    if row <= 0 {
        MsgBox("Select an entry to delete.", "No Selection", "Icon!")
        return
    }
    if MsgBox("Delete this entry?", "Confirm", "YesNo Icon!") = "Yes" {
        gStoredData.RemoveAt(row)
        SaveStoredData()
        RefreshDataList()
    }
}

; ============================================================
; TAB 5: SETTINGS
; ============================================================

BuildSettingsTab() {
    global gShell
    gShell.gui.Add("Text", "xm+15 ym+50 c" DARK_TEXT, "AI Provider")
    gShell.gui.SetFont("s10", "Segoe UI")

    gShell.gui.Add("Text", "xm+15 y+15 c" DARK_TEXT, "Provider:")
    gShell.providerDDL := gShell.gui.Add("DropDownList", "x+20 w150 Choose1", ["OpenAI", "Claude"])
    ApplyDarkTheme(gShell.providerDDL)
    ApplyInputTheme(gShell.providerDDL)

    gShell.gui.Add("Text", "xm+15 y+25 c" DARK_TEXT, "--- OpenAI Settings ---")
    gShell.gui.Add("Text", "xm+15 y+12 c" DARK_TEXT, "OpenAI Key:")
    gShell.openaiKeyEdit := gShell.gui.Add("Edit", "x+20 w450 Password", "")
    ApplyDarkTheme(gShell.openaiKeyEdit)
    ApplyInputTheme(gShell.openaiKeyEdit)

    gShell.gui.Add("Text", "xm+15 y+10 c" DARK_TEXT, "OpenAI Model:")
    gShell.openaiModelEdit := gShell.gui.Add("Edit", "x+5 w200", "gpt-4o-mini")
    ApplyDarkTheme(gShell.openaiModelEdit)
    ApplyInputTheme(gShell.openaiModelEdit)
    gShell.gui.Add("Text", "x+10 c888888", "(gpt-4o-mini is cheapest)")

    gShell.gui.Add("Text", "xm+15 y+25 c" DARK_TEXT, "--- Claude Settings ---")
    gShell.gui.Add("Text", "xm+15 y+12 c" DARK_TEXT, "Claude Key:")
    gShell.claudeKeyEdit := gShell.gui.Add("Edit", "x+25 w450 Password", "")
    ApplyDarkTheme(gShell.claudeKeyEdit)
    ApplyInputTheme(gShell.claudeKeyEdit)

    gShell.gui.Add("Text", "xm+15 y+10 c" DARK_TEXT, "Claude Model:")
    gShell.claudeModelEdit := gShell.gui.Add("Edit", "x+10 w250", "claude-sonnet-4-20250514")
    ApplyDarkTheme(gShell.claudeModelEdit)
    ApplyInputTheme(gShell.claudeModelEdit)

    gShell.btnSaveSettings := gShell.gui.Add("Button", "xm+15 y+30 w120", "Save Settings")
    gShell.btnSaveSettings.OnEvent("Click", (*) => SaveSettings())
    ApplyDarkTheme(gShell.btnSaveSettings)

    gShell.btnTestAPI := gShell.gui.Add("Button", "x+10 w120", "Test API")
    gShell.btnTestAPI.OnEvent("Click", (*) => TestAPIConnection())
    ApplyDarkTheme(gShell.btnTestAPI)

    gShell.gui.Add("Text", "xm+15 y+40 c" DARK_TEXT, "Global Hotkeys")
    gShell.gui.Add("Text", "xm+15 y+15 c888888", "Ctrl+Alt+Z         PROMPT MENU (select text, pick action)")
    gShell.gui.Add("Text", "xm+15 y+8 c888888", "Ctrl+Alt+Space     Smart Fix (select all, fix everything)")
    gShell.gui.Add("Text", "xm+15 y+8 c888888", "Ctrl+Alt+G         Show/Hide AI-HUB window")
    gShell.gui.Add("Text", "xm+15 y+8 c888888", "Ctrl+Alt+A         Quick AI Chat (with selected text)")
    gShell.gui.Add("Text", "xm+15 y+8 c888888", "Alt+H              Toggle Dictation (Win+H)")
    gShell.gui.Add("Text", "xm+15 y+8 c888888", "Ctrl+Alt+C         Clipboard (HTML)")
    gShell.gui.Add("Text", "xm+15 y+8 c888888", "Ctrl+Alt+O         Prompts (HTML)")
    gShell.gui.Add("Text", "xm+15 y+8 c888888", "Ctrl+Alt+L         Links (HTML)")
    gShell.gui.Add("Text", "xm+15 y+8 c888888", "Ctrl+Alt+W         Toggle Always On Top")
    gShell.gui.Add("Text", "xm+15 y+8 c888888", "Ctrl+Alt+Y         Toggle Remember Position")
    gShell.gui.Add("Text", "xm+15 y+8 c888888", "Ctrl+Shift+Q       Save selection as Markdown (Downloads)")
    gShell.gui.Add("Text", "xm+15 y+8 c888888", "Ctrl+Shift+W       Save selection as Markdown (Save As)")
    gShell.gui.Add("Text", "xm+15 y+15 c888888", "Ctrl+Z             Undo after any AI action")

    gShell.gui.Add("Text", "xm+15 y+40 cFF6666", "Danger Zone")
    gShell.btnClearHotkeys := gShell.gui.Add("Button", "xm+15 y+15 w150", "Clear All Hotkeys")
    gShell.btnClearHotkeys.OnEvent("Click", (*) => ClearAllHotkeys())
    ApplyDarkTheme(gShell.btnClearHotkeys)

    gShell.btnClearData := gShell.gui.Add("Button", "x+10 w150", "Clear All Data")
    gShell.btnClearData.OnEvent("Click", (*) => ClearAllData())
    ApplyDarkTheme(gShell.btnClearData)

    gShell.btnClearPrompts := gShell.gui.Add("Button", "x+10 w150", "Clear All Prompts")
    gShell.btnClearPrompts.OnEvent("Click", (*) => ClearAllPrompts())
    ApplyDarkTheme(gShell.btnClearPrompts)
}

SaveSettings(*) {
    global gShell, CONFIG_FILE, gAlwaysOnTop, gRememberPos
    global gSaveMarkdownAutoEnabled, gSaveMarkdownAsEnabled
    global gSavedX, gSavedY
    content := "[Settings]`n"
    content .= "provider=" gShell.providerDDL.Text "`n"
    content .= "apiKey=" gShell.openaiKeyEdit.Value "`n"
    content .= "openaiKey=" gShell.openaiKeyEdit.Value "`n"
    content .= "claudeKey=" gShell.claudeKeyEdit.Value "`n"
    content .= "openaiModel=" gShell.openaiModelEdit.Value "`n"
    content .= "claudeModel=" gShell.claudeModelEdit.Value "`n"
    content .= "`n[Utilities]`n"
    content .= "alwaysOnTop=" (gAlwaysOnTop ? "1" : "0") "`n"
    content .= "rememberPos=" (gRememberPos ? "1" : "0") "`n"
    content .= "saveMdAuto=" (gSaveMarkdownAutoEnabled ? "1" : "0") "`n"
    content .= "saveMdAs=" (gSaveMarkdownAsEnabled ? "1" : "0") "`n"
    content .= "savedX=" gSavedX "`n"
    content .= "savedY=" gSavedY "`n"
    try FileDelete(CONFIG_FILE)
    FileAppend(content, CONFIG_FILE)
    ToolTip("Settings saved!")
    SetTimer(() => ToolTip(), -1500)
}

LoadSettings() {
    global gShell, CONFIG_FILE, gAlwaysOnTop, gRememberPos
    global gSaveMarkdownAutoEnabled, gSaveMarkdownAsEnabled
    global gSavedX, gSavedY
    if !FileExist(CONFIG_FILE)
        return
    try {
        provider := IniRead(CONFIG_FILE, "Settings", "provider", "OpenAI")
        gShell.providerDDL.Text := provider
        openaiKey := IniRead(CONFIG_FILE, "Settings", "openaiKey", "")
        if openaiKey = ""
            openaiKey := IniRead(CONFIG_FILE, "Settings", "apiKey", "")
        if openaiKey = ""
            openaiKey := EnvGet("OPENAI_API_KEY")
        if openaiKey = ""
            openaiKey := EnvGet("OPENAI_KEY")
        claudeKey := IniRead(CONFIG_FILE, "Settings", "claudeKey", "")
        if claudeKey = ""
            claudeKey := EnvGet("ANTHROPIC_API_KEY")
        if claudeKey = ""
            claudeKey := EnvGet("CLAUDE_API_KEY")
        gShell.openaiKeyEdit.Value := openaiKey
        gShell.claudeKeyEdit.Value := claudeKey
        gShell.openaiModelEdit.Value := IniRead(CONFIG_FILE, "Settings", "openaiModel", "gpt-4o-mini")
        gShell.claudeModelEdit.Value := IniRead(CONFIG_FILE, "Settings", "claudeModel", "claude-sonnet-4-20250514")
    }
    ; Restore utility toggles
    try {
        gAlwaysOnTop := IniRead(CONFIG_FILE, "Utilities", "alwaysOnTop", "0") = "1"
        gRememberPos := IniRead(CONFIG_FILE, "Utilities", "rememberPos", "0") = "1"
        gSaveMarkdownAutoEnabled := IniRead(CONFIG_FILE, "Utilities", "saveMdAuto", "1") = "1"
        gSaveMarkdownAsEnabled := IniRead(CONFIG_FILE, "Utilities", "saveMdAs", "1") = "1"
        gSavedX := IniRead(CONFIG_FILE, "Utilities", "savedX", "")
        gSavedY := IniRead(CONFIG_FILE, "Utilities", "savedY", "")
        ; Apply always-on-top if it was saved on
        if gAlwaysOnTop {
            WinSetAlwaysOnTop("On", "ahk_id " gShell.gui.Hwnd)
            try A_TrayMenu.Check("Always On Top")
        }
        ; Sync Utilities tab checkboxes if they exist
        try {
            gShell.chkAlwaysOnTop.Value := gAlwaysOnTop ? 1 : 0
            gShell.chkAlwaysOnTop.Text := gAlwaysOnTop ? "ON" : "OFF"
        }
        try {
            gShell.chkRememberPos.Value := gRememberPos ? 1 : 0
            gShell.chkRememberPos.Text := gRememberPos ? "ON" : "OFF"
        }
        try {
            gShell.chkSaveMdAuto.Value := gSaveMarkdownAutoEnabled ? 1 : 0
            gShell.chkSaveMdAuto.Text := gSaveMarkdownAutoEnabled ? "ON" : "OFF"
        }
        try {
            gShell.chkSaveMdAs.Value := gSaveMarkdownAsEnabled ? 1 : 0
            gShell.chkSaveMdAs.Text := gSaveMarkdownAsEnabled ? "ON" : "OFF"
        }
        ; If remember position was on, move window now
        if gRememberPos && gSavedX != "" && gSavedY != ""
            gShell.gui.Move(Integer(gSavedX), Integer(gSavedY))
    }
}

TestAPIConnection(*) {
    global gShell
    provider := gShell.providerDDL.Text
    if provider = "OpenAI" {
        if gShell.openaiKeyEdit.Value = "" {
            MsgBox("Enter OpenAI API key first.", "Missing Key", "Icon!")
            return
        }
    } else {
        if gShell.claudeKeyEdit.Value = "" {
            MsgBox("Enter Claude API key first.", "Missing Key", "Icon!")
            return
        }
    }
    ToolTip("Testing " provider " connection...")
    result := CallAI("Say 'Connection successful!' in exactly those words.", [])
    ToolTip()
    if InStr(result, "successful") || InStr(result, "Connection")
        MsgBox("API connection working!", "Success", "Iconi")
    else
        MsgBox("Response: " result, "API Test Result", "Icon!")
}

ClearAllHotkeys(*) {
    global gItems
    if MsgBox("Delete ALL shortcuts? This cannot be undone!", "Confirm", "YesNo Icon!") = "Yes" {
        Unregister_All()
        gItems := []
        Save_All()
        UI_Populate()
    }
}

ClearAllData(*) {
    global gStoredData
    if MsgBox("Delete ALL stored data? This cannot be undone!", "Confirm", "YesNo Icon!") = "Yes" {
        gStoredData := []
        SaveStoredData()
        RefreshDataList()
    }
}

ClearAllPrompts(*) {
    global gPrompts
    if MsgBox("Delete ALL prompts? This cannot be undone!", "Confirm", "YesNo Icon!") = "Yes" {
        gPrompts := []
        SavePrompts()
        RefreshPromptsLV()
        ClearPromptEditor()
    }
}

; ============================================================
; AI API CALLS
; ============================================================

CallAI(prompt, history, sysPrompt := "") {
    global gShell
    provider := "OpenAI"
    try provider := gShell.providerDDL.Text
    if provider = "OpenAI"
        return CallOpenAI(prompt, history, sysPrompt)
    else
        return CallClaude(prompt, history, sysPrompt)
}

CallOpenAI(prompt, history, sysPrompt := "") {
    global gShell
    apiKey := ""
    model := "gpt-4o-mini"
    try {
        apiKey := gShell.openaiKeyEdit.Value
        model := gShell.openaiModelEdit.Value
    }
    envKey := EnvGet("OPENAI_API_KEY")
    if envKey != ""
        apiKey := envKey
    if apiKey = ""
        apiKey := EnvGet("OPENAI_KEY")
    if apiKey = ""
        return "Please configure your OpenAI API key in Settings."

    messages := "["
    if sysPrompt != ""
        messages .= '{"role":"system","content":"' EscapeJSON(sysPrompt) '"},'
    for i, msg in history {
        messages .= '{"role":"' msg.role '","content":"' EscapeJSON(msg.content) '"},'
    }
    if prompt != ""
        messages .= '{"role":"user","content":"' EscapeJSON(prompt) '"}'
    else if history.Length > 0
        messages := SubStr(messages, 1, -1)
    messages .= "]"

    body := '{"model":"' model '","max_tokens":16000,"messages":' messages '}'

    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("POST", "https://api.openai.com/v1/chat/completions", true)
        whr.SetRequestHeader("Content-Type", "application/json")
        whr.SetRequestHeader("Authorization", "Bearer " apiKey)
        whr.Send(body)
        whr.WaitForResponse()
        responseText := whr.ResponseText
        if RegExMatch(responseText, '"content"\s*:\s*"((?:[^"\\]|\\.)*)"', &match)
            return UnescapeJSON(match[1])
        else if InStr(responseText, "error") {
            if RegExMatch(responseText, '"message"\s*:\s*"([^"]*)"', &errMatch)
                return "API Error: " errMatch[1]
            return "API Error - check your key and settings"
        }
        return "Response received but couldn't parse."
    } catch as e {
        return "Request failed: " e.Message
    }
}

CallClaude(prompt, history, sysPrompt := "") {
    global gShell
    apiKey := ""
    model := "claude-sonnet-4-20250514"
    try {
        apiKey := gShell.claudeKeyEdit.Value
        model := gShell.claudeModelEdit.Value
    }
    if apiKey = ""
        apiKey := EnvGet("ANTHROPIC_API_KEY")
    if apiKey = ""
        apiKey := EnvGet("CLAUDE_API_KEY")
    if apiKey = ""
        return "Please configure your Claude API key in Settings."

    messages := "["
    for i, msg in history {
        messages .= '{"role":"' msg.role '","content":"' EscapeJSON(msg.content) '"},'
    }
    if prompt != ""
        messages .= '{"role":"user","content":"' EscapeJSON(prompt) '"}'
    else if history.Length > 0
        messages := SubStr(messages, 1, -1)
    messages .= "]"

    sysField := ""
    if sysPrompt != ""
        sysField := ',"system":"' EscapeJSON(sysPrompt) '"'

    body := '{"model":"' model '","max_tokens":16000' sysField ',"messages":' messages '}'

    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("POST", "https://api.anthropic.com/v1/messages", true)
        whr.SetRequestHeader("Content-Type", "application/json")
        whr.SetRequestHeader("x-api-key", apiKey)
        whr.SetRequestHeader("anthropic-version", "2023-06-01")
        whr.Send(body)
        whr.WaitForResponse()
        responseText := whr.ResponseText
        if RegExMatch(responseText, '"text"\s*:\s*"((?:[^"\\]|\\.)*)"', &match)
            return UnescapeJSON(match[1])
        else if InStr(responseText, "error") {
            if RegExMatch(responseText, '"message"\s*:\s*"([^"]*)"', &errMatch)
                return "API Error: " errMatch[1]
            return "API Error - check your key and settings"
        }
        return "Response received but couldn't parse."
    } catch as e {
        return "Request failed: " e.Message
    }
}

; ============================================================
; FILE I/O
; ============================================================

Load_All() {
    global gItems, HOTKEY_FILE, HOTSTR_FILE
    gItems := []
    hkText := ""
    try hkText := FileRead(HOTKEY_FILE, "UTF-8")
    if hkText != "" {
        for _, line in StrSplit(hkText, "`n", "`r") {
            line := Trim(line)
            if line = ""
                continue
            parts := StrSplit(line, "|")
            if parts.Length >= 4 {
                gItems.Push({
                    Kind: "Hotkey",
                    Trigger: parts[1],
                    Desc: parts[2],
                    Action: parts[3],
                    Output: parts[4]
                })
            }
        }
    }
    hsText := ""
    try hsText := FileRead(HOTSTR_FILE, "UTF-8")
    if hsText != "" {
        for _, line in StrSplit(hsText, "`n", "`r") {
            line := Trim(line)
            if line = ""
                continue
            if RegExMatch(line, "U)^:(?<opts>.*?):(?<abbr>.*?)::(?<repl>.*)$", &m) {
                gItems.Push({
                    Kind: "Hotstring",
                    Trigger: m["abbr"],
                    Desc: "",
                    Output: m["repl"],
                    Opts: m["opts"]
                })
            }
        }
    }
    if gItems.Length = 0 {
        gItems.Push({Kind: "Hotkey", Trigger: "^!l", Desc: "Quick email", Action: "send", Output: "example@email.com"})
        gItems.Push({Kind: "Hotstring", Trigger: "MYEMAIL", Desc: "Email shortcut", Output: "example@email.com", Opts: "*C"})
        Save_All()
    }
}

Save_All() {
    global gItems, HOTKEY_FILE, HOTSTR_FILE
    hk := ""
    hs := ""
    for it in gItems {
        if it.Kind = "Hotkey" {
            act := it.HasProp("Action") ? it.Action : "send"
            hk .= it.Trigger "|" (it.Desc ? it.Desc : "") "|" act "|" it.Output "`n"
        } else {
            opts := it.HasProp("Opts") && it.Opts ? it.Opts : "*C"
            hs .= ":" opts ":" it.Trigger "::" it.Output "`n"
        }
    }
    try FileDelete(HOTKEY_FILE)
    try FileDelete(HOTSTR_FILE)
    FileAppend(hk, HOTKEY_FILE)
    FileAppend(hs, HOTSTR_FILE)
}

LoadStoredData() {
    global gStoredData, DATA_FILE
    gStoredData := []
    if !FileExist(DATA_FILE)
        return
    try {
        jsonStr := FileRead(DATA_FILE, "UTF-8")
        if jsonStr = "" || jsonStr = "[]"
            return
        jsonStr := Trim(jsonStr)
        if SubStr(jsonStr, 1, 1) = "[" {
            pattern := '\{"id":"([^"]*)".*?"category":"([^"]*)".*?"name":"([^"]*)".*?"value":"([^"]*)".*?"tags":"([^"]*)".*?"created":"([^"]*)".*?"modified":"([^"]*)"\}'
            pos := 1
            while RegExMatch(jsonStr, pattern, &m, pos) {
                gStoredData.Push({
                    id: m[1],
                    category: UnescapeJSON(m[2]),
                    name: UnescapeJSON(m[3]),
                    value: UnescapeJSON(m[4]),
                    tags: UnescapeJSON(m[5]),
                    created: m[6],
                    modified: m[7]
                })
                pos := m.Pos + m.Len
            }
        }
    }
}

SaveStoredData() {
    global gStoredData, DATA_FILE
    jsonStr := "["
    for i, entry in gStoredData {
        jsonStr .= "`n  {"
        jsonStr .= '"id":"' entry.id '", '
        jsonStr .= '"category":"' EscapeJSON(entry.category) '", '
        jsonStr .= '"name":"' EscapeJSON(entry.name) '", '
        jsonStr .= '"value":"' EscapeJSON(entry.value) '", '
        jsonStr .= '"tags":"' EscapeJSON(entry.tags) '", '
        jsonStr .= '"created":"' entry.created '", '
        jsonStr .= '"modified":"' entry.modified '"'
        jsonStr .= "}" (i < gStoredData.Length ? "," : "")
    }
    jsonStr .= "`n]"
    try FileDelete(DATA_FILE)
    FileAppend(jsonStr, DATA_FILE, "UTF-8")
}

; ============================================================
; REGISTRATION
; ============================================================

Register_All() {
    global gItems, gHKMap, gHSMap, gShell
    enableHK := true
    try enableHK := gShell.enableHK.Value
    if enableHK {
        for it in gItems {
            if it.Kind != "Hotkey"
                continue
            k := it.Trigger
            try {
                Hotkey(k, Hotkey_Handler, "On")
                gHKMap[k] := it
            }
        }
    }
    enableHS := true
    try enableHS := gShell.enableHS.Value
    if enableHS {
        for it in gItems {
            if it.Kind != "Hotstring"
                continue
            opts := it.HasProp("Opts") && it.Opts ? it.Opts : "*C"
            sig := ":" opts ":" it.Trigger
            try {
                ; Use clipboard-paste handler instead of SendInput
                ; Fixes first-letter surviving in browsers
                output := it.Output
                trigLen := StrLen(it.Trigger)
                Hotstring(sig, ((txt, bsCount) => (*) => HotstringPaste(txt, bsCount))(output, trigLen), true)
                gHSMap[sig] := output
            }
        }
    }
}

Unregister_All() {
    global gHKMap, gHSMap
    for k, _ in gHKMap
        try Hotkey(k, Hotkey_Handler, "Off")
    gHKMap.Clear()
    for s, _ in gHSMap
        try Hotstring(s, , false)
    gHSMap.Clear()
}

ReRegister() {
    Unregister_All()
    Register_All()
}

Hotkey_Handler(*) {
    global gHKMap
    hk := A_ThisHotkey
    if !gHKMap.Has(hk)
        return
    it := gHKMap[hk]
    act := it.HasProp("Action") ? it.Action : "send"
    if act = "run"
        Run(it.Output)
    else
        SafePaste(it.Output)
}

; ============================================================
; HELPERS
; ============================================================

SafePaste(s) {
    old := ClipboardAll()
    A_Clipboard := s
    ClipWait(0.5)
    Send("^v")
    Sleep(60)
    A_Clipboard := old
}

; Backspace trigger text then clipboard-paste replacement
; Solves browser first-letter issue with hotstrings
HotstringPaste(text, backspaceCount) {
    Send("{Backspace " backspaceCount "}")
    Sleep(30)
    SafePaste(text)
}

EscapeJSON(str) {
    str := StrReplace(str, "\", "\\")
    str := StrReplace(str, '"', '\"')
    str := StrReplace(str, "`n", "\n")
    str := StrReplace(str, "`r", "\r")
    str := StrReplace(str, "`t", "\t")
    return str
}

UnescapeJSON(str) {
    str := StrReplace(str, "\n", "`n")
    str := StrReplace(str, "\r", "`r")
    str := StrReplace(str, "\t", "`t")
    str := StrReplace(str, '\"', '"')
    str := StrReplace(str, "\\", "\")
    return str
}

FixTextEncodingDamage(str) {
    str := StrReplace(str, "â€™", "'")
    str := StrReplace(str, "â€˜", "'")
    str := StrReplace(str, "â€œ", '"')
    str := StrReplace(str, "â€", '"')
    str := StrReplace(str, "â€“", "-")
    str := StrReplace(str, "â€”", "-")
    str := StrReplace(str, "â€¦", "...")
    str := StrReplace(str, "Â ", " ")
    str := StrReplace(str, "Â", "")
    str := StrReplace(str, "�", "")
    return str
}

Dq(s) => Chr(34) . StrReplace(s, '"', '""') . Chr(34)

OnGuiResize(thisGui, minMax, width, height) {
    global gShell
    if minMax = -1
        return
    try gShell.tabs.Move(,, width - 20, height - 60)
}

; ============================================================
; GLOBAL HOTKEYS
; ============================================================

^!g:: {
    ToggleGui()
}

!h:: {
    Send("#h")
}

^!w:: {
    ToggleAlwaysOnTop()
}

^!y:: {
    ToggleRememberPos()
}

^+q:: {
    global gSaveMarkdownAutoEnabled
    if gSaveMarkdownAutoEnabled
        SaveMarkdownAuto()
}

^+w:: {
    global gSaveMarkdownAsEnabled
    if gSaveMarkdownAsEnabled
        SaveMarkdownAs()
}

^!a:: {
    global gShell
    oldClip := A_Clipboard
    A_Clipboard := ""
    Send("^c")
    if !ClipWait(1) {
        A_Clipboard := oldClip
        ShowGui()
        SetActiveTabByName("AI Chat")
        return
    }
    selectedText := A_Clipboard
    A_Clipboard := oldClip
    ShowGui()
    SetActiveTabByName("AI Chat")
    gShell.chatInput.Value := selectedText
    gShell.chatInput.Focus()
}

; Ctrl+Alt+Z now routes to the dedicated Hotkey Menu module.
^!z:: {
    if IsSet(HKMenu_ShowMenu)
        HKMenu_ShowMenu()
}

ShowQuickActionPopup() {
    global gPrompts, gSelectedText, DARK_BG, DARK_TEXT, DARK_CTRL

    ; Destroy previous popup if exists
    static popGui := ""
    if popGui != ""
        try popGui.Destroy()

    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)

    popGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", "Quick Actions")
    popGui.BackColor := "111115"
    popGui.MarginX := 8
    popGui.MarginY := 6
    popGui.SetFont("s9 Bold cDDDDDD", "Segoe UI")

    ; Dark title bar
    if (VerCompare(A_OSVersion, "10.0.17763") >= 0) {
        attr := (VerCompare(A_OSVersion, "10.0.18985") >= 0) ? 20 : 19
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", popGui.hWnd, "Int", attr, "Int*", true, "Int", 4)
    }

    ; Header
    popGui.SetFont("s8 c888888", "Segoe UI")
    popGui.Add("Text", "xm w200", "⚡ QUICK ACTIONS  (Esc to close)")
    popGui.Add("Text", "xm w200 h1 Background2a2a2a")
    popGui.SetFont("s9 Bold cDDDDDD", "Segoe UI")

    ; Built-in defaults (if no custom prompts)
    builtins := [
        {name: "Fix Grammar",    prompt: "Fix all grammar, spelling, capitalization, and punctuation. Return ONLY the corrected text:"},
        {name: "Summarize",      prompt: "Summarize this concisely. Return ONLY the summary:"},
        {name: "Professional",   prompt: "Rewrite in a professional tone. Return ONLY the text:"},
        {name: "Simplify",       prompt: "Simplify and explain in plain English. Return ONLY the text:"},
        {name: "Expand",         prompt: "Expand with more detail. Return ONLY the expanded text:"},
        {name: "Bullet Points",  prompt: "Convert to clear bullet points. Return ONLY the bullets:"},
        {name: "Email Format",   prompt: "Reformat as a professional email. Return ONLY the email:"},
        {name: "Code It",        prompt: "Convert this description into working code. Return ONLY the code:"},
        {name: "ELI5",           prompt: "Explain this like I'm 5 years old. Return ONLY the explanation:"},
        {name: "To Clipboard",   prompt: ""}
    ]

    ; Custom prompts first
    if gPrompts.Length > 0 {
        for i, p in gPrompts {
            btn := popGui.Add("Button", "xm w200 h28", p.name)
            btn.OnEvent("Click", PopupRunPrompt.Bind(popGui, p.template, p.HasProp("replace") ? p.replace : true, p.HasProp("popup") ? p.popup : false))
            try DllCall("uxtheme\SetWindowTheme", "Ptr", btn.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        }
        ; Separator
        popGui.Add("Text", "xm w200 h1 Background2a2a2a y+4")
        popGui.SetFont("s8 c888888", "Segoe UI")
        popGui.Add("Text", "xm", "DEFAULTS")
        popGui.SetFont("s9 Bold cDDDDDD", "Segoe UI")
    }

    ; Built-in buttons
    for i, b in builtins {
        if b.name = "To Clipboard" {
            popGui.Add("Text", "xm w200 h1 Background2a2a2a y+4")
            btn := popGui.Add("Button", "xm w200 h28", "📋 Copy Selection")
            btn.OnEvent("Click", (*) => (A_Clipboard := gSelectedText, ToolTip("Copied!"), SetTimer(() => ToolTip(), -1000), popGui.Destroy()))
        } else {
            btn := popGui.Add("Button", "xm w200 h28", b.name)
            btn.OnEvent("Click", PopupRunPrompt.Bind(popGui, b.prompt, true, false))
        }
        try DllCall("uxtheme\SetWindowTheme", "Ptr", btn.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
    }

    popGui.OnEvent("Escape", (*) => popGui.Destroy())

    ; Position near mouse, but keep on screen
    monW := SysGet(78)  ; SM_CXVIRTUALSCREEN
    monH := SysGet(79)  ; SM_CYVIRTUALSCREEN
    px := mx + 15
    py := my - 40
    if (px + 230 > monW)
        px := mx - 230
    if (py + 500 > monH)
        py := monH - 500
    if py < 0
        py := 0

    popGui.Show("x" px " y" py " AutoSize NoActivate")
}

PopupRunPrompt(popGui, template, replaceText, showPopup, *) {
    global gSelectedText
    try popGui.Destroy()
    if template = "" {
        A_Clipboard := gSelectedText
        ToolTip("Copied!")
        SetTimer(() => ToolTip(), -1500)
        return
    }
    ProcessWithPrompt(template, replaceText, showPopup)
}

ProcessWithPrompt(promptTemplate, replaceText := true, showPopup := false) {
    global gSelectedText
    if !gSelectedText || gSelectedText = "" {
        ToolTip("No text selected!")
        SetTimer(() => ToolTip(), -1500)
        return
    }
    ToolTip("Processing...")
    if InStr(promptTemplate, "{text}")
        fullPrompt := StrReplace(promptTemplate, "{text}", gSelectedText)
    else
        fullPrompt := promptTemplate "`n`n" gSelectedText
    response := CallAI(fullPrompt, [])
    ToolTip()
    if InStr(response, "API Error") || InStr(response, "configure") || InStr(response, "failed") {
        MsgBox(response, "AI Error", "Icon!")
        return
    }
    response := Trim(response)
    if SubStr(response, 1, 1) = '"' && SubStr(response, -1) = '"'
        response := SubStr(response, 2, -1)
    if showPopup {
        MsgBox(response, "AI Response", "Iconi")
    } else if replaceText {
        oldClip := A_Clipboard
        A_Clipboard := response
        ClipWait(1)
        Send("^v")
        Sleep(100)
        A_Clipboard := oldClip
        ToolTip("Done! (Ctrl+Z to undo)")
        SetTimer(() => ToolTip(), -2000)
    } else {
        A_Clipboard := response
        ToolTip("Copied to clipboard!")
        SetTimer(() => ToolTip(), -2000)
    }
}

^!Space:: {
    global gShell
    oldClip := A_Clipboard
    A_Clipboard := ""
    Send("^a")
    Sleep(100)
    Send("^c")
    if !ClipWait(2) {
        A_Clipboard := oldClip
        ToolTip("No text found!")
        SetTimer(() => ToolTip(), -1500)
        return
    }
    textToFix := FixTextEncodingDamage(A_Clipboard)
    if StrLen(textToFix) < 2 {
        A_Clipboard := oldClip
        return
    }
    ToolTip("Fixing text...")
    fixPrompt := "Fix and improve this text. Correct all grammar, spelling, capitalization, and punctuation errors. Make the text coherent and well-organized while preserving the original meaning and intent."
    fixPrompt .= "`n`nCRITICAL RULES:"
    fixPrompt .= "`n- Repair text-encoding damage such as broken apostrophes, broken quotes, broken dashes, broken ellipses, stray Â characters, and replacement characters."
    fixPrompt .= "`n- Use plain ASCII punctuation for ordinary apostrophes, quotes, dashes, and ellipses so the text pastes cleanly everywhere."
    fixPrompt .= "`n- Remove speech-dictation clutter such as filler words, false starts, duplicated phrases, and accidental repeated connectors when doing so preserves the speaker's intent."
    fixPrompt .= "`n- Return ONLY the corrected text with no explanations, no quotes, no markdown formatting — just the clean corrected text."
    fixPrompt .= "`n- DO NOT modify, remove, or alter any URLs (http://, https://), file paths (C:\, D:\, O:\, \\, /mnt/), or links of any kind. Leave them EXACTLY as they appear."
    fixPrompt .= "`n- DO NOT modify email addresses, IP addresses, or any technical identifiers."
    fixPrompt .= "`n- Only correct the natural language prose around these elements."
    fixPrompt .= "`n`n" textToFix
    response := CallAI(fixPrompt, [])
    ToolTip()
    if InStr(response, "API Error") || InStr(response, "configure") || InStr(response, "failed") {
        MsgBox(response, "Smart Fix Error", "Icon!")
        A_Clipboard := oldClip
        Send("{End}")
        return
    }
    response := FixTextEncodingDamage(Trim(response))
    if SubStr(response, 1, 1) = '"' && SubStr(response, -1) = '"'
        response := SubStr(response, 2, -1)
    ; Re-select all before pasting to guarantee replacement
    Send("^a")
    Sleep(100)
    A_Clipboard := response
    ClipWait(1)
    Send("^v")
    Sleep(150)
    A_Clipboard := oldClip
    ToolTip("Fixed! (Ctrl+Z to undo)")
    SetTimer(() => ToolTip(), -2000)
}


; ============================================================
; HTML PANEL HOTKEYS — Ctrl+Alt+C/P/K/M

; Ctrl+Alt+T = Toggle always-on-top for ACTIVE window (works on Chrome, Edge, anything)
^!t:: {
    hwnd := WinGetID("A")
    exStyle := WinGetExStyle("ahk_id " hwnd)
    if (exStyle & 0x8) {  ; WS_EX_TOPMOST
        WinSetAlwaysOnTop(0, "ahk_id " hwnd)
        ToolTip("Unpinned")
    } else {
        WinSetAlwaysOnTop(1, "ahk_id " hwnd)
        ToolTip("📌 Pinned on top")
    }
    SetTimer(() => ToolTip(), -1500)
}

; XButton2 = drag-anywhere window move/resize (WinCardinalMover)
XButton2:: WinCardinalMover("XButton2", "Ctrl")
; ============================================================

LaunchHtmlPanel(url, title) {
    ; Map short keys to actual Chrome window title fragments
    static titleMap := Map(
        "POF-Clipboard", "Clipboard",
        "POF-Mission",   "MISSION CONTROL",
        "POF-Prompts",   "Prompt",
        "POF-Links",     "Links",
        "POF-Calendar",  "Calendar"
    )
    searchTitle := titleMap.Has(title) ? titleMap[title] : title
    if WinExist(searchTitle " ahk_exe chrome.exe") {
        hwnd := WinGetID(searchTitle " ahk_exe chrome.exe")
        HideFromTaskbar(hwnd)
        WinRestore("ahk_id " hwnd)
        WinActivate("ahk_id " hwnd)
        return
    }
    if WinExist(searchTitle " ahk_exe msedge.exe") {
        hwnd := WinGetID(searchTitle " ahk_exe msedge.exe")
        HideFromTaskbar(hwnd)
        WinRestore("ahk_id " hwnd)
        WinActivate("ahk_id " hwnd)
        return
    }

    ; Launch in Chrome app mode
    chrome := ""
    for , p in ["C:\Program Files\Google\Chrome\Application\chrome.exe",
              "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"] {
        if FileExist(p) {
            chrome := p
            break
        }
    }
    if chrome = "" {
        chrome := "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
        if !FileExist(chrome)
            chrome := "msedge.exe"
    }
    Run(chr(34) . chrome . chr(34) . " --app=" . chr(34) . url . chr(34) . " --window-size=420,750 --disable-extensions --disable-background-networking --disable-sync")
    ; After launching, poll for window and hide from taskbar (repeating timer, 500ms interval, 15s timeout)
    SetTimer(HideNewPanel.Bind(searchTitle, A_TickCount), 500)
}

HideNewPanel(searchTitle, startTick) {
    ; Give up after 15 seconds
    if (A_TickCount - startTick > 15000) {
        SetTimer(, 0)
        return
    }
    ; Try both Chrome and Edge
    for , exe in ["chrome.exe", "msedge.exe"] {
        winTitle := searchTitle " ahk_exe " exe
        if WinExist(winTitle) {
            hwnd := WinGetID(winTitle)
            HideFromTaskbar(hwnd)
            SetTimer(, 0)  ; stop repeating
            return
        }
    }
}

FileUrl(path) {
    urlPath := StrReplace(path, "\", "/")
    urlPath := StrReplace(urlPath, "%", "%25")
    urlPath := StrReplace(urlPath, " ", "%20")
    urlPath := StrReplace(urlPath, "#", "%23")
    return "file:///" urlPath
}

; Ctrl+Alt+C = Clipboard (HTML)
^!c:: {
    LaunchHtmlPanel("http://127.0.0.1:3456/clipboard", "POF-Clipboard")
}

; Ctrl+Alt+O = Prompts (HTML)
^!o:: {
    LaunchHtmlPanel("http://127.0.0.1:3456/prompts", "POF-Prompts")
}

; Ctrl+Alt+K = Links (web research)
^!k:: {
    LaunchHtmlPanel("http://127.0.0.1:3456/links", "POF-Links")
}

; Ctrl+Alt+D = DeepCrawl
^!d:: {
    LaunchHtmlPanel("https://7c0baad5.deepcrawl-gui.pages.dev/", "POF-DeepCrawl")
}

; Ctrl+Alt+M = Calendar / Tasks
^!m:: {
    LaunchHtmlPanel("http://127.0.0.1:3456/calendar", "POF-Calendar")
}
