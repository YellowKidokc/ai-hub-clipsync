; ============================================================
; Module: Overnight Operations — Ollama Batch Processing
; ============================================================
; Provides a GUI tab for launching overnight Ollama tasks:
;   - YAML Enrichment (full vault or by domain)
;   - Callout Fixer
;   - Citation Checker
;   - Knowledge Graph Refresh
;   - Custom batch scripts
; ============================================================

#Requires AutoHotkey v2.0+

; ---- Register tab ----
if IsSet(HUB_CORE_LOADED)
    RegisterTab("Overnight", Build_OvernightTab, 50)

; ---- Config ----
global OVERNIGHT_PYTHON := "O:\999_IGNORE\Obsidian Programs\Python_Backend"
global OVERNIGHT_SCRIPTS := OVERNIGHT_PYTHON "\scripts"
global OVERNIGHT_VAULT := "O:\_Theophysics_v3\04_THEOPYHISCS"
global OVERNIGHT_LOG := ""
global OVERNIGHT_PID := 0

Build_OvernightTab() {
    global gShell, DARK_TEXT, DARK_BG, DARK_CTRL, INPUT_BG, INPUT_TEXT

    gShell.gui.SetFont("s10 Bold c" DARK_TEXT, "Segoe UI")
    gShell.gui.Add("Text", "xm+15 ym+50", "Overnight Operations")
    gShell.gui.SetFont("s9 c888888", "Segoe UI")
    gShell.gui.Add("Text", "xm+15 y+5", "Launch batch Ollama tasks. Make sure 'ollama serve' is running.")

    ; ---- Status indicator ----
    gShell.gui.SetFont("s9 Bold c" DARK_TEXT, "Segoe UI")
    gShell.overnightStatus := gShell.gui.Add("Text", "xm+15 y+20 w600 c888888", "Status: Idle")

    ; ---- Separator ----
    gShell.gui.Add("Text", "xm+15 y+15 w700 h1 Background333333")

    ; ============================================================
    ; YAML ENRICHMENT SECTION
    ; ============================================================
    gShell.gui.SetFont("s10 Bold cF59E0B", "Segoe UI")
    gShell.gui.Add("Text", "xm+15 y+15", "YAML Enrichment")
    gShell.gui.SetFont("s9 c888888", "Segoe UI")
    gShell.gui.Add("Text", "xm+15 y+5", "Scans papers, generates YAML frontmatter with Ollama. Tags are ADDITIVE ONLY — never removes existing data.")

    ; Model selector
    gShell.gui.SetFont("s9 c" DARK_TEXT, "Segoe UI")
    gShell.gui.Add("Text", "xm+15 y+20", "Model:")
    gShell.overnightModel := gShell.gui.Add("DropDownList", "x+10 w150 Choose1", ["llama3.2", "llama3.1", "mistral", "qwen2.5", "gemma2"])
    ApplyDarkTheme(gShell.overnightModel)

    gShell.gui.Add("Text", "x+20", "Mode:")
    gShell.overnightMode := gShell.gui.Add("DropDownList", "x+10 w180 Choose1", ["All Papers", "Skip Existing YAML", "Dry Run (preview)", "Test (10 files)"])
    ApplyDarkTheme(gShell.overnightMode)

    ; Target folder
    gShell.gui.Add("Text", "xm+15 y+20 c" DARK_TEXT, "Target:")
    gShell.overnightTarget := gShell.gui.Add("DropDownList", "x+10 w350 Choose1", [
        "04_THEOPYHISCS (full)",
        "FORMAL_PAPERS",
        "[TX_A5.1] Cross-Domain",
        "[TX_A5.2] Consciousness",
        "[TX_A5.5] Axiom Foundations",
        "[TX_A6.1] Logos Foundation",
        "[TX_A6.2] Apologetics",
        "[TX_A6.5] JS-Series",
        "[TX_A6.6] THE CONVERGENCE",
        "[TX_A6.8] Moral Decay",
        "[TX_A6.9] Duality Project",
        "[TX_A7.7] Consciousness",
        "[6.6] LOGOS_V3"
    ])
    ApplyDarkTheme(gShell.overnightTarget)

    ; Launch button
    gShell.btnYamlEnrich := gShell.gui.Add("Button", "xm+15 y+20 w180 h35", "▶  Run YAML Enricher")
    gShell.btnYamlEnrich.OnEvent("Click", (*) => LaunchYamlEnricher())
    ApplyDarkTheme(gShell.btnYamlEnrich)

    gShell.btnYamlStop := gShell.gui.Add("Button", "x+10 w120 h35", "⬛  Stop")
    gShell.btnYamlStop.OnEvent("Click", (*) => StopOvernightProcess())
    ApplyDarkTheme(gShell.btnYamlStop)

    gShell.btnOpenReport := gShell.gui.Add("Button", "x+10 w140 h35", "📊  Open Reports")
    gShell.btnOpenReport.OnEvent("Click", (*) => Run("explorer.exe " . Chr(34) . OVERNIGHT_PYTHON . "\reports" . Chr(34)))
    ApplyDarkTheme(gShell.btnOpenReport)

    ; ---- Separator ----
    gShell.gui.Add("Text", "xm+15 y+25 w700 h1 Background333333")

    ; ============================================================
    ; OTHER OVERNIGHT TASKS
    ; ============================================================
    gShell.gui.SetFont("s10 Bold c10B981", "Segoe UI")
    gShell.gui.Add("Text", "xm+15 y+15", "Other Batch Tasks")
    gShell.gui.SetFont("s9 c888888", "Segoe UI")
    gShell.gui.Add("Text", "xm+15 y+5", "Additional overnight operations. Each runs independently.")

    ; Row of task buttons
    gShell.gui.SetFont("s9 Bold c" DARK_TEXT, "Segoe UI")

    gShell.btnKnowledgeGraph := gShell.gui.Add("Button", "xm+15 y+20 w180 h32", "🔗  Knowledge Graph")
    gShell.btnKnowledgeGraph.OnEvent("Click", (*) => LaunchBatchScript("RUN_OVERNIGHT_KNOWLEDGE_GRAPH.bat"))
    ApplyDarkTheme(gShell.btnKnowledgeGraph)

    gShell.btnMathTranslation := gShell.gui.Add("Button", "x+8 w180 h32", "🔢  Math Translation")
    gShell.btnMathTranslation.OnEvent("Click", (*) => LaunchBatchScript("RUN_OVERNIGHT_MATH.bat"))
    ApplyDarkTheme(gShell.btnMathTranslation)

    gShell.btnVaultAnalytics := gShell.gui.Add("Button", "x+8 w180 h32", "📈  Vault Analytics")
    gShell.btnVaultAnalytics.OnEvent("Click", (*) => LaunchBatchScript("RUN_VAULT_ANALYTICS.bat"))
    ApplyDarkTheme(gShell.btnVaultAnalytics)

    gShell.btnTruthEngine := gShell.gui.Add("Button", "xm+15 y+10 w180 h32", "⚖️  Truth Engine")
    gShell.btnTruthEngine.OnEvent("Click", (*) => LaunchBatchScript("RUN_TRUTH_ENGINE.bat"))
    ApplyDarkTheme(gShell.btnTruthEngine)

    gShell.btnAllAnalytics := gShell.gui.Add("Button", "x+8 w180 h32", "🚀  Run ALL Analytics")
    gShell.btnAllAnalytics.OnEvent("Click", (*) => LaunchBatchScript("RUN_ALL_ANALYTICS.bat"))
    ApplyDarkTheme(gShell.btnAllAnalytics)

    gShell.btnBackup := gShell.gui.Add("Button", "x+8 w180 h32", "💾  Backup to Synology")
    gShell.btnBackup.OnEvent("Click", (*) => LaunchBatchScript("BACKUP_TO_SYNOLOGY.bat"))
    ApplyDarkTheme(gShell.btnBackup)

    ; ---- Separator ----
    gShell.gui.Add("Text", "xm+15 y+25 w700 h1 Background333333")

    ; ============================================================
    ; LOG OUTPUT
    ; ============================================================
    gShell.gui.SetFont("s10 Bold c" DARK_TEXT, "Segoe UI")
    gShell.gui.Add("Text", "xm+15 y+15", "Output Log")

    gShell.overnightLog := gShell.gui.Add("Edit", "xm+15 y+8 w700 h200 ReadOnly Multi VScroll", "Ready. Select a task and click Run.")
    ApplyDarkTheme(gShell.overnightLog)
    try gShell.overnightLog.Opt("Background" DARK_CTRL)
    try gShell.overnightLog.SetFont("s8 c" DARK_TEXT, "Consolas")
}

