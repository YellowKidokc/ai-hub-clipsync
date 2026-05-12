; ============================================================
; Module: BetterTTS Tab v3
; Two-column layout: Settings LEFT, Text RIGHT. CapsLock+C/P/S hotkeys. WAV save.
; ============================================================

RegisterTab("TTS", Build_TTSTab, 200)

global gTTS_TextEdit  := ""
global gTTS_VoiceDD   := ""
global gTTS_VolSlider := ""
global gTTS_SpdSlider := ""
global gTTS_PitSlider := ""
global gTTS_VolLbl    := ""
global gTTS_SpdLbl    := ""
global gTTS_PitLbl    := ""
global gTTS_Status    := ""
global gTTS_VoiceList := []
global gTTS_Speaker   := ""
global gTTS_NormChk   := ""
global gTTS_Paused    := false

Build_TTSTab() {
    global gShell, gTTS_TextEdit, gTTS_VoiceDD
    global gTTS_VolSlider, gTTS_SpdSlider, gTTS_PitSlider
    global gTTS_VolLbl, gTTS_SpdLbl, gTTS_PitLbl, gTTS_Status, gTTS_NormChk

    g := gShell.gui

    ; ---- LEFT: settings panel ----
    g.SetFont("s9 cDDDDDD", "Segoe UI")
    btnPaste := g.AddButton("xm+15 ym+52 w130 h28", "Paste Clipboard")
    btnPaste.OnEvent("Click", (*) => TTS_PasteClip())

    g.SetFont("s9 c888888", "Segoe UI")
    g.AddText("x+14 yp+5 w42", "Voice:")
    gTTS_VoiceDD := g.AddDropDownList("x+5 yp-3 w170 Background1a1a1a cDDDDDD", ["(click Refresh)"])
    gTTS_VoiceDD.Choose(1)
    btnRef := g.AddButton("x+5 yp w52 h28", "Refresh")
    btnRef.OnEvent("Click", (*) => TTS_LoadVoices())

    ; Volume
    g.AddText("xm+15 y+18 w58", "Volume:")
    gTTS_VolSlider := g.AddSlider("x+6 yp-4 w280 Range0-100 TickInterval10")
    gTTS_VolSlider.Value := 100
    gTTS_VolLbl := g.AddEdit("x+6 yp-1 w38 h22 Background1a1a1a cDDDDDD Center", "100")
    gTTS_VolSlider.OnEvent("Change", (*) => TTS_UpdateLabels())
    gTTS_VolLbl.OnEvent("Change",   (*) => TTS_SyncVolEdit())

    ; Speed
    g.AddText("xm+15 y+14 w58", "Speed:")
    gTTS_SpdSlider := g.AddSlider("x+6 yp-4 w280 Range20-80 TickInterval10")
    gTTS_SpdSlider.Value := 50
    gTTS_SpdLbl := g.AddEdit("x+6 yp-1 w38 h22 Background1a1a1a cDDDDDD Center", "5.0")
    gTTS_SpdSlider.OnEvent("Change", (*) => TTS_UpdateLabels())

    ; Pitch
    g.AddText("xm+15 y+14 w58", "Pitch:")
    gTTS_PitSlider := g.AddSlider("x+6 yp-4 w280 Range1-10")
    gTTS_PitSlider.Value := 5
    gTTS_PitLbl := g.AddEdit("x+6 yp-1 w38 h22 Background1a1a1a cDDDDDD Center", "5")
    gTTS_PitSlider.OnEvent("Change", (*) => TTS_UpdateLabels())

    ; Normalize toggle
    gTTS_NormChk := g.AddCheckbox("xm+15 y+20 w400 cDDDDDD", "Run normalizer (math/markdown cleanup)")
    gTTS_NormChk.Value := 1

    ; Playback buttons — stacked vertically under settings
    g.SetFont("s10 cDDDDDD", "Segoe UI")
    btnSpeak := g.AddButton("xm+15 y+24 w130 h32", "Speak")
    btnSpeak.OnEvent("Click", (*) => TTS_Speak())
    btnPause := g.AddButton("x+6 yp w130 h32", "Pause / Resume")
    btnPause.OnEvent("Click", (*) => TTS_Pause())
    btnStop  := g.AddButton("x+6 yp w90 h32", "Stop")
    btnStop.OnEvent("Click",  (*) => TTS_Stop())

    btnSave  := g.AddButton("xm+15 y+6 w130 h32", "Save WAV")
    btnSave.OnEvent("Click",  (*) => TTS_SaveWAV())
    btnQuick := g.AddButton("x+6 yp w130 h32", "Quick Save")
    btnQuick.OnEvent("Click", (*) => TTS_QuickSave())

    ; Hotkey hints
    g.SetFont("s8 c555555", "Segoe UI")
    g.AddText("xm+15 y+24 w400", "CapsLock+C  =  copy selection -> normalize -> speak")
    g.AddText("xm+15 y+6  w400", "CapsLock+V  =  speak text box contents")
    g.AddText("xm+15 y+6  w400", "CapsLock+P  =  pause / resume")
    g.AddText("xm+15 y+6  w400", "CapsLock+S  =  stop")

    ; Status — small, at the bottom of the left panel
    gTTS_Status := g.AddText("xm+15 y+18 w440 h18 c555555", "")

    ; ---- RIGHT: text area (full height) ----
    g.SetFont("s9 cE0E0E0", "Segoe UI")
    gTTS_TextEdit := g.AddEdit("x480 ym+48 w590 h600 Multi VScroll Background111111 cE0E0E0")
}

