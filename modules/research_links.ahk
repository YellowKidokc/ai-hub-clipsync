; ============================================================
; Module: Research Links — Quick-access URL repository
; ============================================================
; Add to manifest.ahk:  #include .\research_links.ahk
; Links stored in config\research_links.json
; ============================================================

#Requires AutoHotkey v2.0+

; ---- Register tabs (hub mode only) ----
if IsSet(HUB_CORE_LOADED) {
    RegisterTab("Research", Build_ResearchTab, 35)
    RegisterTab("Research Links", Build_LinksTab, 36)
}

; ---- State ----
global gResearchLinks := []
global RESEARCH_FILE := A_ScriptDir "\config\research_links.json"
global BRIDGE_BOOKMARKS_FILE := A_ScriptDir "\clipsync-bridge\data\bookmarks.json"
global gEditingLinkIndex := 0
global gLinkTabContexts := Map()
global gResearchLinksLastStamp := ""
global gResearchLinksWatchStarted := false

; ---- Default categories ----
global RESEARCH_CATEGORIES := [
    "Physics", "Theology", "Consciousness", "Mathematics",
    "AI / ML", "Databases", "Tools", "Journals",
    "Scripture", "Reference", "News", "Other"
]

Build_ResearchTab() {
    Build_LinkLibraryTab("research", "Research", "Research Library")
}

Build_LinksTab() {
    Build_LinkLibraryTab("links", "Research Links", "Research Links")
}