; ============================================================
; YAML ENRICHER LAUNCHER
; ============================================================
LaunchYamlEnricher() {
    global gShell, OVERNIGHT_SCRIPTS, OVERNIGHT_VAULT, OVERNIGHT_PID

    if OVERNIGHT_PID > 0 {
        try {
            if ProcessExist(OVERNIGHT_PID) {
                gShell.overnightStatus.Text := "Status: ⚠️ Already running (PID " OVERNIGHT_PID ")"
                return
            }
        }
    }

    model := gShell.overnightModel.Text
    mode := gShell.overnightMode.Text
    target := gShell.overnightTarget.Text

    ; Map target to folder path
    targetMap := Map()
    targetMap["04_THEOPYHISCS (full)"] := OVERNIGHT_VAULT
    targetMap["FORMAL_PAPERS"] := OVERNIGHT_VAULT "\FORMAL_PAPERS"
    targetMap["[TX_A5.1] Cross-Domain"] := OVERNIGHT_VAULT "\[TX_A5.1] Cross-Domain Coherence Project"
    targetMap["[TX_A5.2] Consciousness"] := OVERNIGHT_VAULT "\[TX_A5.2] Consciousness_System"
    targetMap["[TX_A5.5] Axiom Foundations"] := OVERNIGHT_VAULT "\[TX_A5.5] AXIOM_FOUNDATIONS"
    targetMap["[TX_A6.1] Logos Foundation"] := OVERNIGHT_VAULT "\[TX_A6.1] __LOGOS_FOUNDATION_DONE"
    targetMap["[TX_A6.2] Apologetics"] := OVERNIGHT_VAULT "\[TX_A6.2] 07_Apologetics"
    targetMap["[TX_A6.5] JS-Series"] := OVERNIGHT_VAULT "\[TX_A6.5] JS-SERIES"
    targetMap["[TX_A6.6] THE CONVERGENCE"] := OVERNIGHT_VAULT "\[TX_A6.6] THE CONVERGENCE"
    targetMap["[TX_A6.8] Moral Decay"] := OVERNIGHT_VAULT "\[TX_A6.8] MORAL_DECAY_CLEAN"
    targetMap["[TX_A6.9] Duality Project"] := OVERNIGHT_VAULT "\[TX_A6.9] DUALITY_PROJECT"
    targetMap["[TX_A7.7] Consciousness"] := OVERNIGHT_VAULT "\[TX_A7.7] Consciousness"
    targetMap["[6.6] LOGOS_V3"] := OVERNIGHT_VAULT "\[6.6] LOGOS_V3"

    folder := targetMap.Has(target) ? targetMap[target] : OVERNIGHT_VAULT

    ; Build command args
    args := '--folder "' folder '" --model ' model
    if mode = "Skip Existing YAML"
        args .= " --skip-existing"
    else if mode = "Dry Run (preview)"
        args .= " --dry-run"
    else if mode = "Test (10 files)"
        args .= " --limit 10"

    script := OVERNIGHT_SCRIPTS "\ollama_yaml_enricher_v2.py"
    cmd := 'python "' script '" ' args

    ; Log
    LogOvernight("Starting YAML Enricher...")
    LogOvernight("  Model:  " model)
    LogOvernight("  Target: " target)
    LogOvernight("  Mode:   " mode)
    LogOvernight("  CMD:    " cmd)
    LogOvernight("")

    gShell.overnightStatus.Text := "Status: 🟢 Running YAML Enricher — " target

    ; Launch in background
    try {
        Run(A_ComSpec ' /c cd /d "' OVERNIGHT_SCRIPTS '\.." && ' cmd, , "Hide", &pid)
        OVERNIGHT_PID := pid
        LogOvernight("  Launched PID: " pid)
        LogOvernight("  Running in background. Check reports folder when done.")
        ; Start monitoring for completion
        SetTimer(CheckOvernightComplete.Bind(pid, "YAML Enricher — " target), 30000)
    } catch as e {
        LogOvernight("  ERROR: " e.Message)
        gShell.overnightStatus.Text := "Status: ❌ Failed to launch"
    }
}

