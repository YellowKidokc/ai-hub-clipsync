; ============================================================
; Module: Config Sync — import from D:\AI-HUB-SYNC on startup,
;         export on close + every 30 minutes
; Also syncs clipboard data from clipsync-bridge/data/
; ============================================================

global SYNC_DIR := DirExist("B:\") ? "B:\AI-HUB-SYNC" : (DirExist("D:\") ? "D:\AI-HUB-SYNC" : "C:\AI-HUB-SYNC")

; Config files to sync
global SYNC_FILES := ["hotkeys.ini", "hotstrings.sav", "settings.ini", "prompts.json",
                      "storage.json", "sysprompts.json", "research_links.json"]

; Clipboard data files (in clipsync-bridge/data/)
global SYNC_CLIP_FILES := ["clips.json", "bookmarks.json", "prompts.json"]
global CLIP_DATA_DIR := A_ScriptDir "\..\Data"

; Import: if sync copy is newer than local, overwrite local
Sync_Import() {
    global CFG_DIR, SYNC_DIR, SYNC_FILES, SYNC_CLIP_FILES, CLIP_DATA_DIR
    if !DirExist(SYNC_DIR)
        return  ; nothing to import from

    ; Sync config files
    for , f in SYNC_FILES {
        syncFile  := SYNC_DIR "\" f
        localFile := CFG_DIR "\" f
        if !FileExist(syncFile)
            continue
        if !FileExist(localFile) {
            try FileCopy(syncFile, localFile, true)
            continue
        }
        syncTime  := FileGetTime(syncFile, "M")
        localTime := FileGetTime(localFile, "M")
        if (syncTime > localTime)
            try FileCopy(syncFile, localFile, true)
    }

    ; Sync clipboard data files
    clipSyncDir := SYNC_DIR "\clipdata"
    if !DirExist(clipSyncDir)
        return
    if !DirExist(CLIP_DATA_DIR)
        return

    for , f in SYNC_CLIP_FILES {
        syncFile  := clipSyncDir "\" f
        localFile := CLIP_DATA_DIR "\" f
        if !FileExist(syncFile)
            continue
        if !FileExist(localFile) {
            try FileCopy(syncFile, localFile, true)
            continue
        }
        syncTime  := FileGetTime(syncFile, "M")
        localTime := FileGetTime(localFile, "M")
        if (syncTime > localTime)
            try FileCopy(syncFile, localFile, true)
    }
}

; Export: copy all local config + clipboard data to sync directory
Sync_Export() {
    global CFG_DIR, SYNC_DIR, SYNC_FILES, SYNC_CLIP_FILES, CLIP_DATA_DIR

    if !DirExist(SYNC_DIR)
        DirCreate(SYNC_DIR)

    ; Export config files
    for , f in SYNC_FILES {
        localFile := CFG_DIR "\" f
        if FileExist(localFile)
            try FileCopy(localFile, SYNC_DIR "\" f, true)
    }

    ; Export clipboard data files
    clipSyncDir := SYNC_DIR "\clipdata"
    if !DirExist(clipSyncDir)
        DirCreate(clipSyncDir)

    if DirExist(CLIP_DATA_DIR) {
        for , f in SYNC_CLIP_FILES {
            localFile := CLIP_DATA_DIR "\" f
            if FileExist(localFile)
                try FileCopy(localFile, clipSyncDir "\" f, true)
        }
    }
}
