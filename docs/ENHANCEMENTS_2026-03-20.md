# AI-HUB v2 Enhancement Pack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement four enhancements to AI-HUB v2: auto-backup config on startup, hide HTML panels from taskbar, improve dark mode on GUI controls, and add quick-save audio download button.

**Architecture:** All changes are in AutoHotkey v2 (.ahk files) and target the existing modular architecture. Each enhancement touches 1-2 files with clear boundaries. The auto-backup is a new module; the other three are modifications to existing files.

**Tech Stack:** AutoHotkey v2.0+, Windows DLL calls (dwmapi, uxtheme, user32), SAPI COM objects

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `modules/autobackup.ahk` | **Create** | Config backup on startup to `D:\AI-HUB-BACKUP\` |
| `modules/config_sync.ahk` | **Create** | Config sync engine — import/export to `D:\AI-HUB-SYNC\` |
| `modules/manifest.ahk` | **Modify** | Add `#Include` lines for new modules |
| `hub_core.ahk` | **Modify** | 1) Wire backup+sync into boot. 2) Fix dark theming. 3) Add `WS_EX_TOOLWINDOW` to HTML panels |
| `modules/bettertts_tab.ahk` | **Modify** | Add "Quick Save" button (auto-save to Downloads, no dialog) |

---

### Task 1: Auto-Backup Config on Startup

**Priority: HIGHEST** — Prevents future data loss from settings being wiped.

**Files:**
- Create: `modules/autobackup.ahk`
- Modify: `modules/manifest.ahk` (add `#Include` line)

**Context for implementer:**
- Config files live in `A_ScriptDir "\config"` (the `CFG_DIR` global)
- Files to back up: `settings.ini`, `prompts.json`, `hotkeys.ini`, `hotstrings.sav`, `storage.json`, `sysprompts.json`, `research_links.json`
- Also back up `Data\` folder (contains `clipboard.db` SQLite database)
- Backup destination: `D:\AI-HUB-BACKUP\latest\` (mirror) + `D:\AI-HUB-BACKUP\daily\YYYY-MM-DD\` (one per day)
- `modules/manifest.ahk` contains `#Include` lines for all modules — add the new one there

- [ ] **Step 1: Create `modules/autobackup.ahk`**

```ahk
; ============================================================
; Module: Auto-Backup — copies config + data on every startup
; ============================================================

Hub_RunBackup() {
    global CFG_DIR

    ; Use D:\ if available, fall back to C:\
    backupRoot := DirExist("D:\") ? "D:\AI-HUB-BACKUP" : "C:\AI-HUB-BACKUP"
    latestDir  := backupRoot "\latest"
    dailyDir   := backupRoot "\daily\" FormatTime(, "yyyy-MM-dd")

    ; Ensure backup directories exist
    ; NOTE: AHK v2 `for val in array` yields INDEX as first var. Use `for , val in array` to get values.
    for , dir in [latestDir "\config", latestDir "\Data", dailyDir "\config", dailyDir "\Data"] {
        if !DirExist(dir)
            DirCreate(dir)
    }

    ; Back up config files (sysprompts.json may not exist yet — FileExist guard handles it)
    configFiles := ["settings.ini", "prompts.json", "hotkeys.ini", "hotstrings.sav",
                    "storage.json", "sysprompts.json", "research_links.json"]
    for , f in configFiles {
        src := CFG_DIR "\" f
        if FileExist(src) {
            try FileCopy(src, latestDir "\config\" f, true)
            try FileCopy(src, dailyDir  "\config\" f, true)
        }
    }

    ; Back up Data folder (clipboard.db etc.) — may not exist on fresh installs
    dataDir := A_ScriptDir "\Data"
    if DirExist(dataDir) {
        Loop Files dataDir "\*.*" {
            try FileCopy(A_LoopFileFullPath, latestDir "\Data\" A_LoopFileName, true)
            try FileCopy(A_LoopFileFullPath, dailyDir  "\Data\" A_LoopFileName, true)
        }
    }
}
```

- [ ] **Step 2: Add include to `modules/manifest.ahk`**

Open `modules/manifest.ahk` and add this line alongside the other `#Include` statements:

```ahk
#Include autobackup.ahk
```

- [ ] **Step 3: Wire backup into boot sequence**

In `hub_core.ahk`, inside `Hub_Boot()` (line 100), insert `try Hub_RunBackup()` as a new line between line 102 (`EnsureConfig()`) and line 104 (`Load_All()`):

