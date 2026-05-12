#Requires AutoHotkey v2.0+
#SingleInstance Off

pinNum := A_Args.Length ? A_Args[1] : "1"
global gPinGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
global gPinText
global gTargetHwnd := 0
global gLocked := false
global gDragging := false

gPinGui.BackColor := "202020"
gPinGui.SetFont("s9 cFFB000 Bold", "Segoe UI")
gPinText := gPinGui.AddText("Center w92 h34", "PIN " pinNum)
gPinGui.Show("x120 y120 w92 h34")

OnMessage(0x201, PinMouseDown) ; WM_LBUTTONDOWN
OnMessage(0x202, PinMouseUp)   ; WM_LBUTTONUP
OnMessage(0x204, PinRightClick) ; WM_RBUTTONDOWN
gPinGui.OnEvent("Close", (*) => ExitApp())

PinMouseDown(wParam, lParam, msg, hwnd) {
    global gPinGui, gDragging
    if !PinOwnsHwnd(hwnd)
        return
    gDragging := true
    SetTimer(PinFollowMouse, 10)
}

PinMouseUp(wParam, lParam, msg, hwnd) {
    global gDragging
    if !gDragging
        return
    gDragging := false
    SetTimer(PinFollowMouse, 0)
    ToggleWindowUnderPin()
}

PinFollowMouse() {
    global gPinGui, gDragging
    if !gDragging
        return
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    gPinGui.Move(mx - 46, my - 17)
}

ToggleWindowUnderPin() {
    global gPinGui, gPinText, gTargetHwnd, gLocked, pinNum
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my, &hwndUnder)
    if !hwndUnder
        return
    if PinOwnsHwnd(hwndUnder)
        return

    if gLocked && gTargetHwnd {
        try WinSetAlwaysOnTop(0, "ahk_id " gTargetHwnd)
        gLocked := false
        gTargetHwnd := 0
        gPinText.Text := "PIN " pinNum
        gPinGui.BackColor := "202020"
        ToolTip("Unlocked")
    } else {
        gTargetHwnd := hwndUnder
        WinSetAlwaysOnTop(1, "ahk_id " gTargetHwnd)
        gLocked := true
        gPinText.Text := "LOCKED " pinNum
        gPinGui.BackColor := "214D2B"
        ToolTip("Locked on top")
    }
    SetTimer(() => ToolTip(), -1200)
}

PinOwnsHwnd(hwnd) {
    global gPinGui
    return hwnd = gPinGui.Hwnd
}

PinRightClick(wParam, lParam, msg, hwnd) {
    global gTargetHwnd
    if !PinOwnsHwnd(hwnd)
        return
    if gTargetHwnd {
        try WinSetAlwaysOnTop(0, "ahk_id " gTargetHwnd)
    }
    ExitApp()
}
