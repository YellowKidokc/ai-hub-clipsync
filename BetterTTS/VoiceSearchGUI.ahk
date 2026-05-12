#Requires AutoHotkey v2

class VoiceSearchGUI {
    gui := unset
    searchEdit := unset
    voiceListView := unset
    resultsList := []
    allVoices := []
    parentGui := unset
    parentControl := unset
    ocr := unset

    __New(parentGui, parentControl, voiceList, currentVoiceIndex, ocrClass) {
        this.parentGui := parentGui
        this.parentControl := parentControl
        this.allVoices := voiceList
        this.ocr := ocrClass
        this.Create(currentVoiceIndex)
    }

    Create(currentVoiceIndex) {
        this.gui := Gui("+AlwaysOnTop +ToolWindow +Owner" this.parentGui.gui.Hwnd)
        this.gui.Title := this.ocr.GetTranslation("voiceSearch")
        this.gui.SetFont("s10 cDDDDDD", "Segoe UI")
        this.gui.BackColor := "0f0f0f"
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.gui.Hwnd, "Int", 20, "Int*", 1, "Int", 4)

        this.gui.AddText("x10 y10 w400", this.ocr.GetTranslation("searchForVoices"))
        this.searchEdit := this.gui.AddEdit("x10 y30 w400 h25 Background1a1a1a cE0E0E0")
        this.searchEdit.OnEvent("Change", this.UpdateSearch.Bind(this))

        this.voiceListView := this.gui.AddListView("x10 y65 w400 h300 -Multi", [this.ocr.GetTranslation("voiceColumn")])
        this.voiceListView.OnEvent("DoubleClick", this.SelectVoice.Bind(this))
        this.voiceListView.ModifyCol(1, 380)

        for voice in this.allVoices
            this.voiceListView.Add("", voice)

        if (currentVoiceIndex > 0 && currentVoiceIndex <= this.voiceListView.GetCount())
            this.voiceListView.Modify(currentVoiceIndex, "Select Focus")

        selectBtn := this.gui.AddButton("x200 y375 w100 h30 Default", this.ocr.GetTranslation("select"))
        selectBtn.OnEvent("Click", this.SelectVoice.Bind(this))

        cancelBtn := this.gui.AddButton("x310 y375 w100 h30", this.ocr.GetTranslation("cancel"))
        cancelBtn.OnEvent("Click", (*) => this.gui.Destroy())

        this.gui.OnEvent("Escape", (*) => this.gui.Destroy())
        this.gui.OnEvent("Close", (*) => this.gui.Destroy())

        WinGetPos(&parentX, &parentY, &parentW, &parentH, "ahk_id " this.parentGui.gui.Hwnd)
        guiX := parentX + (parentW / 2) - 210
        guiY := parentY + (parentH / 2) - 200
        this.gui.Show("x" guiX " y" guiY " w420 h415")
        this.searchEdit.Focus()
    }

    UpdateSearch(*) {
        searchTerm := this.searchEdit.Value
        this.voiceListView.Delete()
        if (searchTerm = "") {
            for voice in this.allVoices
                this.voiceListView.Add("", voice)
        } else {
            for voice in this.allVoices {
                if (InStr(voice, searchTerm, false))
                    this.voiceListView.Add("", voice)
            }
        }
        if (this.voiceListView.GetCount() > 0)
            this.voiceListView.Modify(1, "Select Focus")
    }

    SelectVoice(*) {
        if (row := this.voiceListView.GetNext(0, "Focused")) {
            selectedVoice := this.voiceListView.GetText(row, 1)
            for index, voice in this.allVoices {
                if (voice = selectedVoice) {
                    this.parentControl.Value := index
                    break
                }
            }
            this.gui.Destroy()
        }
    }
}
