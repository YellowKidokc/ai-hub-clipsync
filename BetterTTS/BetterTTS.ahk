#Requires AutoHotkey v2
#include "OCR.ahk"
#include "RectangleCreator.ahk"
#include "SpeechHandler.ahk"
#include "Highlighter.ahk"
#include "OCRReaderGUI.ahk"

; Set distinct tray icon
if FileExist(A_ScriptDir "\GHOSTY.ICO")
    TraySetIcon(A_ScriptDir "\GHOSTY.ICO")
A_IconTip := "BetterTTS"

; Global settings
CoordMode "Mouse", "Screen"
CoordMode "ToolTip", "Screen"
DllCall("SetThreadDpiAwarenessContext", "ptr", -3)
SetCapsLockState("AlwaysOff")
CapsLock::SetCapsLockState("AlwaysOff")

class BetterTTS {
    static showOverlays := true
    static cleanTextEnabled := true
    static settingsFile := A_ScriptDir "\settings.ini"
    static box := Rectangle_creator()
    static guiLanguage := "eng"
    static ocrLanguage := "en-US"
    static isPaused := false
    static installedOCRLanguages := Map()
    static ocrLanguageNames := Map()

    static translations := Map(
        "eng", Map(
            "capturedText", "📝 Captured Text",
            "voiceSettings", "🎙️ Voice Settings",
            "language", "🌐 Interface:",
            "ocrLanguage", "🔍 OCR:",
            "english", "🇺🇸 English",
            "arabic", "🇸🇦 Arabic",
            "voice", "🗣️ Voice:",
            "volume", "🔊 Volume:",
            "speed", "⚡ Speed:",
            "speak", "🔊 Speak",
            "pause", "⏸️ Pause",
            "resume", "⏯️ Resume",
            "stop", "⏹️ Stop",
            "ready", "✅ Ready",
            "textCaptured", "📸 Text captured",
            "captureRefreshed", "🔄 Capture refreshed",
            "highlightCleared", "🧹 Highlight cleared",
            "speaking", "🗣️ Speaking...",
            "speechPaused", "⏸️ Speech paused",
            "speechStopped", "⏹️ Speech stopped",
            "overlaysDisabled", "🚫 Overlays disabled",
            "overlaysEnabled", "✅ Overlays enabled",
            "cleanTextOn", "✨ Clean text: On",
            "cleanTextOff", "❌ Clean text: Off",
            "languageSet", "🌐 Interface language set to: ",
            "ocrLanguageSet", "🔍 OCR language set to: ",
            "volumeSet", "🔊 Volume: {1}%",
            "speedSet", "⚡ Speed: {1}",
            "textCopied", "📋 Text copied from selection",
            "noTextSelected", "⚠️ No text was selected",
            "showOverlays", "🎯 Show Overlays",
            "refreshOCRLanguages", "🔄 Refresh OCR Languages",
            "ocrLanguagesRefreshed", "✅ OCR languages refreshed",
            "refreshingOCRLanguages", "🔄 Refreshing OCR languages...",
            "noOCRLanguagesFound", "⚠️ No OCR languages found",
            "adminRequired", "⚠️ Administrator privileges required",
            "adminRequiredText", "Refreshing OCR languages requires administrator privileges.`n`nPlease run as administrator to use this feature.",
            "fileMenu", "📁 File",
            "settingsMenu", "⚙️ Settings",
            "helpMenu", "❓ Help",
            "voiceSearch", "🔍 Voice Search",
            "searchForVoices", "🔍 Search for voices:",
            "voiceColumn", "Voice",
            "select", "✅ Select",
            "cancel", "❌ Cancel",
            "saveText", "💾 Save Text",
            "loadText", "📂 Load Text",
            "exit", "🚪 Exit",
            "alwaysOnTop", "📌 Always on Top",
            "cleanText", "✨ Clean Text",
            "hotkeys", "⌨️ Hotkeys",
            "about", "ℹ️ About",
            "textSaved", "✅ Text saved successfully",
            "textLoaded", "✅ Text loaded successfully",
            "alwaysOnTopOn", "📌 Always on top: On",
            "alwaysOnTopOff", "❌ Always on top: Off",
            "saveFileDialog", "💾 Save Captured Text",
            "loadFileDialog", "📂 Load Text File",
            "textFiles", "📄 Text Files (*.txt)",
            "errorSaving", "❌ Error saving file: ",
            "errorLoading", "❌ Error loading file: ",
            "error", "⚠️ Error",
            "hotkeyTitle", "⌨️ Available Hotkeys",
            "hotkeyDesc", "⌨️ Keyboard Shortcuts",
            "captureDesc", "📸 Capture new text",
            "refreshDesc", "🔄 Refresh captured text",
            "copyDesc", "📋 Copy selected text",
            "clearDesc", "🧹 Clear highlight",
            "speakDesc", "🔊 Start speaking",
            "pauseDesc", "⏯️ Pause/Resume speech",
            "stopDesc", "⏹️ Stop speaking",
            "topDesc", "📌 Toggle always on top",
            "overlayDesc", "🎯 Toggle overlays",
            "volumeUpDesc", "🔊 Increase volume",
            "volumeDownDesc", "🔈 Decrease volume",
            "speedUpDesc", "⚡ Increase speed",
            "speedDownDesc", "🐌 Decrease speed",
            "aboutTitle", "ℹ️ About Better TTS",
            "aboutText", "✨ Better TTS`nVersion v1.0`n`nCreated with AutoHotkey v2",
            "hotkeyColumn", "⌨️ Hotkey",
            "descriptionColumn", "📝 Description",
            "ok", "✅ OK",
            "pitch", "🎵 Pitch:",
            "pitchSet", "🎵 Pitch: {1}",
            "resetDefaults", "🔄 Reset to Defaults",
            "settingsReset", "✨ Settings reset to defaults",
            "languagePackInfo", "🔍 Language Pack Requirements",
            "languagePackInfoTitle", "OCR Language Pack Requirements",
            "languagePackInfoText", "To use OCR with different languages, install the appropriate language packs.`n`n1. Go to Windows Settings > Time & Language > Language & region`n2. Click 'Add a language'`n3. During installation, select the OCR feature`n`nAfter installation, click 'Refresh OCR Languages'.",
            "installOCRLanguages", "📦 Install OCR Languages",
            "removeOCRLanguages", "🗑️ Remove OCR Languages",
            "close", "❌ Close",
            "availableOCRLanguagePacks", "Available OCR Language Packs (double-click to install):",
            "languageCode", "Language Code",
            "status", "Status",
            "refreshList", "🔄 Refresh List",
            "install", "📦 Install",
            "remove", "🗑️ Remove",
            "loadingLanguages", "Loading languages... Please wait...",
            "installed", "Installed",
            "notInstalled", "Not Installed",
            "foundOCRLanguagePacks", "Found {1} OCR language packs. Double-click or select and click Install.",
            "errorRetrievingLanguageList", "Error: Could not retrieve language list.",
            "errorLoadingLanguages", "Error: Failed to load languages. ",
            "pleaseSelectLanguageToInstall", "Please select a language to install.",
            "alreadyInstalled", " is already installed.",
            "installing", "Installing ",
            "installationCompleted", "Installation completed for {1}! Click Refresh to update list.",
            "errorInstalling", "Error: Failed to install ",
            "pleaseSelectLanguageToRemove", "Please select a language to remove.",
            "notInstalledOrCannotBeRemoved", " is not installed or cannot be removed.",
            "removing", "Removing ",
            "removalCompleted", "Removal completed for {1}! Click Refresh to update list.",
            "errorRemoving", "Error: Failed to remove "
        )
    )