```ahk
Hub_Boot() {
    EnsureConfig()
    try Hub_RunBackup()   ; <-- ADD THIS LINE (new line 103)
    Load_All()            ; existing line 104 becomes 105
    LoadPrompts()
    Register_All()
    RegisterBuiltInTabs()
    CreateMainGUI()
    ApplyLoadedUtilitySettings()
    SetupTray()
}
```

- [ ] **Step 4: Manual test**

1. Run AI-HUB.ahk
2. Check which backup root was used — `D:\AI-HUB-BACKUP\` if D:\ exists, else `C:\AI-HUB-BACKUP\`
3. Verify `<root>\latest\config\settings.ini` exists and matches source
4. Verify `<root>\daily\YYYY-MM-DD\config\settings.ini` exists
5. Verify `<root>\latest\Data\` contains clipboard.db (Data folder may not exist on fresh installs — that's OK)

- [ ] **Step 5: Commit**

```bash
git add modules/autobackup.ahk modules/manifest.ahk hub_core.ahk
git commit -m "feat: auto-backup config and data to D:\AI-HUB-BACKUP on every startup"
```

---

### Task 2: Hide HTML Panels from Taskbar (WS_EX_TOOLWINDOW)

**Priority: HIGH** — Reduces taskbar clutter from HTML panel windows.

**Files:**
- Modify: `hub_core.ahk` — `LaunchHtmlPanel()` function (line ~2454)

**Context for implementer:**
- `LaunchHtmlPanel(url, title)` launches Chrome/Edge in `--app=` mode
- These windows appear in the taskbar as separate entries, cluttering it
- Fix: After the window spawns, apply `WS_EX_TOOLWINDOW` (0x80) extended style
- This hides from taskbar while keeping the window accessible and visible
- Must wait for the window to appear before modifying its style
- The function uses title fragments like "Clipboard", "Prompt", "Links", "Calendar" to find windows
- `WS_EX_APPWINDOW` (0x40000) must be REMOVED and `WS_EX_TOOLWINDOW` (0x80) ADDED

- [ ] **Step 1: Add helper function `HideFromTaskbar` to `hub_core.ahk`**

Add this after the `ApplyInputTheme()` function (around line 254):

```ahk
; Hide a window from the taskbar by toggling extended window styles
; Uses GetWindowLongPtr/SetWindowLongPtr for 64-bit compatibility (Windows 11)
HideFromTaskbar(hwnd) {
    GWL_EXSTYLE := -20
    WS_EX_APPWINDOW  := 0x40000
    WS_EX_TOOLWINDOW := 0x80
    exStyle := DllCall("GetWindowLongPtr", "Ptr", hwnd, "Int", GWL_EXSTYLE, "Ptr")
    exStyle := (exStyle | WS_EX_TOOLWINDOW) & ~WS_EX_APPWINDOW
    DllCall("SetWindowLongPtr", "Ptr", hwnd, "Int", GWL_EXSTYLE, "Ptr", exStyle)
    ; Force Windows to refresh the taskbar entry
    DllCall("ShowWindow", "Ptr", hwnd, "Int", 0)  ; SW_HIDE
    DllCall("ShowWindow", "Ptr", hwnd, "Int", 5)  ; SW_SHOW
}
```

- [ ] **Step 2: Modify `LaunchHtmlPanel` to apply style after launch**

In `LaunchHtmlPanel()` (line ~2454), after the `Run(...)` call at the end of the function, add a deferred style application:

```ahk
    ; ... existing Run(...) call at line 2486 ...

    ; After launching, poll for window and hide from taskbar (repeating timer, 500ms interval, 15s timeout)
    SetTimer(HideNewPanel.Bind(searchTitle, A_TickCount), 500)
}

HideNewPanel(searchTitle, startTick) {
    ; Give up after 15 seconds
    if (A_TickCount - startTick > 15000) {
        SetTimer(, 0)
        return
    }
    ; Try both Chrome and Edge
    for , exe in ["chrome.exe", "msedge.exe"] {
        winTitle := searchTitle " ahk_exe " exe
        if WinExist(winTitle) {
            hwnd := WinGetID(winTitle)
            HideFromTaskbar(hwnd)
            SetTimer(, 0)  ; stop repeating
            return
        }
    }
}
```

**Important:** Replace the closing `}` of `LaunchHtmlPanel` with the SetTimer call + new function.

**Also:** In the "already exists" early-return branches (lines 2463-2470), apply `HideFromTaskbar` before returning so reopened windows stay hidden:

```ahk
    if WinExist(searchTitle " ahk_exe chrome.exe") {
        HideFromTaskbar(WinGetID(searchTitle " ahk_exe chrome.exe"))
        WinActivate(searchTitle " ahk_exe chrome.exe")
        return
    }
    if WinExist(searchTitle " ahk_exe msedge.exe") {
        HideFromTaskbar(WinGetID(searchTitle " ahk_exe msedge.exe"))
        WinActivate(searchTitle " ahk_exe msedge.exe")
        return
    }