Build_LinkLibraryTab(tabKey, headerText, libraryTitle) {
    global gShell, DARK_TEXT, DARK_BG, DARK_CTRL, gResearchLinks, RESEARCH_CATEGORIES, gLinkTabContexts

    gShell.gui.SetFont("s10 Bold c" DARK_TEXT, "Segoe UI")
    ctx := Map()

    ; --- LEFT: Add/Edit ---
    gShell.gui.Add("Text", "xm+15 ym+45", "Add " headerText " Entry")
    gShell.gui.SetFont("s9 Bold c" DARK_TEXT, "Segoe UI")

    gShell.gui.Add("Text", "xm+15 y+20 c" DARK_TEXT, "Category:")
    ctx["catDDL"] := gShell.gui.Add("DropDownList", "x+10 w150 Choose1", RESEARCH_CATEGORIES)
    ApplyDarkTheme(ctx["catDDL"])
    ApplyInputTheme(ctx["catDDL"])

    gShell.gui.Add("Text", "xm+15 y+12 c" DARK_TEXT, "Name:")
    ctx["nameEdit"] := gShell.gui.Add("Edit", "x+40 w280", "")
    ApplyDarkTheme(ctx["nameEdit"])
    ApplyInputTheme(ctx["nameEdit"])

    gShell.gui.Add("Text", "xm+15 y+12 c" DARK_TEXT, "URL:")
    ctx["urlEdit"] := gShell.gui.Add("Edit", "x+50 w280", "")
    ApplyDarkTheme(ctx["urlEdit"])
    ApplyInputTheme(ctx["urlEdit"])

    gShell.gui.Add("Text", "xm+15 y+12 c" DARK_TEXT, "Notes:")
    ctx["notesEdit"] := gShell.gui.Add("Edit", "x+35 w280 r2", "")
    ApplyDarkTheme(ctx["notesEdit"])
    ApplyInputTheme(ctx["notesEdit"])

    gShell.gui.Add("Text", "xm+15 y+12 c" DARK_TEXT, "Tags:")
    ctx["tagsEdit"] := gShell.gui.Add("Edit", "x+42 w280", "")
    ApplyDarkTheme(ctx["tagsEdit"])
    ApplyInputTheme(ctx["tagsEdit"])
    gShell.gui.Add("Text", "x+5 c888888", "(comma-separated)")

    ctx["btnSave"] := gShell.gui.Add("Button", "xm+15 y+20 w90", "Add/Save")
    ctx["btnSave"].OnEvent("Click", (*) => SaveResearchLink(tabKey))
    ApplyDarkTheme(ctx["btnSave"])

    ctx["btnNew"] := gShell.gui.Add("Button", "x+8 w70", "New")
    ctx["btnNew"].OnEvent("Click", (*) => ClearLinkEditor(tabKey))
    ApplyDarkTheme(ctx["btnNew"])

    ctx["btnDelete"] := gShell.gui.Add("Button", "x+8 w70", "Delete")
    ctx["btnDelete"].OnEvent("Click", (*) => DeleteResearchLink(tabKey))
    ApplyDarkTheme(ctx["btnDelete"])

    ctx["btnOpen"] := gShell.gui.Add("Button", "x+8 w80", "Open URL")
    ctx["btnOpen"].OnEvent("Click", (*) => OpenSelectedLink(tabKey))
    ApplyDarkTheme(ctx["btnOpen"])

    ctx["statusTxt"] := gShell.gui.Add("Text", "xm+15 y+15 w390 c888888", "")

    gShell.gui.Add("Text", "xm+15 y+20 w400 h1 Background333333")
    gShell.gui.SetFont("s9 c888888", "Segoe UI")
    gShell.gui.Add("Text", "xm+15 y+10", "Paste URL from clipboard:")
    ctx["btnQuickAdd"] := gShell.gui.Add("Button", "x+10 w100", "Paste + Add")
    ctx["btnQuickAdd"].OnEvent("Click", (*) => QuickAddLink(tabKey))
    ApplyDarkTheme(ctx["btnQuickAdd"])
    gShell.gui.SetFont("s9 Bold c" DARK_TEXT, "Segoe UI")

    ; --- RIGHT: Library ---
    gShell.gui.Add("Text", "x460 ym+45 c" DARK_TEXT, libraryTitle)

    gShell.gui.Add("Text", "x460 y+10 c888888", "Filter:")
    filterCats := ["All"]
    for cat in RESEARCH_CATEGORIES
        filterCats.Push(cat)
    ctx["filterDDL"] := gShell.gui.Add("DropDownList", "x+5 w120 Choose1", filterCats)
    ctx["filterDDL"].OnEvent("Change", (*) => RefreshLinksLV(tabKey))
    ApplyDarkTheme(ctx["filterDDL"])
    ApplyInputTheme(ctx["filterDDL"])

    ctx["searchEdit"] := gShell.gui.Add("Edit", "x+10 w150", "")
    ctx["searchEdit"].OnEvent("Change", (*) => RefreshLinksLV(tabKey))
    ApplyDarkTheme(ctx["searchEdit"])
    ApplyInputTheme(ctx["searchEdit"])
    gShell.gui.Add("Text", "x+5 c888888", "Search")

    ctx["linksLV"] := gShell.gui.Add("ListView", "x460 y+10 w590 h380 -Multi +Grid VScroll",
        ["Category", "Name", "URL", "Notes", "Tags"])
    ctx["linksLV"].OnEvent("Click", (lv, row) => LinkLV_OnClick(tabKey, lv, row))
    ctx["linksLV"].OnEvent("DoubleClick", (lv, row) => LinkLV_OnDoubleClick(tabKey, lv, row))
    ApplyDarkListView(ctx["linksLV"])

    gShell.gui.Add("Text", "x460 y+8 c888888", "Double-click to open in browser  |  Click to edit")

    ctx["editingIndex"] := 0
    gLinkTabContexts[tabKey] := ctx
    LoadResearchLinks()
    RefreshLinksLV(tabKey)
    StartResearchLinksWatcher()
}