    static GetTranslation(key) {
        return this.translations[this.guiLanguage][key]
    }

    static ReverseArabicWords(text) {
        if (this.ocrLanguage != "ar-SA")
            return text
        words := StrSplit(text, " ")
        reversed := ""
        Loop words.Length {
            reversed .= words[words.Length - A_Index + 1] . (A_Index < words.Length ? " " : "")
        }
        return reversed
    }

    static LoadInstalledOCRLanguages() {
        this.installedOCRLanguages.Clear()
        this.ocrLanguageNames.Clear()
        this.installedOCRLanguages["en-US"] := "🇺🇸 English (en-US)"
        this.ocrLanguageNames["en-US"] := "English"
        try {
            PSCommand := "powershell -Command `"Get-WindowsCapability -Online | Where-Object { $_.Name -Like 'Language.OCR*' -and $_.State -eq 'Installed' } | ForEach-Object { $_.Name }`""
            TempFile := A_Temp . "\InstalledOCRLanguages.txt"
            RunWait(PSCommand . " > `"" . TempFile . "`"", , "Hide")
            if (FileExist(TempFile)) {
                FileContent := FileRead(TempFile)
                FileDelete(TempFile)
                Lines := StrSplit(FileContent, "`n")
                for Line in Lines {
                    Line := Trim(Line)
                    if (Line = "")
                        continue
                    if (RegExMatch(Line, "Language\.OCR~~~(.+?)~", &Match)) {
                        LanguageCode := Match[1]
                        FriendlyName := this.GetFriendlyLanguageName(LanguageCode)
                        this.installedOCRLanguages[LanguageCode] := FriendlyName
                        this.ocrLanguageNames[LanguageCode] := FriendlyName
                    }
                }
            }
        } catch Error as err {
        }
    }

