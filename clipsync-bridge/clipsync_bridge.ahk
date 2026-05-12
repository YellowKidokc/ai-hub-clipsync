#Requires AutoHotkey v2.0+
#SingleInstance Force

global SERVICES_INI := FileExist(A_ScriptDir "\..\config\services.ini")
    ? A_ScriptDir "\..\config\services.ini"
    : A_ScriptDir "\config\services.ini"
global LAST_CLIP := ""
OnClipboardChange(ClipChanged)

ClipChanged(*) {
    global LAST_CLIP
    txt := A_Clipboard
    if !IsSet(txt) || txt = "" || txt = LAST_CLIP
        return
    LAST_CLIP := txt
    PostClip(txt)
}

PostClip(content) {
    endpointKey := IniRead(SERVICES_INI, "CLIPBOARD", "active", "local")
    baseUrl := IniRead(SERVICES_INI, "CLIPBOARD", endpointKey, "http://localhost:3456")
    title := ClipTitle(content)
    payload := Format('{{"content":{1},"title":{2},"category":"clipboard","tags":["history"],"ts":"{3}"}}', JsonStr(content), JsonStr(title), FormatTime(A_NowUTC, "yyyy-MM-ddTHH:mm:ssZ"))
    http := ComObject("WinHttp.WinHttpRequest.5.1")
    try {
        http.Open("POST", baseUrl "/api/clips", false)
        http.SetRequestHeader("Content-Type", "application/json")
        http.Send(payload)
    }
}
ClipTitle(s) {
    for line in StrSplit(s, "`n", "`r") {
        line := Trim(line)
        if line != ""
            return SubStr(line, 1, 80)
    }
    return "Clipboard"
}
JsonStr(s) => '"' StrReplace(StrReplace(StrReplace(StrReplace(StrReplace(s, "\", "\\"), '"', '\"'), "`r", "\r"), "`n", "\n"), "`t", "\t") '"'

^!s:: {
    txt := A_Clipboard
    if txt != ""
        PostClip(txt)
}