```

- [ ] **Step 3: Manual test**

1. Run AI-HUB.ahk
2. Wait for Prompts and Links panels to launch (~3 seconds)
3. Verify: Neither panel appears in the taskbar
4. Verify: Both panels are still visible and usable
5. Use Ctrl+Alt+P to toggle Prompts panel — verify it still activates correctly
6. Use Ctrl+Alt+C to open Clipboard panel — verify it also hides from taskbar

- [ ] **Step 4: Commit**

```bash
git add hub_core.ahk
git commit -m "feat: hide HTML panels from taskbar using WS_EX_TOOLWINDOW"
```

---

### Task 3: Fix Dark Mode on GUI Controls

**Priority: MEDIUM** — Visual polish for buttons, edit boxes, dropdowns.

**Files:**
- Modify: `hub_core.ahk` — `CreateMainGUI()` and `ApplyDarkTheme()`

**Context for implementer:**
- Current dark mode: `DwmSetWindowAttribute` for title bar + `SetWindowTheme("DarkMode_Explorer")` for controls
- Problem: Standard Win32 Button and Edit controls ignore `DarkMode_Explorer` theming
- The `ApplyDarkTheme()` function at line 233 only does the uxtheme call
- `ApplyInputTheme()` at line 249 already sets Background + font color on individual controls — but it's only used sparingly
- Fix: After building all tabs, enumerate all child controls and force dark backgrounds
- Color constants already defined: `DARK_BG="0f0f0f"`, `INPUT_BG="1a1a1a"`, `DARK_CTRL="181818"`, `DARK_TEXT="DDDDDD"`
- **Note:** This will override any per-module custom colors (e.g., bettertts_tab uses `Background111111`). In practice the values are near-identical so this is acceptable. If a module needs unique colors, it should re-apply them after `ApplyDarkToAllControls` runs.

- [ ] **Step 1: Add `ApplyDarkToAllControls` function to `hub_core.ahk`**

Add after `ApplyInputTheme()` (line ~253):

```ahk
; Force dark background on all child controls that resist DarkMode_Explorer
ApplyDarkToAllControls(guiObj) {
    global DARK_BG, DARK_CTRL, INPUT_BG, DARK_TEXT
    for hwnd, ctrl in guiObj {
        try {
            ctrlType := ctrl.Type
            if (ctrlType = "Edit" || ctrlType = "ComboBox" || ctrlType = "DDL" || ctrlType = "DropDownList") {
                ctrl.Opt("Background" INPUT_BG)
                ctrl.SetFont("c" DARK_TEXT)
            } else if (ctrlType = "Button" || ctrlType = "CheckBox") {
                ctrl.Opt("Background" DARK_CTRL)
            } else if (ctrlType = "ListBox") {
                ctrl.Opt("Background" INPUT_BG)
                ctrl.SetFont("c" DARK_TEXT)
            }
        }
    }
}
```

- [ ] **Step 2: Call it after all tabs are built**

In `CreateMainGUI()`, after the tab build loop (after line 197 `gShell.tabs.UseTab(0)`), add:

```ahk
    gShell.tabs.UseTab(0)

    ; Force dark backgrounds on controls that resist DarkMode_Explorer
    ApplyDarkToAllControls(gShell.gui)