    static GetFriendlyLanguageName(languageCode) {
        return "🌐 " . languageCode
    }

    static RefreshOCRLanguages(gui) {
        if (!A_IsAdmin) {
            MsgBox(this.GetTranslation("adminRequiredText"), this.GetTranslation("adminRequired"), "48")
            return
        }
        gui.DisplayText(this.GetTranslation("refreshingOCRLanguages"))
        this.LoadInstalledOCRLanguages()
        this.UpdateOCRLanguageDropdown(gui)
        gui.DisplayText(this.GetTranslation("ocrLanguagesRefreshed"))
    }

    static UpdateOCRLanguageDropdown(gui) {
        currentIndex := gui.ocrLanguageDropDown.Value
        currentLanguage := ""
        if (currentIndex > 0 && currentIndex <= this.installedOCRLanguages.Count) {
            counter := 1
            for code, name in this.installedOCRLanguages {
                if (counter = currentIndex) {
                    currentLanguage := code
                    break
                }
                counter++
            }
        }
        gui.ocrLanguageDropDown.Delete()
        options := []
        newIndex := 1
        selectedIndex := 1
        for code, name in this.installedOCRLanguages {
            options.Push(name)
            if (code = currentLanguage || (currentLanguage = "" && code = this.ocrLanguage))
                selectedIndex := newIndex
            newIndex++
        }
        if (options.Length = 0) {
            options.Push("🇺🇸 English (en-US)")
            this.installedOCRLanguages["en-US"] := "🇺🇸 English (en-US)"
        }
        gui.ocrLanguageDropDown.Add(options)
        gui.ocrLanguageDropDown.Value := selectedIndex
    }

    static CaptureText(gui) {
        this.box.set_first_coord()
        while (GetKeyState("x", "P")) {
            this.box.set_second_coord()
            this.box.set_rectangle()
            this.HighlightArea("Red")
            capturedText := OCR.FromRect(this.box.rectangle[1], this.box.rectangle[2],
                                      this.box.rectangle[3], this.box.rectangle[4], this.ocrLanguage, 2).Text
            gui.textEdit.Value := this.ReverseArabicWords(capturedText)
            Sleep(50)
        }
        gui.DisplayText(this.GetTranslation("textCaptured"))
        SetTimer(() => this.SpeakText(gui), -1)
    }

    static RefreshCapture(gui) {
        gui.textEdit.Value := OCR.FromRect(this.box.rectangle[1], this.box.rectangle[2],
                                      this.box.rectangle[3], this.box.rectangle[4], this.ocrLanguage, 2).Text
        this.HighlightArea("Blue")
        Sleep(100)
        this.HighlightArea("Red")
        gui.DisplayText(this.GetTranslation("captureRefreshed"))
        SetTimer(() => this.SpeakText(gui), -1)
    }

    static ClearHighlight(gui) {
        Highlighter.Highlight()
        ToolTip()
        this.box.isFirstCoord := true
        this.box.isBoxActive := false
        gui.DisplayText(this.GetTranslation("highlightCleared"))
    }