SaveResearchLink(tabKey, *) {
    global gResearchLinks
    ctx := GetLinkTabContext(tabKey)
    name := Trim(ctx["nameEdit"].Value)
    url := Trim(ctx["urlEdit"].Value)
    cat := ctx["catDDL"].Text
    notes := ctx["notesEdit"].Value
    tags := ctx["tagsEdit"].Value

    if name = "" || url = "" {
        ctx["statusTxt"].Text := "Name and URL required"
        return
    }
    if !RegExMatch(url, "^https?://")
        url := "https://" url

    link := {
        category: cat,
        name: name,
        url: url,
        notes: notes,
        tags: tags,
        added: FormatTime(A_Now, "yyyy-MM-dd HH:mm")
    }

    if ctx["editingIndex"] > 0 {
        gResearchLinks[ctx["editingIndex"]] := link
        ctx["editingIndex"] := 0
    } else {
        gResearchLinks.Push(link)
    }

    PersistResearchLinks()
    RefreshAllLinkTabs()
    ClearLinkEditor(tabKey)
    ctx["statusTxt"].Text := "Saved: " name
    SetTimer(() => (ctx["statusTxt"].Text := ""), -2000)
}

DeleteResearchLink(tabKey, *) {
    global gResearchLinks
    ctx := GetLinkTabContext(tabKey)
    row := ctx["linksLV"].GetNext()
    if row <= 0 {
        ctx["statusTxt"].Text := "Select a link to delete"
        return
    }
    idx := GetFilteredLinkIndex(tabKey, row)
    if idx <= 0
        return
    if MsgBox("Delete this link?", "Confirm", "YesNo Icon!") = "Yes" {
        gResearchLinks.RemoveAt(idx)
        ctx["editingIndex"] := 0
        PersistResearchLinks()
        RefreshAllLinkTabs()
        ClearLinkEditor(tabKey)
        ctx["statusTxt"].Text := "Deleted"
    }
}

OpenSelectedLink(tabKey, *) {
    global gResearchLinks
    ctx := GetLinkTabContext(tabKey)
    row := ctx["linksLV"].GetNext()
    if row <= 0
        return
    idx := GetFilteredLinkIndex(tabKey, row)
    if idx > 0
        Run(gResearchLinks[idx].url)
}

ClearLinkEditor(tabKey, *) {
    ctx := GetLinkTabContext(tabKey)
    ctx["editingIndex"] := 0
    ctx["nameEdit"].Value := ""
    ctx["urlEdit"].Value := ""
    ctx["notesEdit"].Value := ""
    ctx["tagsEdit"].Value := ""
}

QuickAddLink(tabKey, *) {
    ctx := GetLinkTabContext(tabKey)
    url := Trim(A_Clipboard)
    if !RegExMatch(url, "^https?://") {
        ctx["statusTxt"].Text := "Clipboard doesn't look like a URL"
        SetTimer(() => (ctx["statusTxt"].Text := ""), -2000)
        return
    }
    ctx["urlEdit"].Value := url
    if RegExMatch(url, "https?://(?:www\.)?([^/]+)", &m)
        ctx["nameEdit"].Value := m[1]
    ctx["nameEdit"].Focus()
    ctx["statusTxt"].Text := "URL pasted — add a name and save"
}

LinkLV_OnClick(tabKey, lv, row) {
    global gResearchLinks
    ctx := GetLinkTabContext(tabKey)
    if row <= 0
        return
    idx := GetFilteredLinkIndex(tabKey, row)
    if idx <= 0
        return
    link := gResearchLinks[idx]
    ctx["editingIndex"] := idx
    ctx["catDDL"].Text := link.category
    ctx["nameEdit"].Value := link.name
    ctx["urlEdit"].Value := link.url
    ctx["notesEdit"].Value := link.HasProp("notes") ? link.notes : ""
    ctx["tagsEdit"].Value := link.HasProp("tags") ? link.tags : ""
}

LinkLV_OnDoubleClick(tabKey, lv, row) {
    global gResearchLinks
    if row <= 0
        return
    idx := GetFilteredLinkIndex(tabKey, row)
    if idx > 0
        Run(gResearchLinks[idx].url)
}

