; ============================================================
; Module: Auto-Backup — copies config + data on every startup
; ============================================================

Hub_RunBackup() {
    global CFG_DIR

    ; Use D:\ if available, fall back to C:\
    backupRoot := DirExist("B:\") ? "B:\AI-HUB-BACKUP" : (DirExist("D:\") ? "D:\AI-HUB-BACKUP" : "C:\AI-HUB-BACKUP")
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

    ; Back up Data folder (clips, prompts, bookmarks JSON) — may not exist on fresh installs
    for , dataDir in [A_ScriptDir "\Data", A_ScriptDir "\clipsync-bridge\data"] {
        if DirExist(dataDir) {
            Loop Files dataDir "\*.*" {
                try FileCopy(A_LoopFileFullPath, latestDir "\Data\" A_LoopFileName, true)
                try FileCopy(A_LoopFileFullPath, dailyDir  "\Data\" A_LoopFileName, true)
            }
        }
    }
}