    static SpeakText(gui) {
        if (this.isPaused) {
            SpeechHandler.PauseSpeech()
            this.isPaused := false
            gui.pauseButton.Text := this.GetTranslation("pause")
        }
        SpeechHandler.StopSpeaking()
        gui.playButton.Enabled := false
        gui.DisplayText(this.GetTranslation("speaking"))
        textToSpeak := this.cleanTextEnabled ? this.CleanText(gui.textEdit.Value) : gui.textEdit.Value
        SpeechHandler.SpeakText(textToSpeak, gui.voiceDropDown.Value - 1,
                           gui.volumeSlider.Value, gui.speedSlider.Value,
                           gui.pitchSlider.Value)
        gui.playButton.Enabled := true
        Highlighter.Highlight()
    }

    static PauseSpeech(gui) {
        SpeechHandler.PauseSpeech()
        this.isPaused := !this.isPaused
        gui.pauseButton.Text := this.GetTranslation(this.isPaused ? "resume" : "pause")
        gui.DisplayText(this.GetTranslation(this.isPaused ? "resume" : "pause"))
    }

    static StopSpeaking(gui) {
        if (this.isPaused) {
            SpeechHandler.PauseSpeech()
            this.isPaused := false
            gui.pauseButton.Text := this.GetTranslation("pause")
        }
        SpeechHandler.StopSpeaking()
        gui.DisplayText(this.GetTranslation("speechStopped"))
    }

    static SaveSettings(gui) {
        try {
            IniWrite(gui.voiceDropDown.Value, this.settingsFile, "Settings", "VoiceIndex")
            IniWrite(gui.volumeSlider.Value, this.settingsFile, "Settings", "Volume")
            IniWrite(gui.speedSlider.Value, this.settingsFile, "Settings", "Speed")
            IniWrite(gui.pitchSlider.Value, this.settingsFile, "Settings", "Pitch")
            IniWrite(this.cleanTextEnabled, this.settingsFile, "Settings", "CleanText")
            IniWrite(this.guiLanguage, this.settingsFile, "Settings", "GUILanguage")
            IniWrite(this.ocrLanguage, this.settingsFile, "Settings", "OCRLanguage")
            IniWrite(this.showOverlays, this.settingsFile, "Settings", "ShowOverlays")
            languageCodes := []
            for code, name in this.installedOCRLanguages
                languageCodes.Push(code)
            persistedLanguagesString := ""
            for index, code in languageCodes {
                persistedLanguagesString .= code
                if (index < languageCodes.Length)
                    persistedLanguagesString .= ","
            }
            IniWrite(persistedLanguagesString, this.settingsFile, "Settings", "PersistedOCRLanguages")
        } catch as err {
            MsgBox("Error saving settings: " err.Message, "Error", "0x10")
        }
    }

    static LoadSettings(gui) {
        try {
            gui.voiceDropDown.Value := IniRead(this.settingsFile, "Settings", "VoiceIndex", "1")
            gui.volumeSlider.Value := IniRead(this.settingsFile, "Settings", "Volume", "100")
            gui.speedSlider.Value := IniRead(this.settingsFile, "Settings", "Speed", "50")
            gui.pitchSlider.Value := IniRead(this.settingsFile, "Settings", "Pitch", "5")
            this.cleanTextEnabled := IniRead(this.settingsFile, "Settings", "CleanText", "1")
            this.guiLanguage := IniRead(this.settingsFile, "Settings", "GUILanguage", "eng")
            this.ocrLanguage := IniRead(this.settingsFile, "Settings", "OCRLanguage", "en-US")
            this.showOverlays := IniRead(this.settingsFile, "Settings", "ShowOverlays", "1")
            gui.guiLanguageDropDown.Value := (this.guiLanguage = "eng") ? 1 : 2
            gui.overlayCheckbox.Value := this.showOverlays
            persistedLanguages := IniRead(this.settingsFile, "Settings", "PersistedOCRLanguages", "en-US")
            this.installedOCRLanguages.Clear()
            this.ocrLanguageNames.Clear()
            this.installedOCRLanguages["en-US"] := "🇺🇸 English (en-US)"
            this.ocrLanguageNames["en-US"] := "English"
            for each, code in StrSplit(persistedLanguages, ",") {
                code := Trim(code)
                if (code = "")
                    continue
                FriendlyName := this.GetFriendlyLanguageName(code)
                this.installedOCRLanguages[code] := FriendlyName
                this.ocrLanguageNames[code] := FriendlyName
            }
            this.UpdateOCRLanguageDropdown(gui)
        } catch as err {
            MsgBox("Error loading settings: " err.Message "`nDefault settings will be used.", "Warning", "0x30")
            gui.voiceDropDown.Value := 1
            gui.volumeSlider.Value := 100
            gui.speedSlider.Value := 50
            gui.pitchSlider.Value := 5
            this.cleanTextEnabled := true
            this.guiLanguage := "eng"
            this.ocrLanguage := "en-US"
            this.showOverlays := false
            gui.guiLanguageDropDown.Value := 1
            gui.overlayCheckbox.Value := 0
            this.installedOCRLanguages.Clear()
            this.ocrLanguageNames.Clear()
            this.installedOCRLanguages["en-US"] := "🇺🇸 English (en-US)"
            this.ocrLanguageNames["en-US"] := "English"
            this.UpdateOCRLanguageDropdown(gui)
        }
    }

