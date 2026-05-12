; ============================================================
; MODULE: Auto-Clicker (Multi-Slot)
; 5 configurable slots with coordinate picker, multiple action
; modes, sequential execution, and safety controls.
;
; Hotkeys:
;   F5          = Pick coordinates (crosshair mode)
;   F8          = Start / Stop automation
;   F12         = Emergency Stop
;   Ctrl+Alt+1-5 = Jump to slot
; ============================================================

#Requires AutoHotkey v2.0+

; ---- Register tab ----
RegisterTab("Auto-Clicker", Build_AutoClickerTab, 55)

; ---- Module State ----
global acSlots := []       ; Array of slot objects
global acRunning := false  ; Is automation running?
global acCurrentSlot := 0  ; Current executing slot (1-based)
global acLoopCount := 0    ; Current loop iteration
global acPicking := false  ; In coordinate pick mode?
global acControls := {}    ; GUI control references

; Initialize 5 slots
InitSlots() {
    global acSlots
    acSlots := []
    loop 5 {
        acSlots.Push({
            enabled: (A_Index = 1),
            x: 0,
            y: 0,
            mode: "Click",
            text: "",
            interval: 1000,
            maxLoops: 0,
            clickType: "Left",
        })
    }
}
InitSlots()

Build_AutoClickerTab() {
    global gShell, acControls, acSlots, DARK_TEXT, INPUT_BG

    gShell.gui.SetFont("s11 c" DARK_TEXT, "Segoe UI")
    gShell.gui.AddText("xm+15 ym+45", "Auto-Clicker — 5 Slots")
    gShell.gui.SetFont("s9 c" DARK_TEXT, "Segoe UI")

    gShell.gui.AddText("xm+15 y+15 c" DARK_TEXT, "Slot:")
    acControls.slotDDL := gShell.gui.Add("DropDownList", "x+10 w80 Choose1", ["1", "2", "3", "4", "5"])
    acControls.slotDDL.OnEvent("Change", (*) => AC_LoadSlot())
    ApplyDarkTheme(acControls.slotDDL)
    ApplyInputTheme(acControls.slotDDL)

    acControls.enabledChk := gShell.gui.Add("CheckBox", "x+15 c" DARK_TEXT " Checked", "Enabled")
    acControls.enabledChk.OnEvent("Click", (*) => AC_SaveCurrentSlot())

    gShell.gui.AddText("xm+15 y+20 c" DARK_TEXT, "X:")
    acControls.xEdit := gShell.gui.Add("Edit", "x+5 w70 Number", "0")
    acControls.xEdit.OnEvent("Change", (*) => AC_SaveCurrentSlot())
    ApplyDarkTheme(acControls.xEdit)
    ApplyInputTheme(acControls.xEdit)

    gShell.gui.AddText("x+15 c" DARK_TEXT, "Y:")
    acControls.yEdit := gShell.gui.Add("Edit", "x+5 w70 Number", "0")
    acControls.yEdit.OnEvent("Change", (*) => AC_SaveCurrentSlot())
    ApplyDarkTheme(acControls.yEdit)
    ApplyInputTheme(acControls.yEdit)

    acControls.btnPick := gShell.gui.Add("Button", "x+15 w130", "Pick Coords (F5)")
    acControls.btnPick.OnEvent("Click", (*) => AC_StartPick())
    ApplyDarkTheme(acControls.btnPick)

    acControls.coordLabel := gShell.gui.Add("Text", "x+10 w200 c888888", "Click a spot on screen")

    gShell.gui.AddText("xm+15 y+20 c" DARK_TEXT, "Action:")
    acControls.modeDDL := gShell.gui.Add("DropDownList", "x+10 w140 Choose1", ["Click", "Type+Enter", "Click+Type", "Type+Click"])
    acControls.modeDDL.OnEvent("Change", (*) => AC_SaveCurrentSlot())
    ApplyDarkTheme(acControls.modeDDL)
    ApplyInputTheme(acControls.modeDDL)

    gShell.gui.AddText("x+15 c" DARK_TEXT, "Click Type:")
    acControls.clickDDL := gShell.gui.Add("DropDownList", "x+5 w100 Choose1", ["Left", "Right", "Middle", "Double"])
    acControls.clickDDL.OnEvent("Change", (*) => AC_SaveCurrentSlot())
    ApplyDarkTheme(acControls.clickDDL)
    ApplyInputTheme(acControls.clickDDL)

    gShell.gui.AddText("xm+15 y+20 c" DARK_TEXT, "Text to type:")
    acControls.textEdit := gShell.gui.Add("Edit", "xm+15 y+5 w400 r3", "")
    acControls.textEdit.OnEvent("Change", (*) => AC_SaveCurrentSlot())
    ApplyDarkTheme(acControls.textEdit)
    ApplyInputTheme(acControls.textEdit)

    gShell.gui.AddText("xm+15 y+15 c" DARK_TEXT, "Interval (ms):")
    acControls.intervalEdit := gShell.gui.Add("Edit", "x+10 w80 Number", "1000")
    acControls.intervalEdit.OnEvent("Change", (*) => AC_SaveCurrentSlot())
    ApplyDarkTheme(acControls.intervalEdit)
    ApplyInputTheme(acControls.intervalEdit)

    gShell.gui.AddText("x+20 c" DARK_TEXT, "Max Loops:")
    acControls.maxLoopEdit := gShell.gui.Add("Edit", "x+10 w80 Number", "0")
    acControls.maxLoopEdit.OnEvent("Change", (*) => AC_SaveCurrentSlot())
    ApplyDarkTheme(acControls.maxLoopEdit)
    ApplyInputTheme(acControls.maxLoopEdit)
    gShell.gui.AddText("x+5 c888888", "(0 = infinite)")

    gShell.gui.AddText("xm+15 y+20 c" DARK_TEXT, "Run Mode:")
    acControls.seqRadio := gShell.gui.Add("Radio", "x+10 c" DARK_TEXT " Checked", "Sequential (all enabled slots)")
    acControls.singleRadio := gShell.gui.Add("Radio", "x+10 c" DARK_TEXT, "Single (current slot only)")

    acControls.btnStart := gShell.gui.Add("Button", "xm+15 y+25 w130 h35", "▶ Start (F8)")
    acControls.btnStart.OnEvent("Click", (*) => AC_Toggle())
    ApplyDarkTheme(acControls.btnStart)

    acControls.btnStop := gShell.gui.Add("Button", "x+10 w130 h35", "⏹ Stop (F12)")
    acControls.btnStop.OnEvent("Click", (*) => AC_Stop())
    ApplyDarkTheme(acControls.btnStop)

    acControls.statusText := gShell.gui.Add("Text", "xm+15 y+20 w500 c888888", "Ready — F5: Pick | F8: Start/Stop | F12: Emergency Stop")

    gShell.gui.AddText("x500 ym+45 c" DARK_TEXT, "Slot Overview")
    gShell.gui.SetFont("s9", "Segoe UI")
    acControls.slotLV := gShell.gui.Add("ListView", "x500 y+8 w450 h300 -Multi +Grid VScroll",
        ["#", "Enabled", "X", "Y", "Mode", "Interval", "Loops"])
    ApplyDarkListView(acControls.slotLV)
    acControls.slotLV.OnEvent("Click", AC_LV_Click)

    gShell.gui.AddText("x500 y+15 c888888",
        "F5 = Pick coords    F8 = Start/Stop    F12 = Emergency Stop`n" .
        "Ctrl+Alt+1-5 = Jump to slot")

    AC_RefreshLV()
    AC_LoadSlot()
}

