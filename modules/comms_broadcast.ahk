#Requires AutoHotkey v2.0+
; ============================================================
; COMMS BROADCAST — Push messages to all AI agents
; ============================================================
; Ctrl+Shift+B  = INTERRUPT broadcast (posts to comms + pastes into all Claude Code windows)
; Ctrl+Shift+D  = DING (posts to comms only — agents pick it up next check)
; ============================================================

global COMMS_URL := "https://comms.faiththruphysics.com/broadcast"
global COMMS_TOKEN := EnvGet("THEOPHYSICS_COMMS_TOKEN")

; ---------- INTERRUPT: Broadcast to all agents NOW ----------
^+b:: {
    msg := ""
    ib := InputBox("Type your message to ALL agents (INTERRUPT mode):", "Broadcast — INTERRUPT", "w500 h140")
    if (ib.Result = "Cancel" || ib.Value = "")
        return
    msg := ib.Value

    ; Post to comms API (logged permanently)
    PostToComms(msg, "interrupt")

    ; Paste into every Claude Code window
    PasteToAllClaudeWindows("[DAVID — INTERRUPT]: " msg)

    TrayTip("Broadcast sent to all agents", "Comms Interrupt", 1)
}

; ---------- DING: Post to comms only (non-interrupting) ----------
^+d:: {
    msg := ""
    ib := InputBox("Type your message to ALL agents (DING mode — they'll see it next check):", "Broadcast — DING", "w500 h140")
    if (ib.Result = "Cancel" || ib.Value = "")
        return
    msg := ib.Value

    ; Post to comms API only
    PostToComms(msg, "ding")

    TrayTip("Ding posted to comms", "Comms Ding", 1)
}

; ---------- POST TO COMMS API ----------
PostToComms(message, priority := "normal") {
    global COMMS_URL, COMMS_TOKEN
    ; Escape quotes in message for JSON
    escaped := StrReplace(message, '\', '\\')
    escaped := StrReplace(escaped, '"', '\"')

    category := (priority = "interrupt") ? "interrupt" : "ding"
    pri := (priority = "interrupt") ? "high" : "normal"

    payload := '{"sender":"david","content":"[david] ' escaped '","priority":"' pri '","category":"' category '"}'

    cmd := 'curl -s -X POST'
        . ' -H "Authorization: Bearer ' COMMS_TOKEN '"'
        . ' -H "Content-Type: application/json"'
        . ' -d "' StrReplace(payload, '"', '\"') '"'
        . ' ' COMMS_URL

    Run(A_ComSpec ' /c ' cmd, , "Hide")
}

; ---------- PASTE INTO ALL CLAUDE CODE WINDOWS ----------
PasteToAllClaudeWindows(message) {
    ; Save current clipboard
    savedClip := A_Clipboard

    ; Find all windows with "Claude Code" in title
    wins := WinGetList("Claude Code")

    if (wins.Length = 0) {
        ; Also try windows with "claude" in title (terminal variants)
        wins := WinGetList("claude")
    }

    if (wins.Length = 0) {
        TrayTip("No Claude Code windows found", "Comms", 2)
        A_Clipboard := savedClip
        return
    }

    ; Put message on clipboard
    A_Clipboard := message

    for hwnd in wins {
        try {
            WinActivate(hwnd)
            WinWaitActive(hwnd, , 1)
            Sleep(100)
            ; Paste the message
            Send("^v")
            Sleep(50)
            ; Send Enter to submit
            Send("{Enter}")
            Sleep(200)
        }
    }

    ; Restore clipboard and return to original window
    Sleep(200)
    A_Clipboard := savedClip
}