    static HighlightArea(color) {
        if (this.showOverlays) {
            Highlighter.Highlight(this.box.rectangle[1], this.box.rectangle[2],
                            this.box.rectangle[3], this.box.rectangle[4], 0, color, 1)
        }
    }

    static CleanText(text) {
        ; Try full Theophysics normalizer (math translation, tables, Greek, etc.)
        try {
            normalizerDir := A_ScriptDir "\normalizer"
            bridgeScript := normalizerDir "\normalize_bridge.py"
            
            if (FileExist(bridgeScript)) {
                ; Write input to temp file
                inputFile := A_Temp "\bettertts_input.txt"
                outputFile := A_Temp "\bettertts_output.txt"
                
                ; Clean up any previous files (guard against non-existence)
                if (FileExist(outputFile))
                    FileDelete(outputFile)
                if (FileExist(inputFile))
                    FileDelete(inputFile)
                
                ; Write raw text
                FileAppend(text, inputFile, "UTF-8")
                
                ; Run Python normalizer bridge
                RunWait('python "' bridgeScript '" "' inputFile '" "' outputFile '"', normalizerDir, "Hide")
                
                ; Read normalized output
                if (FileExist(outputFile)) {
                    normalized := FileRead(outputFile, "UTF-8")
                    if (FileExist(inputFile))
                        FileDelete(inputFile)
                    if (FileExist(outputFile))
                        FileDelete(outputFile)
                    if (normalized != "")
                        return Trim(normalized)
                }
            }
        } catch as err {
            ; Normalizer failed — fall through to basic clean
        }
        
        ; Fallback: basic regex clean
        keepCharsPattern := "[^\p{L}\p{N}.,!?;:'`"@$€£%&]"
        cleaned := RegExReplace(text, keepCharsPattern, " ")
        return Trim(RegExReplace(cleaned, "\s+", " "))
    }

    static ToggleOverlays(gui) {
        this.showOverlays := !this.showOverlays
        gui.overlayCheckbox.Value := this.showOverlays ? 1 : 0
        if (!this.showOverlays) {
            Highlighter.Highlight()
            ToolTip()
            gui.DisplayText(this.GetTranslation("overlaysDisabled"))
        } else {
            gui.DisplayText(this.GetTranslation("overlaysEnabled"))
        }
    }

    static ToggleCleanText(gui) {
        this.cleanTextEnabled := !this.cleanTextEnabled
        gui.DisplayText(this.GetTranslation(this.cleanTextEnabled ? "cleanTextOn" : "cleanTextOff"))
    }

    static SetGUILanguage(gui) {
        this.guiLanguage := gui.guiLanguageDropDown.Value = 1 ? "eng" : "ara"
        gui.UpdateTranslations()
        gui.DisplayText(this.GetTranslation("languageSet") . (this.guiLanguage = "eng" ? this.GetTranslation("english") : this.GetTranslation("arabic")))
    }

    static SetOCRLanguage(gui) {
        selectedIndex := gui.ocrLanguageDropDown.Value
        counter := 1
        for code, name in this.installedOCRLanguages {
            if (counter = selectedIndex) {
                this.ocrLanguage := code
                gui.DisplayText(this.GetTranslation("ocrLanguageSet") . name)
                break
            }
            counter++
        }
    }

    static ResetToDefaults(gui) {
        gui.voiceDropDown.Value := 1
        gui.volumeSlider.Value := 100
        gui.speedSlider.Value := 50
        gui.pitchSlider.Value := 5
        gui.overlayCheckbox.Value := 1
        gui.guiLanguageDropDown.Value := 1
        this.cleanTextEnabled := true
        this.showOverlays := true
        this.guiLanguage := "eng"
        this.ocrLanguage := "en-US"
        if (this.installedOCRLanguages.Count > 0) {
            gui.ocrLanguageDropDown.Value := 1
            counter := 1
            for code, name in this.installedOCRLanguages {
                if (counter = 1) {
                    this.ocrLanguage := code
                    break
                }
                counter++
            }
        }
        gui.UpdateTranslations()
        gui.DisplayText(this.GetTranslation("settingsReset"))
    }
}