AC_GetSlotIndex() {
    global acControls
    return Integer(acControls.slotDDL.Text)
}

AC_LoadSlot() {
    global acControls, acSlots
    idx := AC_GetSlotIndex()
    if idx < 1 || idx > acSlots.Length
        return
    s := acSlots[idx]
    acControls.enabledChk.Value := s.enabled
    acControls.xEdit.Value := s.x
    acControls.yEdit.Value := s.y
    acControls.modeDDL.Text := s.mode
    acControls.clickDDL.Text := s.clickType
    acControls.textEdit.Value := s.text
    acControls.intervalEdit.Value := s.interval
    acControls.maxLoopEdit.Value := s.maxLoops
}

AC_SaveCurrentSlot() {
    global acControls, acSlots
    idx := AC_GetSlotIndex()
    if idx < 1 || idx > acSlots.Length
        return
    s := acSlots[idx]
    s.enabled := acControls.enabledChk.Value ? true : false
    s.x := Integer(acControls.xEdit.Value != "" ? acControls.xEdit.Value : 0)
    s.y := Integer(acControls.yEdit.Value != "" ? acControls.yEdit.Value : 0)
    s.mode := acControls.modeDDL.Text
    s.clickType := acControls.clickDDL.Text
    s.text := acControls.textEdit.Value
    s.interval := Integer(acControls.intervalEdit.Value != "" ? acControls.intervalEdit.Value : 1000)
    s.maxLoops := Integer(acControls.maxLoopEdit.Value != "" ? acControls.maxLoopEdit.Value : 0)
    AC_RefreshLV()
}