; ---- SAPI lazy init ----
TTS_GetSpeaker() {
    global gTTS_Speaker
    if (!IsObject(gTTS_Speaker)) {
        try {
            oV := ComObject("SAPI.SpVoice")
            oV.AllowAudioOutputFormatChangesOnNextSet := 0
            oV.AudioOutputStream.Format.Type := 39
            oV.AudioOutputStream := oV.AudioOutputStream
            oV.AllowAudioOutputFormatChangesOnNextSet := 1
            gTTS_Speaker := oV
        }
    }
    return IsObject(gTTS_Speaker) ? gTTS_Speaker : ""
}

TTS_LoadVoices() {
    global gTTS_VoiceDD, gTTS_VoiceList, gTTS_Status
    try {
        spk := TTS_GetSpeaker()
        if (spk = "") {
            gTTS_Status.Text := "SAPI unavailable"
            return
        }
        voices := spk.GetVoices()
        gTTS_VoiceList := []
        names := []
        Loop voices.Count {
            v := voices.Item(A_Index - 1)
            gTTS_VoiceList.Push(v)
            names.Push(v.GetDescription())
        }
        gTTS_VoiceDD.Delete()
        Loop names.Length
            gTTS_VoiceDD.Add([names[A_Index]])
        gTTS_VoiceDD.Choose(1)
        gTTS_Status.Text := "Loaded " names.Length " voices"
    } catch Error as e {
        gTTS_Status.Text := "Voice load error: " e.Message
    }
}

TTS_UpdateLabels() {
    global gTTS_VolSlider, gTTS_SpdSlider, gTTS_PitSlider
    global gTTS_VolLbl, gTTS_SpdLbl, gTTS_PitLbl
    gTTS_VolLbl.Value := gTTS_VolSlider.Value
    gTTS_SpdLbl.Value := Format("{:.1f}", gTTS_SpdSlider.Value / 10)
    gTTS_PitLbl.Value := gTTS_PitSlider.Value
}

TTS_SyncVolEdit() {
    global gTTS_VolSlider, gTTS_VolLbl
    try {
        v := Integer(gTTS_VolLbl.Value)
        if (v >= 0 && v <= 100)
            gTTS_VolSlider.Value := v
    }
}

TTS_PasteClip() {
    global gTTS_TextEdit, gTTS_Status
    text := A_Clipboard
    if (text = "") {
        gTTS_Status.Text := "Clipboard empty"
        return
    }
    gTTS_TextEdit.Value := text
    gTTS_Status.Text := "Pasted " StrLen(text) " chars"
}