GetFilteredLinkIndex(tabKey, filteredRow) {
    global gResearchLinks
    ctx := GetLinkTabContext(tabKey)
    filterCat := ctx["filterDDL"].Text
    searchTerm := ctx["searchEdit"].Value
    count := 0
    for i, link in gResearchLinks {
        if filterCat != "All" && link.category != filterCat
            continue
        if searchTerm != "" {
            haystack := link.name " " link.url " " (link.HasProp("notes") ? link.notes : "") " " (link.HasProp("tags") ? link.tags : "")
            if !InStr(haystack, searchTerm)
                continue
        }
        count++
        if count = filteredRow
            return i
    }
    return 0
}

RefreshLinksLV(tabKey, *) {
    global gResearchLinks
    ctx := GetLinkTabContext(tabKey)
    ctx["linksLV"].Delete()
    filterCat := ctx["filterDDL"].Text
    searchTerm := ctx["searchEdit"].Value
    for link in gResearchLinks {
        if filterCat != "All" && link.category != filterCat
            continue
        if searchTerm != "" {
            haystack := link.name " " link.url " " (link.HasProp("notes") ? link.notes : "") " " (link.HasProp("tags") ? link.tags : "")
            if !InStr(haystack, searchTerm)
                continue
        }
        urlPreview := StrLen(link.url) > 40 ? SubStr(link.url, 1, 40) "..." : link.url
        notes := link.HasProp("notes") ? link.notes : ""
        notesPreview := StrLen(notes) > 25 ? SubStr(notes, 1, 25) "..." : notes
        tags := link.HasProp("tags") ? link.tags : ""
        ctx["linksLV"].Add("", link.category, link.name, urlPreview, notesPreview, tags)
    }
    ctx["linksLV"].ModifyCol(1, 80)
    ctx["linksLV"].ModifyCol(2, 140)
    ctx["linksLV"].ModifyCol(3, 180)
    ctx["linksLV"].ModifyCol(4, 100)
    ctx["linksLV"].ModifyCol(5, 80)
}

RefreshAllLinkTabs() {
    global gLinkTabContexts
    for tabKey, _ in gLinkTabContexts
        RefreshLinksLV(tabKey)
}

GetLinkTabContext(tabKey) {
    global gLinkTabContexts
    return gLinkTabContexts[tabKey]
}

LoadResearchLinks() {
    global gResearchLinks, RESEARCH_FILE, gResearchLinksLastStamp
    gResearchLinks := []
    if !FileExist(RESEARCH_FILE)
        return
    try {
        gResearchLinksLastStamp := FileGetTime(RESEARCH_FILE, "M")
        raw := FileRead(RESEARCH_FILE, "UTF-8")
        if raw = "" || raw = "[]"
            return
        pattern := '\{"category":"((?:[^"\\]|\\.)*)\".*?"name":"((?:[^"\\]|\\.)*)\".*?"url":"((?:[^"\\]|\\.)*)"'
        pos := 1
        while RegExMatch(raw, pattern, &m, pos) {
            objStart := m.Pos
            objEnd := InStr(raw, "}", , objStart)
            objStr := SubStr(raw, objStart, objEnd - objStart + 1)
            notes := ""
            if RegExMatch(objStr, '"notes"\s*:\s*"((?:[^"\\]|\\.)*)"', &nm)
                notes := UnescapeJSON(nm[1])
            tags := ""
            if RegExMatch(objStr, '"tags"\s*:\s*"((?:[^"\\]|\\.)*)"', &tm)
                tags := UnescapeJSON(tm[1])
            added := ""
            if RegExMatch(objStr, '"added"\s*:\s*"([^"]*)"', &am)
                added := am[1]
            gResearchLinks.Push({
                category: UnescapeJSON(m[1]),
                name: UnescapeJSON(m[2]),
                url: UnescapeJSON(m[3]),
                notes: notes,
                tags: tags,
                added: added
            })
            pos := objEnd + 1
        }
    }
}