```

- [ ] **Step 3: Manual test**

1. Run AI-HUB.ahk
2. Check every tab — all Edit boxes should have dark backgrounds (`1a1a1a`), not white
3. Check buttons — should have dark gray backgrounds, not Windows default light gray
4. Check dropdowns — should match the dark theme
5. Navigate between tabs to verify controls don't revert

- [ ] **Step 4: Commit**

```bash
git add hub_core.ahk
git commit -m "fix: force dark backgrounds on edit boxes, buttons, and dropdowns"
```

---

### Task 4: Quick-Save Audio Download Button

**Priority: LOW** — Convenience enhancement for TTS.

**Files:**
- Modify: `modules/bettertts_tab.ahk`

**Context for implementer:**
- `TTS_SaveWAV()` already exists (line 272) — it opens a file dialog every time
- Enhancement: Add a "Quick Save" button that auto-saves to Downloads with timestamp
- No dialog, one click, filename like `speech_2026-03-20_143052.wav`
- The existing Save WAV button stays — this is an additional convenience button
- SAPI file stream code from `TTS_SaveWAV()` can be reused directly
- The normalize step should run before saving (currently `TTS_SaveWAV` skips normalization)

- [ ] **Step 1: Add `TTS_QuickSave` function to `bettertts_tab.ahk`**

Add after `TTS_SaveWAV()` (after line 300):

```ahk
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
```

- [ ] **Step 2: Add "Quick Save" button to the TTS tab layout**

In `Build_TTSTab()`, after the Save WAV button (line 42), add:

First, resize the existing buttons to fit 5 in a row aligned with the 600px text edit. Replace the entire button row (lines 35-42):

```ahk
    g.SetFont("s10 cDDDDDD", "Segoe UI")
    btnSpeak := g.AddButton("xm+10 y+10 w140 h34", "Speak")
    btnSpeak.OnEvent("Click", (*) => TTS_Speak())
    btnPause := g.AddButton("x+6 yp w140 h34", "Pause / Resume")
    btnPause.OnEvent("Click", (*) => TTS_Pause())
    btnStop  := g.AddButton("x+6 yp w140 h34", "Stop")
    btnStop.OnEvent("Click",  (*) => TTS_Stop())
    btnSave  := g.AddButton("x+6 yp w90 h34", "Save WAV")
    btnSave.OnEvent("Click",  (*) => TTS_SaveWAV())
    btnQuick := g.AddButton("x+6 yp w90 h34", "Quick Save")
    btnQuick.OnEvent("Click", (*) => TTS_QuickSave())
```

**Layout math:** `10 + 140 + 6 + 140 + 6 + 140 + 6 + 90 + 6 + 90 = 634px` — aligns with text edit (starts at ~66px, ends at ~666px).

- [ ] **Step 3: Manual test**

1. Run AI-HUB.ahk, go to TTS tab
2. Paste or type text, click "Quick Save"
3. Verify a file like `speech_2026-03-20_143052.wav` appears in Downloads
4. Play the WAV — verify it sounds correct with current voice/speed/pitch settings
5. Verify normalize runs if the checkbox is enabled

- [ ] **Step 4: Commit**

```bash
git add modules/bettertts_tab.ahk
git commit -m "feat: add Quick Save button to TTS tab — auto-saves WAV to Downloads"
```

---

### Task 5: Config Sync Engine (Import on Startup, Export on Close + Periodic)

**Priority: HIGH** — Makes D:\ the source of truth for all config, prevents data loss from reinstalls/resets.

**Files:**
- Create: `modules/config_sync.ahk`
- Modify: `modules/manifest.ahk` (add `#Include` line)
- Modify: `hub_core.ahk` (wire import into boot, export on close + periodic timer)

**Context for implementer:**
- Sync directory: `D:\AI-HUB-SYNC\` (fall back to `C:\AI-HUB-SYNC\` if no D:\)
- Files to sync: `hotkeys.ini`, `hotstrings.sav`, `settings.ini`, `prompts.json`, `storage.json`, `sysprompts.json`, `research_links.json`
- **Import logic (startup):** For each file, if the sync copy exists AND is newer than the local copy (by file timestamp), overwrite local with sync copy
- **Export logic (close + every 30 min):** Copy all local config files to sync directory, overwriting sync copies
- This is separate from Task 1's backup system. Backup = archive snapshots. Sync = live source of truth.
- The `CFG_DIR` global holds the local config path
- The GUI close event is handled in `CreateMainGUI()` line 200: `gShell.gui.OnEvent("Close", (*) => HideGui())`
- Actual exit uses `ExitApp` which fires `OnExit` callbacks

- [ ] **Step 1: Create `modules/config_sync.ahk`**

```ahk
; ============================================================
; Module: Config Sync — import from D:\AI-HUB-SYNC on startup,
;         export on close + every 30 minutes
; ============================================================