class OCRLanguageInstaller {
    MyGui := ""
    LanguageList := ""
    RefreshBtn := ""
    InstallBtn := ""
    RemoveBtn := ""
    CloseBtn := ""
    StatusText := ""
    ParentGUI := ""
    OCRClass := ""

    __New(parentGUI, ocrClass) {
        this.ParentGUI := parentGUI
        this.OCRClass := ocrClass
        this.CreateGUI()
        this.LoadLanguages()
    }

    CreateGUI() {
        this.MyGui := Gui("+Resize +Owner" this.ParentGUI.Hwnd, this.OCRClass.GetTranslation("installOCRLanguages"))
        this.MyGui.SetFont("s10 cDDDDDD", "Segoe UI")
        this.MyGui.BackColor := "0f0f0f"
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.MyGui.Hwnd, "Int", 20, "Int*", 1, "Int", 4)
        this.MyGui.Add("Text", "xm y+15 w500", this.OCRClass.GetTranslation("availableOCRLanguagePacks"))
        this.LanguageList := this.MyGui.Add("ListView", "xm y+10 w500 h200 vLanguageList",
            [this.OCRClass.GetTranslation("languageCode"), this.OCRClass.GetTranslation("status")])
        this.LanguageList.OnEvent("DoubleClick", this.InstallSelected.Bind(this))
        this.RefreshBtn := this.MyGui.Add("Button", "xm y+15 w100", this.OCRClass.GetTranslation("refreshList"))
        this.RefreshBtn.OnEvent("Click", this.LoadLanguages.Bind(this))
        this.InstallBtn := this.MyGui.Add("Button", "x+10 yp w120", this.OCRClass.GetTranslation("install"))
        this.InstallBtn.OnEvent("Click", this.InstallSelected.Bind(this))
        this.RemoveBtn := this.MyGui.Add("Button", "x+10 yp w120", this.OCRClass.GetTranslation("remove"))
        this.RemoveBtn.OnEvent("Click", this.RemoveSelected.Bind(this))
        this.CloseBtn := this.MyGui.Add("Button", "x+10 yp w100", this.OCRClass.GetTranslation("close"))
        this.CloseBtn.OnEvent("Click", this.Close.Bind(this))
        this.StatusText := this.MyGui.Add("Text", "xm y+15 w500 h30 +Border", this.OCRClass.GetTranslation("loadingLanguages"))
        this.MyGui.OnEvent("Escape", this.Close.Bind(this))
        this.MyGui.OnEvent("Close", this.Close.Bind(this))
    }

    Show() {
        this.MyGui.Show("w530 h350")
    }

    LoadLanguages(*) {
        this.StatusText.Text := this.OCRClass.GetTranslation("loadingLanguages")
        this.LanguageList.Delete()
        PSCommand := "powershell -Command `"Get-WindowsCapability -Online | Where-Object { $_.Name -Like 'Language.OCR*' } | ForEach-Object { $_.Name + '||' + $_.State }`""
        try {
            TempFile := A_Temp . "\OCRLanguages.txt"
            RunWait(PSCommand . " > `"" . TempFile . "`"", , "Hide")
            if (FileExist(TempFile)) {
                FileContent := FileRead(TempFile)
                FileDelete(TempFile)
                Lines := StrSplit(FileContent, "`n")
                Count := 0
                for Line in Lines {
                    Line := Trim(Line)
                    if (Line = "")
                        continue
                    Parts := StrSplit(Line, "||")
                    if (Parts.Length >= 2) {
                        FullName := Parts[1]
                        State := Parts[2]
                        if (RegExMatch(FullName, "Language\.OCR~~~(.+?)~", &Match)) {
                            LanguageCode := Match[1]
                            TranslatedStatus := (InStr(State, "Installed")) ? this.OCRClass.GetTranslation("installed") : this.OCRClass.GetTranslation("notInstalled")
                            this.LanguageList.Add(, LanguageCode, TranslatedStatus)
                            Count++
                        }
                    }
                }
                this.LanguageList.ModifyCol(1, "AutoHdr")
                this.LanguageList.ModifyCol(2, "AutoHdr")
                this.StatusText.Text := Format(this.OCRClass.GetTranslation("foundOCRLanguagePacks"), Count)
            } else {
                this.StatusText.Text := this.OCRClass.GetTranslation("errorRetrievingLanguageList")
            }
        } catch Error as err {
            this.StatusText.Text := this.OCRClass.GetTranslation("errorLoadingLanguages") . err.Message
        }
    }

    InstallSelected(*) {
        SelectedRow := this.LanguageList.GetNext()
        if (SelectedRow = 0) {
            this.StatusText.Text := this.OCRClass.GetTranslation("pleaseSelectLanguageToInstall")
            return
        }
        LanguageCode := this.LanguageList.GetText(SelectedRow, 1)
        CurrentStatus := this.LanguageList.GetText(SelectedRow, 2)
        if (CurrentStatus = this.OCRClass.GetTranslation("installed")) {
            this.StatusText.Text := LanguageCode . this.OCRClass.GetTranslation("alreadyInstalled")
            return
        }
        this.StatusText.Text := this.OCRClass.GetTranslation("installing") . LanguageCode . "..."
        PSCommand := "powershell -Command `"$Capability = Get-WindowsCapability -Online | Where-Object { $_.Name -Like 'Language.OCR*" . LanguageCode . "*' }; if ($Capability) { $Capability | Add-WindowsCapability -Online }`""
        try {
            RunWait(PSCommand, , "")
            this.StatusText.Text := Format(this.OCRClass.GetTranslation("installationCompleted"), LanguageCode)
            this.LoadLanguages()
        } catch Error as err {
            MsgBox(this.OCRClass.GetTranslation("errorInstalling") . LanguageCode . ". " . err.Message)
        }
    }

    RemoveSelected(*) {
        SelectedRow := this.LanguageList.GetNext()
        if (SelectedRow = 0) {
            this.StatusText.Text := this.OCRClass.GetTranslation("pleaseSelectLanguageToRemove")
            return
        }
        LanguageCode := this.LanguageList.GetText(SelectedRow, 1)
        CurrentStatus := this.LanguageList.GetText(SelectedRow, 2)
        if (CurrentStatus != this.OCRClass.GetTranslation("installed")) {
            this.StatusText.Text := LanguageCode . this.OCRClass.GetTranslation("notInstalledOrCannotBeRemoved")
            return
        }
        this.StatusText.Text := this.OCRClass.GetTranslation("removing") . LanguageCode . "..."
        PSCommand := "powershell -Command `"$Capability = Get-WindowsCapability -Online | Where-Object { $_.Name -Like 'Language.OCR*" . LanguageCode . "*' }; if ($Capability) { $Capability | Remove-WindowsCapability -Online }`""
        try {
            RunWait(PSCommand, , "")
            this.StatusText.Text := Format(this.OCRClass.GetTranslation("removalCompleted"), LanguageCode)
            this.LoadLanguages()
        } catch Error as err {
            MsgBox this.OCRClass.GetTranslation("errorRemoving") . LanguageCode . ". " . err.Message
        }
    }

    Close(*) {
        this.MyGui.Destroy()
    }
}

; Create and initialize the application
app := OCRReaderGUI(BetterTTS)