PersistResearchLinks() {
    global gResearchLinks, RESEARCH_FILE, BRIDGE_BOOKMARKS_FILE, gResearchLinksLastStamp
    jsonStr := "["
    for i, link in gResearchLinks {
        jsonStr .= "`n  {"
        jsonStr .= '"category":"' EscapeJSON(link.category) '", '
        jsonStr .= '"name":"' EscapeJSON(link.name) '", '
        jsonStr .= '"url":"' EscapeJSON(link.url) '", '
        jsonStr .= '"notes":"' EscapeJSON(link.HasProp("notes") ? link.notes : "") '", '
        jsonStr .= '"tags":"' EscapeJSON(link.HasProp("tags") ? link.tags : "") '", '
        jsonStr .= '"added":"' (link.HasProp("added") ? link.added : "") '"'
        jsonStr .= "}" (i < gResearchLinks.Length ? "," : "")
    }
    jsonStr .= "`n]"
    try FileDelete(RESEARCH_FILE)
    FileAppend(jsonStr, RESEARCH_FILE, "UTF-8")
    try gResearchLinksLastStamp := FileGetTime(RESEARCH_FILE, "M")

    bridgeJson := "["
    for i, link in gResearchLinks {
        tagsValue := link.HasProp("tags") ? link.tags : ""
        tagsJson := "[]"
        if tagsValue != "" {
            tagsJson := "["
            tagParts := StrSplit(tagsValue, ",")
            addedTag := 0
            for _, tag in tagParts {
                cleanTag := Trim(tag)
                if cleanTag = ""
                    continue
                tagsJson .= (addedTag > 0 ? "," : "") '"' EscapeJSON(cleanTag) '"'
                addedTag += 1
            }
            tagsJson .= "]"
        }

        bridgeJson .= "`n  {"
        bridgeJson .= '"id":"b' SubStr(Format("{:08X}", Abs(Crc32(link.url link.name))), 1, 8) '", '
        bridgeJson .= '"title":"' EscapeJSON(link.name) '", '
        bridgeJson .= '"url":"' EscapeJSON(link.url) '", '
        bridgeJson .= '"category":"' EscapeJSON(link.category) '", '
        bridgeJson .= '"tags":' tagsJson ', '
        bridgeJson .= '"created_at":"' EscapeJSON(link.HasProp("added") ? link.added : "") '"'
        bridgeJson .= "}" (i < gResearchLinks.Length ? "," : "")
    }
    bridgeJson .= "`n]"
    try FileDelete(BRIDGE_BOOKMARKS_FILE)
    FileAppend(bridgeJson, BRIDGE_BOOKMARKS_FILE, "UTF-8")
}

StartResearchLinksWatcher() {
    global gResearchLinksWatchStarted
    if gResearchLinksWatchStarted
        return
    gResearchLinksWatchStarted := true
    SetTimer(WatchResearchLinksFile, 3000)
}

WatchResearchLinksFile() {
    global RESEARCH_FILE, gResearchLinksLastStamp, gLinkTabContexts
    if !FileExist(RESEARCH_FILE)
        return
    currentStamp := FileGetTime(RESEARCH_FILE, "M")
    if currentStamp = gResearchLinksLastStamp
        return
    LoadResearchLinks()
    if gLinkTabContexts.Count > 0
        RefreshAllLinkTabs()
}

Crc32(str) {
    static table := 0
    if !IsObject(table) {
        table := []
        loop 256 {
            crc := A_Index - 1
            loop 8
                crc := (crc & 1) ? (0xEDB88320 ^ (crc >> 1)) : (crc >> 1)
            table.Push(crc)
        }
    }

    crc := 0xFFFFFFFF
    loop parse str
        crc := table[((crc ^ Ord(A_LoopField)) & 0xFF) + 1] ^ (crc >> 8)
    return ~crc
}