global SYNC_DIR := DirExist("D:\") ? "D:\AI-HUB-SYNC" : "C:\AI-HUB-SYNC"

; Files to sync between local config and sync directory
global SYNC_FILES := ["hotkeys.ini", "hotstrings.sav", "settings.ini", "prompts.json",
                      "storage.json", "sysprompts.json", "research_links.json"]

; Import: if sync copy is newer than local, overwrite local
Sync_Import() {
    global CFG_DIR, SYNC_DIR, SYNC_FILES
    if !DirExist(SYNC_DIR)
        return  ; nothing to import from

    for , f in SYNC_FILES {
        syncFile  := SYNC_DIR "\" f
        localFile := CFG_DIR "\" f
        if !FileExist(syncFile)
            continue
        ; If local doesn't exist, always import
        if !FileExist(localFile) {
            try FileCopy(syncFile, localFile, true)
            continue
        }
        ; Compare timestamps — import if sync is newer
        syncTime  := FileGetTime(syncFile, "M")
        localTime := FileGetTime(localFile, "M")
        if (syncTime > localTime)
            try FileCopy(syncFile, localFile, true)
    }
}

; Export: copy all local config files to sync directory
Sync_Export() {
    global CFG_DIR, SYNC_DIR, SYNC_FILES
    if !DirExist(SYNC_DIR)
        DirCreate(SYNC_DIR)

    for , f in SYNC_FILES {
        localFile := CFG_DIR "\" f
        if FileExist(localFile)
            try FileCopy(localFile, SYNC_DIR "\" f, true)
    }
}
```

- [ ] **Step 2: Add include to `modules/manifest.ahk`**

Add alongside the other includes:

```ahk
#Include config_sync.ahk
```

- [ ] **Step 3: Wire import into boot sequence**

In `hub_core.ahk` `Hub_Boot()`, add `Sync_Import()` **before** `Load_All()` but **after** `Hub_RunBackup()` (so backup captures pre-import state):

```ahk
Hub_Boot() {
    EnsureConfig()
    try Hub_RunBackup()
    try Sync_Import()    ; <-- ADD THIS LINE
    Load_All()
    ; ... rest unchanged
}
```

- [ ] **Step 4: Wire export on exit + periodic timer**

In `hub_core.ahk`, add an `OnExit` callback and a periodic timer. Place these at the end of `Hub_Boot()`, after `SetupTray()`:

```ahk
    SetupTray()

    ; Config sync: export on exit + every 30 minutes
    OnExit((*) => Sync_Export())
    SetTimer(() => Sync_Export(), 1800000)  ; 30 min = 1,800,000 ms
}
```

- [ ] **Step 5: Manual test**

1. Run AI-HUB.ahk
2. Check that `D:\AI-HUB-SYNC\` (or `C:\AI-HUB-SYNC\`) was created with config files
3. Modify a local config file (e.g., add a hotkey)
4. Wait 30 minutes OR close the app — verify sync directory is updated
5. Delete a local config file, put a newer copy in sync directory, restart — verify local is restored from sync
6. Verify backup still runs (Task 1) — backup should capture the pre-import state

- [ ] **Step 6: Commit**

```bash
git add modules/config_sync.ahk modules/manifest.ahk hub_core.ahk
git commit -m "feat: config sync engine — import from D:\AI-HUB-SYNC on startup, export on close + every 30min"
```

---

## Implementation Order

1. **Task 1 (Auto-Backup)** — most critical, prevents data loss
2. **Task 5 (Config Sync)** — second most critical, auto-restores wiped configs
3. **Task 2 (Hide from Taskbar)** — quick win, one function + one modification
4. **Task 3 (Dark Mode Fix)** — visual improvement, affects whole GUI
5. **Task 4 (Quick Save Audio)** — convenience, lowest priority

**Note:** Tasks 1 and 5 both modify `Hub_Boot()` in `hub_core.ahk`. Task 5 must be implemented AFTER Task 1 since its insertion point depends on the backup line being present.

## Notes for Implementer

- **No test framework exists for AHK** — all verification is manual (run the app, check visually/functionally)
- **hub_core.ahk is ~2500 lines** — use line numbers from this plan as approximate anchors, search for function names if lines have shifted
- **The `dist/` folder** contains a "friend" distribution copy — do NOT modify those files; they're a separate build artifact
- **Config directory** is `A_ScriptDir "\config"` — that's the source; backup goes to `D:\AI-HUB-BACKUP\`
- **D:\ drive handling** — both backup and sync auto-detect D:\ availability and fall back to C:\ equivalents
- **Research tab categories** — already implemented in `modules/research_links.html` with dynamic tab filtering. The `category` field exists in `research_links.json`. Users just need to add entries with "Research", "Bookmarks", or "Quick Links" as the category value.