TTS_Normalize(text) {
    normDir  := A_ScriptDir "\BetterTTS\normalizer"
    bridge   := normDir "\normalize_bridge.py"
    inFile   := A_Temp "\tts_in.txt"
    outFile  := A_Temp "\tts_out.txt"
    if (!FileExist(bridge))
        return text
    try {
        if FileExist(inFile)  FileDelete(inFile)
        if FileExist(outFile) FileDelete(outFile)
        FileAppend(text, inFile, "UTF-8")
        RunWait('python "' bridge '" "' inFile '" "' outFile '"', normDir, "Hide")
        if FileExist(outFile) {
            result := FileRead(outFile, "UTF-8")
            if FileExist(inFile)  FileDelete(inFile)
            if FileExist(outFile) FileDelete(outFile)
            if (Trim(result) != "")
                return Trim(result)
        }
    } catch Error as e {
    }
    return text
}

TTS_SetStatus(msg) {
    global gTTS_Status
    if IsObject(gTTS_Status)
        gTTS_Status.Text := msg
    ToolTip(msg)
    SetTimer(() => ToolTip(), -2000)
}

TTS_Speak() {
    global gTTS_TextEdit, gTTS_NormChk
    text := gTTS_TextEdit.Value
    if (text = "") {
        TTS_SetStatus("Nothing to speak - paste text first")
        return
    }
    if (IsObject(gTTS_NormChk) && gTTS_NormChk.Value) {
        TTS_SetStatus("Normalizing...")
        text := TTS_Normalize(text)
    }
    TTS_SetStatus("Speaking...")
    SetTimer(() => TTS_DoSpeak(text), -1)
}

TTS_DoSpeak(text) {
    global gTTS_VoiceList, gTTS_VoiceDD, gTTS_VolSlider, gTTS_SpdSlider, gTTS_PitSlider, gTTS_Paused
    try {
        spk := TTS_GetSpeaker()
        if (spk = "") {
            TTS_SetStatus("SAPI init failed - click Refresh")
            return
        }
        ; If paused, resume first so purge can take effect
        if (gTTS_Paused) {
            spk.Resume()
            gTTS_Paused := false
        }
        ; Purge any currently playing speech before starting new
        spk.Speak("", 3)  ; SVSFPurgeBeforeSpeak(2) + SVSFlagsAsync(1)
        idx := gTTS_VoiceDD.Value
        if (gTTS_VoiceList.Length >= idx && idx > 0)
            spk.Voice := gTTS_VoiceList[idx]
        spk.Volume := gTTS_VolSlider.Value
        spk.Rate   := (gTTS_SpdSlider.Value / 10) - 5
        pit := gTTS_PitSlider.Value - 5
        ; Flag 11 = Async(1) + PurgeBeforeSpeak(2) + IsXML(8)
        spk.Speak('<pitch middle="' pit '">' text '</pitch>', 11)
        TTS_SetStatus("Speaking...")
    } catch Error as e {
        TTS_SetStatus("Speak error: " e.Message)
    }
}

TTS_Pause() {
    global gTTS_Paused
    spk := TTS_GetSpeaker()
    if (!IsObject(spk)) {
        TTS_SetStatus("Nothing playing")
        return
    }
    try {
        gTTS_Paused := !gTTS_Paused
        if (gTTS_Paused) {
            spk.Pause()
            TTS_SetStatus("Paused")
        } else {
            spk.Resume()
            TTS_SetStatus("Resumed — speaking")
        }
    } catch Error as e {
        TTS_SetStatus("Pause error: " e.Message)
    }
}

TTS_Stop() {
    global gTTS_Paused
    spk := TTS_GetSpeaker()
    if (!IsObject(spk)) {
        TTS_SetStatus("Nothing playing")
        return
    }
    try {
        if (gTTS_Paused) {
            spk.Resume()
            gTTS_Paused := false
        }
        spk.Speak("", 3)
        TTS_SetStatus("Stopped")
    } catch Error as e {
        TTS_SetStatus("Stop error: " e.Message)
    }
}

