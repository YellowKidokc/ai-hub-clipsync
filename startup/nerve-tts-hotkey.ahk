; Nerve TTS hotkeys
; Ctrl+Alt+P: pause/resume
; Ctrl+Alt+X: replace with clipboard and play from beginning
; Ctrl+Alt+Shift+X: stop

#Requires AutoHotkey v2.0
#SingleInstance Force
SetTitleMatchMode 2

NERVE_TTS_TITLE := "Nerve TTS Engine"
NERVE_TTS_URL := "https://cloudflare-workers-autoconfig-nerve-tts-pwa.davidokc28.workers.dev/"
NERVE_TTS_API := "http://127.0.0.1:3456/api/tts-command"

NerveTTS_EnsureOpen() {
    global NERVE_TTS_TITLE, NERVE_TTS_URL

    if WinExist(NERVE_TTS_TITLE) {
        WinActivate(NERVE_TTS_TITLE)
        return true
    }

    shortcut := A_Startup "\Nerve TTS Engine.lnk"
    if FileExist(shortcut)
        Run('"' shortcut '"')
    else
        Run('msedge.exe --app="' NERVE_TTS_URL '"')

    if WinWait(NERVE_TTS_TITLE, , 8) {
        WinActivate(NERVE_TTS_TITLE)
        Sleep(600)
        return true
    }

    ToolTip("Nerve TTS: app did not open")
    SetTimer(() => ToolTip(), -1800)
    return false
}

NerveTTS_Post(action, text := "") {
    global NERVE_TTS_API

    payload := '{"action":"' action '","command":"' action '","text":' NerveTTS_Json(text) '}'
    http := ComObject("WinHttp.WinHttpRequest.5.1")

    try {
        http.Open("POST", NERVE_TTS_API, false)
        http.SetRequestHeader("Content-Type", "application/json")
        http.Send(payload)
        return http.Status >= 200 && http.Status < 300
    } catch Error {
        ToolTip("Nerve TTS: local bridge is not running")
        SetTimer(() => ToolTip(), -1800)
        return false
    }
}

NerveTTS_SendToWindow(text) {
    global NERVE_TTS_TITLE
    saved := ClipboardAll()
    A_Clipboard := text
    if !ClipWait(1) {
        A_Clipboard := saved
        return false
    }

    if WinExist(NERVE_TTS_TITLE)
        WinActivate(NERVE_TTS_TITLE)
    Sleep(120)
    MouseGetPos(&oldX, &oldY)
    try {
        WinGetPos(&appX, &appY, &appW, &appH, NERVE_TTS_TITLE)
        Click(appX + 52, appY + 142)
        MouseMove(oldX, oldY, 0)
    }
    Sleep(120)
    Send("^a")
    Sleep(80)
    Send("^v")
    Sleep(120)
    Send("^{Enter}")
    Sleep(120)
    A_Clipboard := saved
    return true
}

NerveTTS_ResetPastePlay() {
    text := A_Clipboard
    if Trim(text) = "" {
        ToolTip("Nerve TTS: clipboard is empty")
        SetTimer(() => ToolTip(), -1600)
        return false
    }

    if !NerveTTS_EnsureOpen()
        return false

    NerveTTS_Post("stop")
    Sleep(180)
    ok := NerveTTS_SendToWindow(text)
    if ok {
        NerveTTS_Post("replace-play", text)
        ToolTip("Nerve TTS: replaced text and started")
        SetTimer(() => ToolTip(), -1400)
    }
    return ok
}

NerveTTS_Json(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, '"', '\"')
    s := StrReplace(s, "`r", "\r")
    s := StrReplace(s, "`n", "\n")
    return '"' s '"'
}

^!p:: {
    if NerveTTS_EnsureOpen() {
        NerveTTS_Post("toggle")
        Send("^{Space}")
    }
}

^!x:: {
    NerveTTS_ResetPastePlay()
}

^!+x:: {
    if NerveTTS_EnsureOpen() {
        NerveTTS_Post("stop")
        Send("{Esc}")
    }
}
