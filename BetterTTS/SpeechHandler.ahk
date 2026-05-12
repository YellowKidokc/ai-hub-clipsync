#Requires AutoHotkey v2

SetOutputVoiceFormat(AudioOutputStreamFormatType) {
    oVoice := ComObject("SAPI.SpVoice")
    oVoice.AllowAudioOutputFormatChangesOnNextSet := 0
    oVoice.AudioOutputStream.Format.Type := AudioOutputStreamFormatType
    oVoice.AudioOutputStream := oVoice.AudioOutputStream
    oVoice.AllowAudioOutputFormatChangesOnNextSet := 1
    return oVoice
}

class SpeechHandler {
    static speaker := SetOutputVoiceFormat(39)
    static voices := SpeechHandler.speaker.GetVoices

    static SpeakText(text, voiceIndex, volume, speed, pitch) {
        this.speaker.Voice := this.voices.Item(voiceIndex)
        this.speaker.Volume := volume
        this.speaker.Rate := (speed/10 - 5)
        pitchValue := pitch - 5
        textWithPitch := '<pitch middle="' pitchValue '">' text '</pitch>'
        this.speaker.Speak(textWithPitch, 9)
    }

    static StopSpeaking() {
        this.speaker.Speak("", 3)
    }

    static PauseSpeech() {
        static isPaused := false
        if (!isPaused) {
            this.speaker.Pause()
            isPaused := true
        } else {
            this.speaker.Resume()
            isPaused := false
        }
    }

    static GetVoiceList() {
        voiceList := []
        Loop this.voices.Count {
            try {
                current_voice := this.voices.Item(A_Index-1)
                lang := current_voice.GetAttribute("Language")
                description := current_voice.GetDescription()
                voiceList.Push(description . " [" . lang . "]")
            } catch {
                voiceList.Push(current_voice.GetDescription())
            }
        }
        return voiceList
    }
}
