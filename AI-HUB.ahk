#Requires AutoHotkey v2.0+
#SingleInstance Force
#Warn

; ============================================================
; AI-HUB v2 — Entry Point
; ============================================================
; Three processes, three tray icons:
;   1. AI-HUB (this)     — main GUI with tabs [shell32 icon]
;   2. ClipSync Bridge    — clipboard + hotkeys [notepad icon]
;   3. BetterTTS          — TTS with normalizer [GHOSTY icon]
;
; On startup also launches:
;   - sync_server.py (serves HTML panels)
;   - Prompt Picker HTML
;   - Research Links HTML
; ============================================================

#include .\hub_core.ahk
#include .\modules\manifest.ahk

; Boot the application (defined in hub_core.ahk)
Hub_Boot()

; Hardcode always-on-top + remember-pos ON (INI already saves these but apply them directly)
SetTimer(TTS_ForceWindowBehavior, -1500)
TTS_ForceWindowBehavior() {
    global gShell, gAlwaysOnTop, gRememberPos
    gAlwaysOnTop := true
    gRememberPos := true
    try WinSetAlwaysOnTop(1, "ahk_id " gShell.gui.Hwnd)
    try {
        gShell.chkAlwaysOnTop.Value := 1
        gShell.chkAlwaysOnTop.Text  := "ON"
        gShell.chkRememberPos.Value := 1
        gShell.chkRememberPos.Text  := "ON"
    }
}

; --- SUBPROCESS 1: ClipSync Bridge server (Python, direct launch, no .bat) ---
; Launch pythonw directly to avoid CMD flash from .bat wrapper
try {
    pyW := "C:\Users\lowes\AppData\Local\Programs\Python\Python313\pythonw.exe"
    pyC := "C:\Users\lowes\AppData\Local\Programs\Python\Python313\python.exe"
    pyW312 := "C:\Users\lowes\AppData\Local\Programs\Python\Python312\pythonw.exe"
    pyC312 := "C:\Users\lowes\AppData\Local\Programs\Python\Python312\python.exe"
    bridgeScript := A_ScriptDir "\clipsync-bridge\sync_server.py"
    if !FileExist(bridgeScript)
        bridgeScript := A_ScriptDir "\sync_server.py"

    if FileExist(bridgeScript) {
        if FileExist(pyW)
            Run('"' pyW '" "' bridgeScript '"', , "Hide")
        else if FileExist(pyC)
            Run('"' pyC '" "' bridgeScript '"', , "Hide")
        else if FileExist(pyW312)
            Run('"' pyW312 '" "' bridgeScript '"', , "Hide")
        else if FileExist(pyC312)
            Run('"' pyC312 '" "' bridgeScript '"', , "Hide")
        else if FileExist("C:\Windows\py.exe")
            Run('py.exe -3 "' bridgeScript '"', , "Hide")
        else
            Run('python.exe "' bridgeScript '"', , "Hide")
    }
}

; --- SUBPROCESS 2: ClipSync hotkeys/UI bridge (AHK) ---
; Runs as its own tiny listener so clipboard history captures every copy.
bridgeAhk := A_ScriptDir "\clipsync-bridge\clipsync_bridge.ahk"
try Run('"' A_AhkPath '" "' bridgeAhk '"')

; --- SUBPROCESS 3: BetterTTS (AHK, own tray icon) ---
; DISABLED - TTS now embedded in hub TTS tab
; try Run(A_ScriptDir "\BetterTTS\BetterTTS.ahk")

; --- SUBPROCESS 4: Clipboard Manager ---
; DISABLED — Clipboard.ahk does not exist in clipboard\ folder
; try Run(A_ScriptDir "\clipboard\Clipboard.ahk")

; --- HTML PANELS: Launch after server has time to start ---
SetTimer(LaunchStartupPanels, -3000)

LaunchStartupPanels() {
    try LaunchHtmlPanel(LocalAppUrl("/clipboard"), "POF-Clipboard")
    Sleep(500)
    try LaunchHtmlPanel(LocalAppUrl("/mission"), "POF-Mission")
    Sleep(500)
    try LaunchHtmlPanel(LocalAppUrl("/prompts"), "POF-Prompts")
    Sleep(500)
    try LaunchHtmlPanel(LocalAppUrl("/links"), "POF-Links")
    Sleep(500)
    try LaunchHtmlPanel(LocalAppUrl("/comms"), "POF-Comms")
}

LocalAppUrl(path) {
    return "http://127.0.0.1:3456" path
}

; Clipboard ingestion now lives in Python (sync_server.py).
; Keep AHK focused on GUI, hotkeys, and OS-level actions.