TTS_SaveWAV() {
    global gTTS_TextEdit, gTTS_VoiceList, gTTS_VoiceDD, gTTS_VolSlider, gTTS_SpdSlider, gTTS_PitSlider, gTTS_NormChk
    text := gTTS_TextEdit.Value
    if (text = "") {
        TTS_SetStatus("Nothing to save - add text first")
        return
    }
    if (IsObject(gTTS_NormChk) && gTTS_NormChk.Value)
        text := TTS_Normalize(text)
    savePath := FileSelect("S16", A_Desktop "\speech.wav", "Save WAV File", "WAV Files (*.wav)")
    if (savePath = "")
        return
    TTS_SetStatus("Saving WAV...")
    try {
        oStream := ComObject("SAPI.SpFileStream")
        oStream.Open(savePath, 3, false)
        oVoice := ComObject("SAPI.SpVoice")
        oVoice.AudioOutputStream := oStream
        idx := gTTS_VoiceDD.Value
        if (gTTS_VoiceList.Length >= idx && idx > 0)
            oVoice.Voice := gTTS_VoiceList[idx]
        oVoice.Volume := gTTS_VolSlider.Value
        oVoice.Rate   := (gTTS_SpdSlider.Value / 10) - 5
        pit := gTTS_PitSlider.Value - 5
        oVoice.Speak('<pitch middle="' pit '">' text '</pitch>', 0)
        oStream.Close()
        TTS_SetStatus("Saved: " savePath)
    } catch Error as e {
        TTS_SetStatus("Save error: " e.Message)
    }
}

TTS_QuickSave() {
    global gTTS_TextEdit, gTTS_VoiceList, gTTS_VoiceDD, gTTS_VolSlider, gTTS_SpdSlider, gTTS_PitSlider, gTTS_NormChk
    text := gTTS_TextEdit.Value
    if (text = "") {
        TTS_SetStatus("Nothing to save - add text first")
        return
    }

    ; Normalize if enabled
    if (IsObject(gTTS_NormChk) && gTTS_NormChk.Value)
        text := TTS_Normalize(text)

    ; Auto-generate filename in Downloads
    timestamp := FormatTime(, "yyyy-MM-dd_HHmmss")
    downloadsDir := EnvGet("USERPROFILE") "\Downloads"
    savePath := downloadsDir "\speech_" timestamp ".wav"

    TTS_SetStatus("Quick saving to Downloads...")
    try {
        oStream := ComObject("SAPI.SpFileStream")
        oStream.Open(savePath, 3, false)
        oVoice := ComObject("SAPI.SpVoice")
        oVoice.AudioOutputStream := oStream
        idx := gTTS_VoiceDD.Value
        if (gTTS_VoiceList.Length >= idx && idx > 0)
            oVoice.Voice := gTTS_VoiceList[idx]
        oVoice.Volume := gTTS_VolSlider.Value
        oVoice.Rate   := (gTTS_SpdSlider.Value / 10) - 5
        pit := gTTS_PitSlider.Value - 5
        oVoice.Speak('<pitch middle="' pit '">' text '</pitch>', 0)
        oStream.Close()
        TTS_SetStatus("Saved: " savePath)
    } catch Error as e {
        TTS_SetStatus("Quick save error: " e.Message)
    }
}

; ---- CapsLock hotkeys ----
TTS_Legacy_CapsC(*) {
    global gTTS_TextEdit, gTTS_NormChk
    SetCapsLockState("AlwaysOff")
    saved := A_Clipboard
    A_Clipboard := ""
    Send("^c")
    if (!ClipWait(1)) {
        TTS_SetStatus("CapsLock+C: nothing selected")
        return
    }
    text := A_Clipboard
    A_Clipboard := saved
    if (IsObject(gTTS_NormChk) && gTTS_NormChk.Value) {
        TTS_SetStatus("Normalizing...")
        text := TTS_Normalize(text)
    }
    if (IsObject(gTTS_TextEdit))
        gTTS_TextEdit.Value := text
    TTS_SetStatus("Speaking (CapsLock+C)...")
    SetTimer(() => TTS_DoSpeak(text), -1)
}

TTS_Legacy_CapsV(*) {
    SetCapsLockState("AlwaysOff")
    TTS_Speak()
}

TTS_Legacy_CapsP(*) {
    SetCapsLockState("AlwaysOff")
    TTS_Pause()
}

TTS_Legacy_CapsS(*) {
    SetCapsLockState("AlwaysOff")
    TTS_Stop()
}
