#Requires AutoHotkey v2.0

; ============================================================
; Module: Smooth Scroll
; Applies wheel smoothing to child controls like ListViews/tables.
; ============================================================

CoordMode("Mouse", "Screen")

global SS_WHEEL_DELTA := 120
global SS_SCROLL_SPEED := 16
global SS_SCROLL_ACCEL := 8
global SS_MAX_STEP := 120
global SS_LINES_PER_NOTCH := 1.0

global SS_VAccum := 0
global SS_HAccum := 0
global SS_CurrStepV := SS_SCROLL_SPEED
global SS_CurrStepH := SS_SCROLL_SPEED
global SS_TargetHwnd := 0
global SS_TargetX := 0
global SS_TargetY := 0
global SS_TargetClass := ""
global SS_IsInjecting := false

~WheelUp::SS_AddScroll(1)
~WheelDown::SS_AddScroll(-1)
~WheelLeft::SS_AddHScroll(-1)
~WheelRight::SS_AddHScroll(1)

SS_AddScroll(direction) {
    global SS_WHEEL_DELTA, SS_LINES_PER_NOTCH, SS_VAccum, SS_CurrStepV, SS_IsInjecting
    global SS_TargetHwnd, SS_TargetX, SS_TargetY, SS_TargetClass, SS_SCROLL_SPEED
    if SS_IsInjecting
        return

    MouseGetPos(&mx, &my, &hwnd, &ctrlHwnd, 2)
    prevSign := (SS_VAccum > 0) ? 1 : ((SS_VAccum < 0) ? -1 : 0)
    SS_TargetHwnd := ctrlHwnd ? ctrlHwnd : hwnd
    SS_TargetX := mx
    SS_TargetY := my
    SS_TargetClass := SS_GetClassName(SS_TargetHwnd)

    notchDelta := Round(SS_WHEEL_DELTA * SS_LINES_PER_NOTCH)
    SS_VAccum += direction * notchDelta
    newSign := (SS_VAccum > 0) ? 1 : ((SS_VAccum < 0) ? -1 : 0)
    if (prevSign != 0 && newSign != prevSign)
        SS_CurrStepV := SS_SCROLL_SPEED

    SetTimer(SS_SmoothV, 10)
}

SS_AddHScroll(direction) {
    global SS_WHEEL_DELTA, SS_LINES_PER_NOTCH, SS_HAccum, SS_CurrStepH, SS_IsInjecting
    global SS_TargetHwnd, SS_TargetX, SS_TargetY, SS_TargetClass, SS_SCROLL_SPEED
    if SS_IsInjecting
        return

    MouseGetPos(&mx, &my, &hwnd, &ctrlHwnd, 2)
    prevSign := (SS_HAccum > 0) ? 1 : ((SS_HAccum < 0) ? -1 : 0)
    SS_TargetHwnd := ctrlHwnd ? ctrlHwnd : hwnd
    SS_TargetX := mx
    SS_TargetY := my
    SS_TargetClass := SS_GetClassName(SS_TargetHwnd)

    notchDelta := Round(SS_WHEEL_DELTA * SS_LINES_PER_NOTCH)
    SS_HAccum += direction * notchDelta
    newSign := (SS_HAccum > 0) ? 1 : ((SS_HAccum < 0) ? -1 : 0)
    if (prevSign != 0 && newSign != prevSign)
        SS_CurrStepH := SS_SCROLL_SPEED

    SetTimer(SS_SmoothH, 10)
}