AC_RefreshLV() {
    global acControls, acSlots
    acControls.slotLV.Delete()
    for i, s in acSlots {
        ena := s.enabled ? "✓" : "—"
        loops := s.maxLoops = 0 ? "∞" : String(s.maxLoops)
        acControls.slotLV.Add("", i, ena, s.x, s.y, s.mode, s.interval, loops)
    }
    acControls.slotLV.ModifyCol(1, 30)
    acControls.slotLV.ModifyCol(2, 55)
    acControls.slotLV.ModifyCol(3, 55)
    acControls.slotLV.ModifyCol(4, 55)
    acControls.slotLV.ModifyCol(5, 90)
    acControls.slotLV.ModifyCol(6, 65)
    acControls.slotLV.ModifyCol(7, 55)
}

AC_LV_Click(lv, row) {
    global acControls
    if row > 0 {
        acControls.slotDDL.Text := String(row)
        AC_LoadSlot()
    }
}

AC_StartPick() {
    global acPicking, acControls
    acPicking := true
    acControls.coordLabel.Text := "Click anywhere... (ESC to cancel)"
    acControls.statusText.Text := "PICK MODE — Click target location (ESC cancels)"
    SetSystemCursor("cross")
    Hotkey("~LButton", AC_PickClick, "On")
    Hotkey("Escape", AC_PickCancel, "On")
}

AC_PickClick(*) {
    global acPicking, acControls
    if !acPicking
        return
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    acControls.xEdit.Value := mx
    acControls.yEdit.Value := my
    acControls.coordLabel.Text := "Picked: " mx ", " my
    AC_SaveCurrentSlot()
    AC_EndPick()
}

AC_PickCancel(*) {
    global acControls
    acControls.coordLabel.Text := "Pick cancelled"
    AC_EndPick()
}

AC_EndPick() {
    global acPicking, acControls
    acPicking := false
    RestoreSystemCursor()
    try Hotkey("~LButton", AC_PickClick, "Off")
    try Hotkey("Escape", AC_PickCancel, "Off")
    acControls.statusText.Text := "Ready — F5: Pick | F8: Start/Stop | F12: Emergency Stop"
}

SetSystemCursor(cursorName) {
    static cursors := Map("cross", 32515, "arrow", 32512)
    if !cursors.Has(cursorName)
        return
    hCursor := DllCall("LoadCursor", "Ptr", 0, "Int", cursors[cursorName], "Ptr")
    for id in [32512, 32513, 32514, 32515, 32516, 32642, 32643, 32644, 32645, 32646, 32648, 32649, 32650]
        DllCall("SetSystemCursor", "Ptr", DllCall("CopyImage", "Ptr", hCursor, "UInt", 2, "Int", 0, "Int", 0, "UInt", 0, "Ptr"), "Int", id)
}

RestoreSystemCursor() {
    DllCall("SystemParametersInfo", "UInt", 0x57, "UInt", 0, "Ptr", 0, "UInt", 0)
}

AC_Toggle() {
    global acRunning
    if acRunning
        AC_Stop()
    else
        AC_Start()
}