; ============================================================
; GENERIC BATCH SCRIPT LAUNCHER
; ============================================================
LaunchBatchScript(batName) {
    global gShell, OVERNIGHT_PYTHON

    batPath := OVERNIGHT_PYTHON "\" batName
    if !FileExist(batPath) {
        LogOvernight("ERROR: Script not found: " batPath)
        return
    }

    LogOvernight("Launching: " batName)
    gShell.overnightStatus.Text := "Status: 🟢 Running " batName

    try {
        Run(batPath, OVERNIGHT_PYTHON, , &pid)
        LogOvernight("  Launched PID: " pid " — " batName)
        ; Start monitoring for completion
        SetTimer(CheckOvernightComplete.Bind(pid, batName), 30000)
    } catch as e {
        LogOvernight("  ERROR: " e.Message)
    }
}

; ============================================================
; STOP PROCESS
; ============================================================
StopOvernightProcess() {
    global gShell, OVERNIGHT_PID

    if OVERNIGHT_PID <= 0 {
        LogOvernight("Nothing to stop.")
        return
    }

    try {
        if ProcessExist(OVERNIGHT_PID) {
            ProcessClose(OVERNIGHT_PID)
            LogOvernight("Stopped PID: " OVERNIGHT_PID)
            gShell.overnightStatus.Text := "Status: ⬛ Stopped"
        } else {
            LogOvernight("Process " OVERNIGHT_PID " already finished.")
        }
    } catch as e {
        LogOvernight("Error stopping: " e.Message)
    }
    OVERNIGHT_PID := 0
}

; ============================================================
; LOG HELPER
; ============================================================
LogOvernight(msg) {
    global gShell
    ts := FormatTime(A_Now, "HH:mm:ss")
    current := gShell.overnightLog.Value
    gShell.overnightLog.Value := current . (current ? "`n" : "") . "[" ts "] " msg
    ; Scroll to bottom
    SendMessage(0x115, 7, 0, gShell.overnightLog.Hwnd)
}

; ============================================================
; COMPLETION MONITOR — Toast notification when tasks finish
; ============================================================
CheckOvernightComplete(pid, taskName, *) {
    global gShell, OVERNIGHT_PID
    if !ProcessExist(pid) {
        ; Process finished — stop checking
        SetTimer(, 0)
        ts := FormatTime(A_Now, "HH:mm:ss")
        LogOvernight("✅ COMPLETED: " taskName " (PID " pid ")")
        gShell.overnightStatus.Text := "Status: ✅ Finished — " taskName

        ; Toast notification
        try TrayTip("Overnight Task Complete", taskName "`nFinished at " ts, "Iconi")

        ; Play system sound
        try SoundPlay("*48")

        ; Clear PID if it was the tracked one
        if OVERNIGHT_PID = pid
            OVERNIGHT_PID := 0
    }
}