SS_SmoothV() {
    global SS_VAccum, SS_CurrStepV, SS_SCROLL_SPEED, SS_SCROLL_ACCEL, SS_MAX_STEP
    global SS_TargetHwnd, SS_TargetX, SS_TargetY, SS_TargetClass

    if (SS_VAccum = 0 || !SS_TargetExists(SS_TargetHwnd)) {
        SS_VAccum := 0
        SS_CurrStepV := SS_SCROLL_SPEED
        SetTimer(SS_SmoothV, 0)
        return
    }

    magnitude := Min(SS_CurrStepV, Abs(SS_VAccum))
    sign := (SS_VAccum > 0) ? 1 : -1
    step := sign * magnitude
    if !SS_PostVerticalStep(step, SS_TargetHwnd, SS_TargetClass, SS_TargetX, SS_TargetY) {
        SS_VAccum := 0
        SS_CurrStepV := SS_SCROLL_SPEED
        SetTimer(SS_SmoothV, 0)
        return
    }
    SS_VAccum -= step
    SS_CurrStepV := Min(SS_CurrStepV + SS_SCROLL_ACCEL, SS_MAX_STEP)
}

SS_SmoothH() {
    global SS_HAccum, SS_CurrStepH, SS_SCROLL_SPEED, SS_SCROLL_ACCEL, SS_MAX_STEP
    global SS_TargetHwnd, SS_TargetX, SS_TargetY

    if (SS_HAccum = 0 || !SS_TargetExists(SS_TargetHwnd)) {
        SS_HAccum := 0
        SS_CurrStepH := SS_SCROLL_SPEED
        SetTimer(SS_SmoothH, 0)
        return
    }

    magnitude := Min(SS_CurrStepH, Abs(SS_HAccum))
    sign := (SS_HAccum > 0) ? 1 : -1
    step := sign * magnitude
    wParam := step << 16
    lParam := (SS_TargetX & 0xFFFF) | ((SS_TargetY & 0xFFFF) << 16)
    try {
        PostMessage(0x20E, wParam, lParam, , "ahk_id " SS_TargetHwnd)
    } catch {
        SS_HAccum := 0
        SS_CurrStepH := SS_SCROLL_SPEED
        SetTimer(SS_SmoothH, 0)
        return
    }
    SS_HAccum -= step
    SS_CurrStepH := Min(SS_CurrStepH + SS_SCROLL_ACCEL, SS_MAX_STEP)
}

SS_PostVerticalStep(step, hwnd, className, screenX, screenY) {
    static LVM_SCROLL := 0x1014
    static WM_MOUSEWHEEL := 0x20A
    static WM_VSCROLL := 0x115
    static SB_LINEUP := 0
    static SB_LINEDOWN := 1
    global SS_IsInjecting

    if !SS_TargetExists(hwnd)
        return false

    SS_IsInjecting := true
    if (className = "SysListView32") {
        dy := Round(-step / 3)
        if dy != 0 {
            try {
                SendMessage(LVM_SCROLL, 0, dy, , "ahk_id " hwnd)
            } catch {
                SS_IsInjecting := false
                return false
            }
        }
        SetTimer(() => (SS_IsInjecting := false), -20)
        return true
    }

    if InStr(className, "Edit") || InStr(className, "RichEdit") {
        scrollCmd := step > 0 ? SB_LINEUP : SB_LINEDOWN
        try {
            SendMessage(WM_VSCROLL, scrollCmd, 0, , "ahk_id " hwnd)
        } catch {
            SS_IsInjecting := false
            return false
        }
        SetTimer(() => (SS_IsInjecting := false), -20)
        return true
    }

    wParam := step << 16
    lParam := (screenX & 0xFFFF) | ((screenY & 0xFFFF) << 16)
    try {
        PostMessage(WM_MOUSEWHEEL, wParam, lParam, , "ahk_id " hwnd)
    } catch {
        SS_IsInjecting := false
        return false
    }
    SetTimer(() => (SS_IsInjecting := false), -20)
    return true
}

SS_TargetExists(hwnd) {
    return hwnd && WinExist("ahk_id " hwnd)
}

SS_GetClassName(hwnd) {
    if !SS_TargetExists(hwnd)
        return ""
    buf := Buffer(256, 0)
    DllCall("GetClassNameW", "ptr", hwnd, "ptr", buf, "int", 128)
    return StrGet(buf, "UTF-16")
}