AC_Start() {
    global acRunning, acSlots, acControls, acLoopCount
    if acRunning
        return
    sequential := acControls.seqRadio.Value
    if !sequential {
        idx := AC_GetSlotIndex()
        if !acSlots[idx].enabled {
            acControls.statusText.Text := "Slot " idx " is disabled!"
            return
        }
    } else {
        hasEnabled := false
        for s in acSlots {
            if s.enabled {
                hasEnabled := true
                break
            }
        }
        if !hasEnabled {
            acControls.statusText.Text := "No slots enabled!"
            return
        }
    }
    acRunning := true
    acLoopCount := 0
    acControls.btnStart.Text := "⏸ Running..."
    acControls.statusText.Text := "RUNNING — F8 or F12 to stop"
    SetTimer(AC_RunLoop, -10)
}

AC_Stop() {
    global acRunning, acControls
    acRunning := false
    acControls.btnStart.Text := "▶ Start (F8)"
    acControls.statusText.Text := "Stopped. Ready."
}

AC_RunLoop() {
    global acRunning, acSlots, acControls, acLoopCount, acCurrentSlot
    if !acRunning
        return
    sequential := acControls.seqRadio.Value
    acLoopCount++
    if sequential {
        for i, s in acSlots {
            if !acRunning
                return
            if !s.enabled
                continue
            acCurrentSlot := i
            acControls.statusText.Text := "Loop " acLoopCount " — Slot " i " (" s.mode ")"
            AC_ExecuteSlot(s)
            if !acRunning
                return
            Sleep(s.interval)
        }
        masterMax := 0
        for s in acSlots {
            if s.enabled && s.maxLoops > 0 {
                masterMax := s.maxLoops
                break
            }
        }
        if masterMax > 0 && acLoopCount >= masterMax {
            AC_Stop()
            acControls.statusText.Text := "Completed " acLoopCount " loops."
            return
        }
    } else {
        idx := AC_GetSlotIndex()
        s := acSlots[idx]
        acCurrentSlot := idx
        acControls.statusText.Text := "Loop " acLoopCount " — Slot " idx " (" s.mode ")"
        AC_ExecuteSlot(s)
        if !acRunning
            return
        Sleep(s.interval)
        if s.maxLoops > 0 && acLoopCount >= s.maxLoops {
            AC_Stop()
            acControls.statusText.Text := "Completed " acLoopCount " loops."
            return
        }
    }
    if acRunning
        SetTimer(AC_RunLoop, -10)
}

AC_ExecuteSlot(s) {
    global acRunning
    if !acRunning
        return
    CoordMode("Mouse", "Screen")
    switch s.mode {
        case "Click":
            AC_DoClick(s.x, s.y, s.clickType)
        case "Type+Enter":
            AC_DoType(s.text)
            Sleep(30)
            Send("{Enter}")
        case "Click+Type":
            AC_DoClick(s.x, s.y, s.clickType)
            Sleep(100)
            AC_DoType(s.text)
        case "Type+Click":
            AC_DoType(s.text)
            Sleep(100)
            AC_DoClick(s.x, s.y, s.clickType)
    }
}

AC_DoClick(x, y, clickType) {
    CoordMode("Mouse", "Screen")
    MouseMove(x, y, 2)
    Sleep(30)
    switch clickType {
        case "Left":    Click(x, y)
        case "Right":   Click(x, y, "Right")
        case "Middle":  Click(x, y, "Middle")
        case "Double":  Click(x, y, 2)
    }
}

AC_DoType(text) {
    if text = ""
        return
    if IsSet(SafePaste)
        SafePaste(text)
    else {
        old := ClipboardAll()
        A_Clipboard := text
        ClipWait(0.5)
        Send("^v")
        Sleep(60)
        A_Clipboard := old
    }
}

F5:: AC_StartPick()
F8:: AC_Toggle()
F12:: {
    AC_Stop()
    ToolTip("EMERGENCY STOP")
    SetTimer(() => ToolTip(), -2000)
}

^!1:: {
    global acControls
    acControls.slotDDL.Text := "1"
    AC_LoadSlot()
}
^!2:: {
    global acControls
    acControls.slotDDL.Text := "2"
    AC_LoadSlot()
}
^!3:: {
    global acControls
    acControls.slotDDL.Text := "3"
    AC_LoadSlot()
}
^!4:: {
    global acControls
    acControls.slotDDL.Text := "4"
    AC_LoadSlot()
}
^!5:: {
    global acControls
    acControls.slotDDL.Text := "5"
    AC_LoadSlot()
}
