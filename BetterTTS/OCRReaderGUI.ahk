#Requires AutoHotkey v2
#include "SpeechHandler.ahk"
#include "VoiceSearchGUI.ahk"

class OCRReaderGUI {
    gui := unset
    textEdit := unset
    voiceDropDown := unset
    volumeSlider := unset
    speedSlider := unset
    pitchSlider := unset
    playButton := unset
    pauseButton := unset
    stopButton := unset
    resetButton := unset
    statusBar := unset
    guiLanguageDropDown := unset
    ocrLanguageDropDown := unset
    overlayCheckbox := unset
    ocr := unset
    voiceSearchButton := unset
    refreshOcrLanguagesButton := unset
    textGroupBox := unset
    voiceGroupBox := unset
    languageLabel := unset
    ocrLanguageLabel := unset
    voiceLabel := unset
    volumeLabel := unset
    speedLabel := unset
    pitchLabel := unset

    __New(ocrClass) {
        this.ocr := ocrClass
        this.gui := Gui("+Resize")
        this.gui.Title := "Better TTS"
        this.gui.BackColor := "0f0f0f"
        this.gui.SetFont("s10 cDDDDDD", "Segoe UI")
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.gui.Hwnd, "Int", 20, "Int*", 1, "Int", 4)
        this.CreateMenuBar()
        this.CreateControls()
        this.ocr.LoadSettings(this)
        this.UpdateTranslations()
        this.SetupEvents()
        this.Show()
    }

    CreateMenuBar() {
        local mb := MenuBar()
        local fileMenu := Menu()
        fileMenu.Add("&" this.ocr.GetTranslation("saveText"), this.SaveText.Bind(this))
        fileMenu.Add("&" this.ocr.GetTranslation("loadText"), this.LoadText.Bind(this))
        fileMenu.Add()
        fileMenu.Add("&" this.ocr.GetTranslation("exit"), (*) => this.gui.Destroy())
        local settingsMenu := Menu()
        settingsMenu.Add("&" this.ocr.GetTranslation("alwaysOnTop"), this.ToggleAlwaysOnTop.Bind(this))
        settingsMenu.Add("&" this.ocr.GetTranslation("cleanText"), this.ToggleCleanText.Bind(this))
        settingsMenu.Add()
        settingsMenu.Add("&" this.ocr.GetTranslation("installOCRLanguages"), this.OpenLanguageInstaller.Bind(this))
        settingsMenu.Add()
        settingsMenu.Add("&" this.ocr.GetTranslation("resetDefaults"), this.ResetToDefaults.Bind(this))
        local helpMenu := Menu()
        helpMenu.Add("&" this.ocr.GetTranslation("hotkeys"), this.ShowHotkeys.Bind(this))
        helpMenu.Add("&" this.ocr.GetTranslation("languagePackInfo"), (*) => this.ocr.ShowLanguagePackInfo())
        helpMenu.Add()
        helpMenu.Add("&" this.ocr.GetTranslation("about"), this.ShowAbout.Bind(this))
        mb.Add("&" this.ocr.GetTranslation("fileMenu"), fileMenu)
        mb.Add("&" this.ocr.GetTranslation("settingsMenu"), settingsMenu)
        mb.Add("&" this.ocr.GetTranslation("helpMenu"), helpMenu)
        this.gui.MenuBar := mb
    }

    CreateControls() {
        this.textGroupBox := this.gui.AddGroupBox("x10 y10 w480 h300", this.ocr.GetTranslation("capturedText"))
        this.textEdit := this.gui.Add("Edit", "vOCRText x20 y30 w460 h270 Multi Background1a1a1a cE0E0E0")
        this.textEdit.OnEvent("ContextMenu", this.ClearText.Bind(this))
        this.voiceGroupBox := this.gui.AddGroupBox("x10 y320 w480 h250", this.ocr.GetTranslation("voiceSettings"))
        this.languageLabel := this.gui.AddText("x20 y340 w100", this.ocr.GetTranslation("language"))
        this.guiLanguageDropDown := this.gui.AddDropDownList("x120 y338 w150 vSelectedGUILanguage",
            [this.ocr.GetTranslation("english"), this.ocr.GetTranslation("arabic")])
        this.guiLanguageDropDown.OnEvent("Change", (*) => this.ocr.SetGUILanguage(this))
        this.ocrLanguageLabel := this.gui.AddText("x280 y340", this.ocr.GetTranslation("ocrLanguage"))
        this.ocrLanguageDropDown := this.gui.AddDropDownList("x+5 y338 w90 vSelectedOCRLanguage")
        this.refreshOcrLanguagesButton := this.gui.Add("Button", "x+2 y338 w25 h25", "🔄")
        this.refreshOcrLanguagesButton.OnEvent("Click", this.HandleRefreshOCRLanguages.Bind(this))
        this.ocr.UpdateOCRLanguageDropdown(this)
        this.ocrLanguageDropDown.OnEvent("Change", (*) => this.ocr.SetOCRLanguage(this))
        this.voiceLabel := this.gui.AddText("x20 y370 w100", this.ocr.GetTranslation("voice"))
        this.voiceSearchButton := this.gui.Add("Button", "x+0 y368 w25 h25", "🔍")
        this.voiceSearchButton.OnEvent("Click", this.OpenVoiceSearch.Bind(this))
        this.voiceDropDown := this.gui.AddDropDownList("x+2 y368 w332 vSelectedVoice", SpeechHandler.GetVoiceList())
        this.volumeLabel := this.gui.AddText("x20 y400 w100", this.ocr.GetTranslation("volume"))
        this.volumeSlider := this.gui.AddSlider("x120 y398 w300 vVolume Range0-100")
        this.volumeValueLabel := this.gui.AddEdit("x425 y398 w35 h21 Background1a1a1a cE0E0E0", "100")
        this.volumeSlider.OnEvent("Change", this.UpdateVolumeLabel.Bind(this))
        this.volumeValueLabel.OnEvent("Change", this.OnVolumeValueChange.Bind(this))
        this.speedLabel := this.gui.AddText("x20 y430 w100", this.ocr.GetTranslation("speed"))
        this.speedSlider := this.gui.AddSlider("x120 y428 w245 vSpeed Range20-80", 50)
        this.speedValueLabel := this.gui.AddEdit("x370 y428 w35 h21 Background1a1a1a cE0E0E0", "5.0")
        this.resetButton := this.gui.AddButton("x410 y426 w50 h25", "Reset")
        this.resetButton.OnEvent("Click", this.ResetFromClipboard.Bind(this))
        this.speedSlider.OnEvent("Change", this.UpdateSpeedLabel.Bind(this))
        this.speedValueLabel.OnEvent("Change", this.OnSpeedValueChange.Bind(this))
        this.pitchLabel := this.gui.AddText("x20 y460 w100", this.ocr.GetTranslation("pitch"))
        this.pitchSlider := this.gui.AddSlider("x120 y458 w300 vPitch Range1-10")
        this.pitchValueLabel := this.gui.AddEdit("x425 y458 w35 h21 Background1a1a1a cE0E0E0", "5")
        this.pitchSlider.OnEvent("Change", this.UpdatePitchLabel.Bind(this))
        this.pitchValueLabel.OnEvent("Change", this.OnPitchValueChange.Bind(this))
        this.playButton := this.gui.AddButton("x20 y490 w150 h25", this.ocr.GetTranslation("speak"))
        this.pauseButton := this.gui.AddButton("x180 y490 w150 h25", this.ocr.GetTranslation("pause"))
        this.stopButton := this.gui.AddButton("x340 y490 w150 h25", this.ocr.GetTranslation("stop"))
        this.overlayCheckbox := this.gui.AddCheckbox("x20 y525 w460 h25", this.ocr.GetTranslation("showOverlays"))
        this.overlayCheckbox.Value := 1
        this.overlayCheckbox.OnEvent("Click", (*) => this.ocr.ToggleOverlays(this))
        this.statusBar := this.gui.AddStatusBar(, this.ocr.GetTranslation("ready"))
    }

    UpdateTranslations() {
        this.CreateMenuBar()
        this.textGroupBox.Text := this.ocr.GetTranslation("capturedText")
        this.voiceGroupBox.Text := this.ocr.GetTranslation("voiceSettings")
        this.languageLabel.Text := this.ocr.GetTranslation("language")
        this.ocrLanguageLabel.Text := this.ocr.GetTranslation("ocrLanguage")
        this.voiceLabel.Text := this.ocr.GetTranslation("voice")
        this.volumeLabel.Text := this.ocr.GetTranslation("volume")
        this.speedLabel.Text := this.ocr.GetTranslation("speed")
        this.pitchLabel.Text := this.ocr.GetTranslation("pitch")
        this.guiLanguageDropDown.Delete()
        this.guiLanguageDropDown.Add([this.ocr.GetTranslation("english"), this.ocr.GetTranslation("arabic")])
        this.guiLanguageDropDown.Value := (this.ocr.guiLanguage = "eng") ? 1 : 2
        this.ocr.UpdateOCRLanguageDropdown(this)
        this.playButton.Text := this.ocr.GetTranslation("speak")
        this.pauseButton.Text := this.ocr.GetTranslation("pause")
        this.stopButton.Text := this.ocr.GetTranslation("stop")
        this.resetButton.Text := "Reset"
        this.refreshOcrLanguagesButton.Text := "🔄"
        this.overlayCheckbox.Text := this.ocr.GetTranslation("showOverlays")
        this.statusBar.SetText(this.ocr.GetTranslation("ready"))
        this.gui.Title := this.ocr.guiLanguage = "eng" ? "Better TTS" : "قارئ النصوص"
    }

    SetupEvents() {
        this.playButton.OnEvent("Click", (*) => this.ocr.SpeakText(this))
        this.pauseButton.OnEvent("Click", (*) => this.ocr.PauseSpeech(this))
        this.stopButton.OnEvent("Click", (*) => this.ocr.StopSpeaking(this))
        Hotkey "^!x", this.ResetFromClipboard.Bind(this)
        Hotkey "^!+x", (*) => this.ocr.StopSpeaking(this)
        Hotkey "CapsLock & a", (*) => this.clipboardToText()
        Hotkey "CapsLock & c", (*) => this.CopySelectedText()
        this.gui.OnEvent("Close", this.GuiClose.Bind(this))
        this.gui.OnEvent("Size", this.GuiSize.Bind(this))
        Hotkey "CapsLock & x", (*) => this.ocr.CaptureText(this)
        Hotkey "CapsLock & r", (*) => this.ocr.RefreshCapture(this)
        Hotkey "CapsLock & z", (*) => this.ocr.ClearHighlight(this)
        Hotkey "CapsLock & v", (*) => this.ocr.SpeakText(this)
        Hotkey "CapsLock & p", (*) => this.ocr.PauseSpeech(this)
        Hotkey "CapsLock & s", (*) => this.ocr.StopSpeaking(this)
        Hotkey "CapsLock & t", this.ToggleAlwaysOnTop.Bind(this)
        Hotkey "CapsLock & h", (*) => this.ocr.ToggleOverlays(this)
        Hotkey "CapsLock & Up", this.IncreaseVolume.Bind(this)
        Hotkey "CapsLock & Down", this.DecreaseVolume.Bind(this)
        Hotkey "CapsLock & Right", this.IncreaseSpeed.Bind(this)
        Hotkey "CapsLock & Left", this.DecreaseSpeed.Bind(this)
        Hotkey "CapsLock & PgUp", this.IncreasePitch.Bind(this)
        Hotkey "CapsLock & PgDn", this.DecreasePitch.Bind(this)
    }

    Show() {
        this.gui.Show("w500 h590")
    }

    GuiClose(*) {
        this.ocr.SaveSettings(this)
        ExitApp
    }

    GuiSize(thisGui, MinMax, Width, Height) {
        if MinMax = -1
            return
        sliderWidth := Width - 200
        speedSliderWidth := Max(120, sliderWidth - 55)
        this.textEdit.Move(, , Width - 40)
        this.volumeSlider.Move(, , sliderWidth)
        this.volumeValueLabel.Move(120 + sliderWidth + 5)
        this.speedSlider.Move(, , speedSliderWidth)
        this.speedValueLabel.Move(120 + speedSliderWidth + 5)
        this.resetButton.Move(120 + speedSliderWidth + 45)
        this.pitchSlider.Move(, , sliderWidth)
        this.pitchValueLabel.Move(120 + sliderWidth + 5)
    }

    SaveText(*) {
        if (fileName := FileSelect("S16", , this.ocr.GetTranslation("saveFileDialog"), this.ocr.GetTranslation("textFiles"))) {
            try {
                FileAppend(this.textEdit.Value, fileName)
                this.DisplayText(this.ocr.GetTranslation("textSaved"))
            } catch as err {
                MsgBox(this.ocr.GetTranslation("errorSaving") err.Message, this.ocr.GetTranslation("error"), "Icon!")
            }
        }
    }

    LoadText(*) {
        if (fileName := FileSelect(3, , this.ocr.GetTranslation("loadFileDialog"), this.ocr.GetTranslation("textFiles"))) {
            try {
                this.textEdit.Value := FileRead(fileName)
                this.DisplayText(this.ocr.GetTranslation("textLoaded"))
            } catch as err {
                MsgBox(this.ocr.GetTranslation("errorLoading") err.Message, this.ocr.GetTranslation("error"), "Icon!")
            }
        }
    }

    ToggleAlwaysOnTop(*) {
        static isOnTop := false
        isOnTop := !isOnTop
        this.gui.Opt(isOnTop ? "+AlwaysOnTop" : "-AlwaysOnTop")
        this.DisplayText(this.ocr.GetTranslation(isOnTop ? "alwaysOnTopOn" : "alwaysOnTopOff"))
    }

    ToggleCleanText(*) {
        this.ocr.ToggleCleanText(this)
    }

    OpenLanguageInstaller(*) {
        if (this.ocr.CheckAdminAndRestart()) {
            try {
                installer := OCRLanguageInstaller(this.gui, this.ocr)
                installer.Show()
            }
        }
    }

    HandleRefreshOCRLanguages(*) {
        if (this.ocr.CheckAdminAndRestart()) {
            this.ocr.RefreshOCRLanguages(this)
        }
    }

    ShowHotkeys(*) {
        hotkeyGui := Gui("+AlwaysOnTop +Owner" this.gui.Hwnd " +Resize")
        hotkeyGui.Title := this.ocr.GetTranslation("hotkeyTitle")
        hotkeyGui.SetFont("s9 cDDDDDD", "Segoe UI")
        hotkeyGui.BackColor := "0f0f0f"
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hotkeyGui.Hwnd, "Int", 20, "Int*", 1, "Int", 4)
        LV := hotkeyGui.Add("ListView", "w170 h250 Grid", [this.ocr.GetTranslation("hotkeyColumn"), this.ocr.GetTranslation("descriptionColumn")])
        LV.Opt("+LV0x10000")
        LV.Add(, "CapsLock + X", this.ocr.GetTranslation("captureDesc"))
        LV.Add(, "CapsLock + R", this.ocr.GetTranslation("refreshDesc"))
        LV.Add(, "CapsLock + C", this.ocr.GetTranslation("copyDesc"))
        LV.Add(, "CapsLock + Z", this.ocr.GetTranslation("clearDesc"))
        LV.Add(, "CapsLock + V", this.ocr.GetTranslation("speakDesc"))
        LV.Add(, "CapsLock + P", this.ocr.GetTranslation("pauseDesc"))
        LV.Add(, "CapsLock + S", this.ocr.GetTranslation("stopDesc"))
        LV.Add(, "CapsLock + T", this.ocr.GetTranslation("topDesc"))
        LV.Add(, "CapsLock + H", this.ocr.GetTranslation("overlayDesc"))
        LV.Add(, "CapsLock + ↑", this.ocr.GetTranslation("volumeUpDesc"))
        LV.Add(, "CapsLock + ↓", this.ocr.GetTranslation("volumeDownDesc"))
        LV.Add(, "CapsLock + →", this.ocr.GetTranslation("speedUpDesc"))
        LV.Add(, "CapsLock + ←", this.ocr.GetTranslation("speedDownDesc"))
        LV.ModifyCol(1, 90)
        LV.ModifyCol(2, 190)
        closeButton := hotkeyGui.Add("Button", "w80 h25 Default", this.ocr.GetTranslation("ok"))
        closeButton.OnEvent("Click", (*) => hotkeyGui.Destroy())
        HotkeyGuiSize(thisGui, MinMax, Width, Height) {
            if (MinMax = -1)
                return
            LV.Move(, , Width - 16, Height - 35)
            closeButton.Move((Width - 80) // 2, Height - 30)
            LV.ModifyCol(1, 90)
            LV.ModifyCol(2, Width - 106)
        }
        hotkeyGui.OnEvent("Size", HotkeyGuiSize)
        hotkeyGui.Show("w280 h330")
    }

    ShowAbout(*) {
        MsgBox(this.ocr.GetTranslation("aboutText"), this.ocr.GetTranslation("aboutTitle"), "0x40")
    }

    IncreaseVolume(*) {
        newVolume := Min(this.volumeSlider.Value + 10, 100)
        this.volumeSlider.Value := newVolume
        this.UpdateVolumeLabel()
        this.DisplayText(StrReplace(this.ocr.GetTranslation("volumeSet"), "{1}", newVolume))
    }

    DecreaseVolume(*) {
        newVolume := Max(this.volumeSlider.Value - 10, 0)
        this.volumeSlider.Value := newVolume
        this.UpdateVolumeLabel()
        this.DisplayText(StrReplace(this.ocr.GetTranslation("volumeSet"), "{1}", newVolume))
    }

    IncreaseSpeed(*) {
        newSpeed := Min(this.speedSlider.Value + 10, 80)
        this.speedSlider.Value := newSpeed
        this.UpdateSpeedLabel()
        this.DisplayText(StrReplace(this.ocr.GetTranslation("speedSet"), "{1}", newSpeed / 10))
    }

    DecreaseSpeed(*) {
        newSpeed := Max(this.speedSlider.Value - 10, 20)
        this.speedSlider.Value := newSpeed
        this.UpdateSpeedLabel()
        this.DisplayText(StrReplace(this.ocr.GetTranslation("speedSet"), "{1}", newSpeed / 10))
    }

    IncreasePitch(*) {
        newPitch := Min(this.pitchSlider.Value + 1, 10)
        this.pitchSlider.Value := newPitch
        this.UpdatePitchLabel()
        this.DisplayText(StrReplace(this.ocr.GetTranslation("pitchSet"), "{1}", newPitch))
    }

    DecreasePitch(*) {
        newPitch := Max(this.pitchSlider.Value - 1, 1)
        this.pitchSlider.Value := newPitch
        this.UpdatePitchLabel()
        this.DisplayText(StrReplace(this.ocr.GetTranslation("pitchSet"), "{1}", newPitch))
    }

    clipboardToText(*) {
        text := A_Clipboard  ; OCRFromClipboard() does not exist - use clipboard directly


        this.textEdit.Value := text
        this.DisplayText(this.ocr.GetTranslation("textCopied"))
        SetTimer(() => this.ocr.SpeakText(this), -1)
    }

    ClearText(*) {
        this.ocr.StopSpeaking(this)
        this.textEdit.Value := ""
        this.DisplayText("Text cleared")
    }

    ResetFromClipboard(*) {
        text := A_Clipboard
        if Trim(text) = "" {
            this.DisplayText("Clipboard is empty")
            return
        }
        this.ocr.StopSpeaking(this)
        Sleep(120)
        this.textEdit.Value := text
        this.DisplayText("Reset from clipboard")
        SetTimer(() => this.ocr.SpeakText(this), -1)
    }

    CopySelectedText(*) {
        prevClip := A_Clipboard
        A_Clipboard := ""
        Send "^c"
        if ClipWait(0.5) {
            this.textEdit.Value := A_Clipboard
            this.DisplayText(this.ocr.GetTranslation("textCopied"))
            SetTimer(() => this.ocr.SpeakText(this), -1)
            A_Clipboard := prevClip
        } else {
            this.DisplayText(this.ocr.GetTranslation("noTextSelected"))
            A_Clipboard := prevClip
        }
    }

    DisplayText(text) {
        this.statusBar.SetText(text)
        if (this.ocr.showOverlays) {
            MouseGetPos(&mouseX, &mouseY)
            ToolTip(text, mouseX + 10, mouseY + 20)
            SetTimer () => ToolTip(), -1500
        }
    }

    UpdateSpeedLabel(*) {
        this.speedValueLabel.Value := Format("{:.1f}", this.speedSlider.Value / 10)
    }

    OnSpeedValueChange(*) {
        value := this.speedValueLabel.Value
        if (value ~= "^[0-9]*\.?[0-9]*$" && value != "") {
            speed := Float(value)
            if (speed >= 2 && speed <= 10) {
                sliderValue := Round(speed * 10)
                this.speedSlider.Value := Min(Max(sliderValue, 20), 80)
            }
        }
    }

    UpdatePitchLabel(*) {
        this.pitchValueLabel.Value := this.pitchSlider.Value
    }

    OnPitchValueChange(*) {
        value := this.pitchValueLabel.Value
        if (value ~= "^[0-9]+$") {
            pitch := Integer(value)
            if (pitch >= 1 && pitch <= 10)
                this.pitchSlider.Value := pitch
            else if (pitch > 10) {
                this.pitchValueLabel.Value := "10"
                this.pitchSlider.Value := 10
            } else if (pitch < 1) {
                this.pitchValueLabel.Value := "1"
                this.pitchSlider.Value := 1
            }
        } else {
            this.UpdatePitchLabel()
        }
    }

    UpdateVolumeLabel(*) {
        this.volumeValueLabel.Value := this.volumeSlider.Value
    }

    OnVolumeValueChange(*) {
        value := this.volumeValueLabel.Value
        if (value ~= "^[0-9]+$") {
            volume := Integer(value)
            if (volume >= 0 && volume <= 100)
                this.volumeSlider.Value := volume
            else if (volume > 100) {
                this.volumeValueLabel.Value := "100"
                this.volumeSlider.Value := 100
            } else if (volume < 0) {
                this.volumeValueLabel.Value := "0"
                this.volumeSlider.Value := 0
            }
        } else {
            this.UpdateVolumeLabel()
        }
    }

    ResetToDefaults(*) {
        this.voiceDropDown.Value := 1
        this.volumeSlider.Value := 100
        this.speedSlider.Value := 50
        this.pitchSlider.Value := 5
        this.overlayCheckbox.Value := 1
        this.guiLanguageDropDown.Value := 1
        this.ocrLanguageDropDown.Value := 1
        this.UpdateVolumeLabel()
        this.UpdateSpeedLabel()
        this.UpdatePitchLabel()
        this.ocr.cleanTextEnabled := true
        this.ocr.showOverlays := true
        this.ocr.guiLanguage := "eng"
        this.ocr.ocrLanguage := "en-US"
        this.UpdateTranslations()
        this.DisplayText(this.ocr.GetTranslation("settingsReset"))
    }

    OpenVoiceSearch(*) {
        voiceList := SpeechHandler.GetVoiceList()
        voiceSearch := VoiceSearchGUI(this, this.voiceDropDown, voiceList, this.voiceDropDown.Value, this.ocr)
    }
}
