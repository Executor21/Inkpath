/*
Script: Inkpath
Συγγραφέας: Tasos
Έτος: 2025
MIT License
Copyright (c) 2025 Tasos
*/

#Requires AutoHotkey v2.0.11
#SingleInstance Force

; ═══════════════════════════════════════════════════════════════════════════
; GLOBAL STATE
; ═══════════════════════════════════════════════════════════════════════════

global Nodes := []
global NodeMap := Map()  ; O(1) lookup by ID
global NextID := 1
global SelectedNodeID := 0
global Categories := Map("Default", [])
global CurrentCategory := "Default"
global UndoStack := []
global RedoStack := []
global ClipboardNode := ""
global TypewriterSpeed := 50
global PlayHistory := []
global NodeListPage := 1
global NodesPerPage := 50
global APP_VERSION := "1.0.0"
global LOG_FILE := A_ScriptDir . "\Inkpath_Log.txt"
global AUTOSAVE_FILE := A_Temp . "\Inkpath_Autosave.sav"
global MAX_UNDO_STACK := 50
global MAX_DEPTH_LIMIT := 1000

; ═══════════════════════════════════════════════════════════════════════════
; STARTUP & RECOVERY
; ═══════════════════════════════════════════════════════════════════════════

TraySetIcon("Shell32.dll", 44)
LogInfo("Application started - Version " . APP_VERSION)

; Register cleanup on exit
OnExit(CleanupOnExit)

; ═══════════════════════════════════════════════════════════════════════════
; MAIN GUI CONSTRUCTION
; ═══════════════════════════════════════════════════════════════════════════

MyGui := Gui("-Resize +MaximizeBox +MinimizeBox", "Inkpath v" . APP_VERSION)
MyGui.SetFont("s10", "Segoe UI")
MyGui.BackColor := "0x2b2b2b"
MyGui.OnEvent("Close", (*) => ExitApp())

; ───────────────────────────────────────────────────────────────────────────
; LEFT PANEL (380px) - Categories & Node Management
; ───────────────────────────────────────────────────────────────────────────

MyGui.SetFont("s9 bold")
MyGui.Add("Text", "x10 y10 w150 cWhite", "📁 Categories")
MyGui.SetFont("s9")
categoryDDL := MyGui.Add("DropDownList", "x10 y30 w220 vCategory Background0x1e1e1e cWhite Choose1", ["Default"])
addCatBtn := MyGui.Add("Button", "x235 y30 w50 h23", "➕")
delCatBtn := MyGui.Add("Button", "x290 y30 w50 h23", "➖")

MyGui.Add("Text", "x10 y60 w100 cWhite", "🔍 Search:")
searchBox := MyGui.Add("Edit", "x10 y80 w330 vSearch Background0x1e1e1e cWhite")

MyGui.SetFont("s9")
MyGui.Add("Text", "x10 y110 w200 cWhite", "Story Nodes:")
pageInfoTxt := MyGui.Add("Text", "x220 y110 w120 cYellow Right", "Page 1/1")
nodeLb := MyGui.Add("ListBox", "x10 y130 w330 h400 vNodeList Background0x1e1e1e cWhite")

prevPageBtn := MyGui.Add("Button", "x10 y535 w160 h30", "◀ Previous")
nextPageBtn := MyGui.Add("Button", "x180 y535 w160 h30", "Next ▶")

delNodeBtn := MyGui.Add("Button", "x10 y570 w105 h30", "🗑️ Delete")
copyNodeBtn := MyGui.Add("Button", "x120 y570 w105 h30", "📋 Copy")
pasteNodeBtn := MyGui.Add("Button", "x230 y570 w110 h30", "📄 Paste")

undoBtn := MyGui.Add("Button", "x10 y605 w160 h30", "↶ Undo")
redoBtn := MyGui.Add("Button", "x180 y605 w160 h30", "↷ Redo")

templateBtn := MyGui.Add("Button", "x10 y645 w105 h30", "📝 Template")
graphBtn := MyGui.Add("Button", "x120 y645 w105 h30", "🗺️ Graph")
validateBtn := MyGui.Add("Button", "x230 y645 w110 h30", "✓ Validate")

; ───────────────────────────────────────────────────────────────────────────
; MIDDLE PANEL (500px) - Node Editor
; ───────────────────────────────────────────────────────────────────────────

MyGui.SetFont("s10")
MyGui.Add("Text", "x360 y10 cWhite", "Node Name:")
nameEdit := MyGui.Add("Edit", "x360 y30 w405 vName Background0x1e1e1e cWhite")
addNodeBtn := MyGui.Add("Button", "x770 y30 w90 h23", "➕ Add")

MyGui.Add("Text", "x360 y65 cWhite", "🖼️ Image Path:")
imgEdit := MyGui.Add("Edit", "x360 y85 w405 vImage Background0x1e1e1e cWhite +ReadOnly")
browseImgBtn := MyGui.Add("Button", "x770 y85 w90 h23", "Browse")

MyGui.Add("Text", "x360 y120 cWhite", "🔊 Audio Path:")
audioEdit := MyGui.Add("Edit", "x360 y140 w405 vAudio Background0x1e1e1e cWhite +ReadOnly")
browseAudioBtn := MyGui.Add("Button", "x770 y140 w90 h23", "Browse")

MyGui.Add("Text", "x360 y175 cWhite", "Scene Text:")
textEdit := MyGui.Add("Edit", "x360 y195 w500 h200 vText Multi Background0x1e1e1e cWhite")

MyGui.Add("Text", "x360 y405 cWhite", "Choices:")
choicesList := MyGui.Add("ListBox", "x360 y425 w500 h120 vChoices Background0x1e1e1e cWhite")

choiceText := MyGui.Add("Edit", "x360 y555 w230 vChoiceText Background0x1e1e1e cWhite")
choiceTarget := MyGui.Add("ComboBox", "x595 y555 w180 vChoiceTarget Background0x1e1e1e cWhite")
addChoiceBtn := MyGui.Add("Button", "x780 y555 w80 h25", "Add ➕")
delChoiceBtn := MyGui.Add("Button", "x780 y585 w80 h25", "Delete 🗑️")

; ───────────────────────────────────────────────────────────────────────────
; RIGHT PANEL (350px) - Preview & Controls
; ───────────────────────────────────────────────────────────────────────────

MyGui.Add("Text", "x880 y10 cWhite", "Preview:")
previewPic := MyGui.Add("Picture", "x880 y30 w430 h240 vPreviewPic Background0x1e1e1e Border")

MyGui.Add("Text", "x880 y280 cWhite", "⚙️ Typewriter Speed:")
speedSlider := MyGui.Add("Slider", "x880 y300 w430 h30 vSpeed Range20-200 TickInterval20 ToolTip", TypewriterSpeed)
speedText := MyGui.Add("Text", "x880 y335 w430 cYellow Center", TypewriterSpeed . " ms/char")

MyGui.Add("Text", "x880 y365 cWhite", "📊 Statistics:")
statsText := MyGui.Add("Text", "x880 y385 w430 h120 vStats c00FFFF", "")

playBtn := MyGui.Add("Button", "x880 y515 w430 h40", "▶️ Play Story")
saveBtn := MyGui.Add("Button", "x880 y565 w210 h35", "💾 Save")
loadBtn := MyGui.Add("Button", "x1100 y565 w210 h35", "📂 Load")

statusTxt := MyGui.Add("Text", "x880 y610 w430 h65 vStatus cYellow", "Ready. Add a node to begin.")

; ═══════════════════════════════════════════════════════════════════════════
; EVENT BINDINGS
; ═══════════════════════════════════════════════════════════════════════════

addNodeBtn.OnEvent("Click", (*) => AddNode())
delNodeBtn.OnEvent("Click", (*) => DeleteNode())
copyNodeBtn.OnEvent("Click", (*) => CopyNode())
pasteNodeBtn.OnEvent("Click", (*) => PasteNode())
templateBtn.OnEvent("Click", (*) => ShowTemplates())
graphBtn.OnEvent("Click", (*) => ShowGraph())
browseImgBtn.OnEvent("Click", (*) => BrowseImage())
browseAudioBtn.OnEvent("Click", (*) => BrowseAudio())
addChoiceBtn.OnEvent("Click", (*) => AddChoice())
delChoiceBtn.OnEvent("Click", (*) => DeleteChoice())
playBtn.OnEvent("Click", (*) => PlayStory())
saveBtn.OnEvent("Click", (*) => SaveStory())
loadBtn.OnEvent("Click", (*) => LoadStory())
validateBtn.OnEvent("Click", (*) => ValidateStory())
undoBtn.OnEvent("Click", (*) => Undo())
redoBtn.OnEvent("Click", (*) => Redo())
addCatBtn.OnEvent("Click", (*) => AddCategory())
delCatBtn.OnEvent("Click", (*) => DeleteCategory())
nodeLb.OnEvent("Change", (*) => OnNodeSelected())
searchBox.OnEvent("Change", (*) => FilterNodes())
categoryDDL.OnEvent("Change", (*) => SwitchCategory())
nameEdit.OnEvent("Change", (*) => UpdateNodeName())
imgEdit.OnEvent("Change", (*) => UpdateNodeImage())
audioEdit.OnEvent("Change", (*) => UpdateNodeAudio())
textEdit.OnEvent("Change", (*) => UpdateNodeText())
speedSlider.OnEvent("Change", (*) => UpdateSpeed())
prevPageBtn.OnEvent("Click", (*) => PreviousPage())
nextPageBtn.OnEvent("Click", (*) => NextPage())

; ═══════════════════════════════════════════════════════════════════════════
; SHOW GUI & INITIALIZE
; ═══════════════════════════════════════════════════════════════════════════

MyGui.Show("w1320 h690")

; Check for crash recovery AFTER GUI is created
if FileExist(AUTOSAVE_FILE) {
    try {
        result := MsgBox("Found autosave file from previous session.`n`nRestore?", "Crash Recovery", "YesNo Icon?")
        if (result = "Yes") {
            LoadStoryFromFile(AUTOSAVE_FILE)
            LogInfo("Restored from autosave")
        } else {
            FileDelete(AUTOSAVE_FILE)
            LogInfo("Autosave ignored by user")
        }
    } catch as e {
        LogError("Recovery failed: " . e.Message)
    }
}

; Initialize UI
UpdateNodeList()
UpdateStatistics()

; Auto-save every 2 minutes
SetTimer(AutoSave, 120000)

return

; ═══════════════════════════════════════════════════════════════════════════
; CLEANUP ON EXIT
; ═══════════════════════════════════════════════════════════════════════════

CleanupOnExit(*) {
    try {
        ; Clean up temporary graph files
        Loop Files, A_Temp . "\Inkpath_graph_*.html" {
            try FileDelete(A_LoopFileFullPath)
        }
        
        ; Clean up old temp files (older than 24 hours)
        Loop Files, A_Temp . "\Inkpath_*.tmp" {
            if (DateDiff(A_Now, FileGetTime(A_LoopFileFullPath), "Hours") > 24) {
                try FileDelete(A_LoopFileFullPath)
            }
        }
        
        LogInfo("Application closed - Cleanup completed")
    } catch as e {
        LogError("Cleanup failed: " . e.Message)
    }
}

; ═══════════════════════════════════════════════════════════════════════════
; CORE NODE OPERATIONS
; ═══════════════════════════════════════════════════════════════════════════

AddNode(*) {
    global NextID, Nodes, NodeMap, CurrentCategory, Categories
    
    try {
        SaveState()
        
        id := NextID++
        node := Map(
            "id", id,
            "name", "Node " . id,
            "image", "",
            "audio", "",
            "text", "",
            "choices", [],
            "category", CurrentCategory
        )
        
        Nodes.Push(node)
        NodeMap[id] := node
        
        if (!Categories.Has(CurrentCategory))
            Categories[CurrentCategory] := []
        Categories[CurrentCategory].Push(id)
        
        UpdateNodeList()
        SelectNodeByID(id)
        UpdateStatistics()
        Status("✓ Node " . id . " created")
        LogInfo("Node " . id . " created in category " . CurrentCategory)
    } catch as e {
        LogError("AddNode failed: " . e.Message)
        Status("❌ Failed to create node")
    }
}

DeleteNode(*) {
    global Nodes, NodeMap, SelectedNodeID, Categories
    
    sel := nodeLb.Text
    if (!sel) {
        Status("⚠️ Select a node to delete")
        return
    }
    
    try {
        if (!RegExMatch(sel, "\((\d+)\)$", &m)) {
            Status("❌ Cannot parse node ID")
            return
        }
        
        id := Integer(m[1])
        
        result := MsgBox("Delete node " . id . "?`n`nThis will remove all choices pointing to it.", "Confirm Delete", "YesNo Icon!")
        if (result = "No")
            return
        
        SaveState()
        
        ; Remove from category
        for cat, arr in Categories {
            newArr := []
            for nid in arr {
                if (nid != id)
                    newArr.Push(nid)
            }
            Categories[cat] := newArr
        }
        
        ; Remove from node list and map
        newNodes := []
        for node in Nodes {
            if (node["id"] != id)
                newNodes.Push(node)
        }
        Nodes := newNodes
        NodeMap.Delete(id)
        
        ; Remove broken choices
        for node in Nodes {
            newChoices := []
            for ch in node["choices"] {
                if (ch["target"] != id)
                    newChoices.Push(ch)
            }
            node["choices"] := newChoices
        }
        
        if (SelectedNodeID = id)
            SelectedNodeID := 0
        
        UpdateNodeList()
        ClearEditor()
        UpdateStatistics()
        Status("✓ Node " . id . " deleted")
        LogInfo("Node " . id . " deleted")
    } catch as e {
        LogError("DeleteNode failed: " . e.Message)
        Status("❌ Delete failed")
    }
}

CopyNode(*) {
    global SelectedNodeID, ClipboardNode
    
    if (!SelectedNodeID) {
        Status("⚠️ Select a node to copy")
        return
    }
    
    try {
        n := FindNodeByID(SelectedNodeID)
        if (!n) {
            Status("❌ Node not found")
            return
        }
        
        ClipboardNode := Map(
            "name", n["name"],
            "image", n["image"],
            "audio", n["audio"],
            "text", n["text"],
            "choices", []
        )
        
        for ch in n["choices"] {
            ClipboardNode["choices"].Push(Map("text", ch["text"], "target", ch["target"]))
        }
        
        Status("✓ Node copied")
        LogInfo("Node " . SelectedNodeID . " copied")
    } catch as e {
        LogError("CopyNode failed: " . e.Message)
        Status("❌ Copy failed")
    }
}

PasteNode(*) {
    global ClipboardNode, NextID, Nodes, NodeMap, CurrentCategory, Categories
    
    if (!ClipboardNode) {
        Status("⚠️ Clipboard is empty")
        return
    }
    
    try {
        SaveState()
        
        id := NextID++
        node := Map(
            "id", id,
            "name", ClipboardNode["name"] . " (Copy)",
            "image", ClipboardNode["image"],
            "audio", ClipboardNode["audio"],
            "text", ClipboardNode["text"],
            "choices", [],
            "category", CurrentCategory
        )
        
        ; Validate and copy choices - only include valid targets
        invalidChoices := 0
        for ch in ClipboardNode["choices"] {
            if (NodeMap.Has(ch["target"])) {
                node["choices"].Push(Map("text", ch["text"], "target", ch["target"]))
            } else {
                invalidChoices++
            }
        }
        
        Nodes.Push(node)
        NodeMap[id] := node
        
        if (!Categories.Has(CurrentCategory))
            Categories[CurrentCategory] := []
        Categories[CurrentCategory].Push(id)
        
        UpdateNodeList()
        SelectNodeByID(id)
        UpdateStatistics()
        
        if (invalidChoices > 0) {
            Status("✓ Node pasted with ID " . id . " (" . invalidChoices . " invalid choices removed)")
            LogInfo("Node pasted with ID " . id . " - " . invalidChoices . " invalid choices removed")
        } else {
            Status("✓ Node pasted with ID " . id)
            LogInfo("Node pasted with ID " . id)
        }
    } catch as e {
        LogError("PasteNode failed: " . e.Message)
        Status("❌ Paste failed")
    }
}

; ═══════════════════════════════════════════════════════════════════════════
; TEMPLATES
; ═══════════════════════════════════════════════════════════════════════════

ShowTemplates(*) {
    try {
        TemplateGui := Gui("+Owner" . MyGui.Hwnd, "Story Templates")
        TemplateGui.SetFont("s10", "Segoe UI")
        TemplateGui.BackColor := "0x2b2b2b"
        
        TemplateGui.Add("Text", "x10 y10 w380 cWhite", "Choose a template:")
        
        templates := [
            "Opening Scene - Introduce setting",
            "Choice Point - Critical decision",
            "Combat Scene - Action sequence",
            "Dialogue Scene - Character interaction",
            "Ending Scene - Story conclusion"
        ]
        
        templateLB := TemplateGui.Add("ListBox", "x10 y40 w380 h200 Background0x1e1e1e cWhite", templates)
        
        ApplyTemplateHandler(*) {
            sel := templateLB.Value
            if (sel) {
                ApplyTemplate(sel)
                TemplateGui.Destroy()
            }
        }
        
        applyBtn := TemplateGui.Add("Button", "x10 y250 w380 h35", "Apply Template")
        applyBtn.OnEvent("Click", ApplyTemplateHandler)
        
        TemplateGui.Show("w400 h300")
    } catch as e {
        LogError("ShowTemplates failed: " . e.Message)
        Status("❌ Templates failed")
    }
}

ApplyTemplate(index) {
    global SelectedNodeID
    
    if (!SelectedNodeID) {
        Status("⚠️ Select a node first")
        return
    }
    
    try {
        n := FindNodeByID(SelectedNodeID)
        if (!n)
            return
        
        SaveState()
        
        switch index {
            case 1:
                n["name"] := "Opening Scene"
                n["text"] := "The story begins here. Describe the setting, atmosphere, and introduce your protagonist."
            case 2:
                n["name"] := "Choice Point"
                n["text"] := "A critical moment arrives. What will you do?"
            case 3:
                n["name"] := "Combat Scene"
                n["text"] := "Danger! Describe the threat and the action that unfolds."
            case 4:
                n["name"] := "Dialogue Scene"
                n["text"] := "Characters speak. What important information or emotion is conveyed?"
            case 5:
                n["name"] := "Ending Scene"
                n["text"] := "The story concludes. How does everything resolve?"
        }
        
        SelectNodeByID(SelectedNodeID)
        Status("✓ Template applied")
        LogInfo("Template " . index . " applied to node " . SelectedNodeID)
    } catch as e {
        LogError("ApplyTemplate failed: " . e.Message)
        Status("❌ Template failed")
    }
}

; ═══════════════════════════════════════════════════════════════════════════
; VISUAL GRAPH
; ═══════════════════════════════════════════════════════════════════════════

ShowGraph(*) {
    global Nodes
    
    if (Nodes.Length = 0) {
        Status("⚠️ No nodes to display")
        return
    }
    
    try {
        html := "<!DOCTYPE html><html><head>"
        html .= "<meta charset='UTF-8'>"
        html .= "<script src='https://cdnjs.cloudflare.com/ajax/libs/vis-network/9.1.2/dist/vis-network.min.js'></script>"
        html .= "<style>body{margin:0;padding:0;background:#1e1e1e;}#network{width:100%;height:100vh;}</style>"
        html .= "</head><body><div id='network'></div><script>"
        html .= "var nodes=new vis.DataSet(["
        
        for node in Nodes {
            ; Proper JavaScript string escaping
            escapedName := EscapeJS(node["name"])
            html .= "{id:" . node["id"] . ",label:'" . escapedName . "',color:{background:'#3a7ca5',border:'#2c5f8d'}},"
        }
        
        html .= "]);var edges=new vis.DataSet(["
        
        for node in Nodes {
            for ch in node["choices"] {
                html .= "{from:" . node["id"] . ",to:" . ch["target"] . ",arrows:'to'},"
            }
        }
        
        html .= "]);"
        html .= "var container=document.getElementById('network');"
        html .= "var data={nodes:nodes,edges:edges};"
        html .= "var options={nodes:{shape:'box',font:{color:'#fff',size:14}},edges:{color:{color:'#666'},width:2},physics:{enabled:true}};"
        html .= "new vis.Network(container,data,options);"
        html .= "</script></body></html>"
        
        tempFile := A_Temp . "\Inkpath_graph_" . A_TickCount . ".html"
        
        if FileExist(tempFile)
            FileDelete(tempFile)
        
        FileAppend(html, tempFile, "UTF-8")
        Run(tempFile)
        Status("✓ Graph opened")
        LogInfo("Graph opened")
    } catch as e {
        LogError("ShowGraph failed: " . e.Message)
        Status("❌ Graph failed: " . e.Message)
    }
}

; ═══════════════════════════════════════════════════════════════════════════
; VALIDATION
; ═══════════════════════════════════════════════════════════════════════════

ValidateStory(*) {
    global Nodes
    
    if (Nodes.Length = 0) {
        MsgBox("⚠️ No nodes to validate.", "Validation", "Iconi")
        return
    }
    
    try {
        issues := []
        
        ; Dead ends
        for node in Nodes {
            if (node["choices"].Length = 0) {
                issues.Push("⚠️ Node " . node["id"] . " (" . node["name"] . ") has no choices")
            }
        }
        
        ; Broken links
        for node in Nodes {
            for ch in node["choices"] {
                if (!NodeMap.Has(ch["target"])) {
                    issues.Push("❌ Node " . node["id"] . " has broken link to node " . ch["target"])
                }
            }
        }
        
        ; Enhanced circular loop detection (full graph traversal)
        circularLoops := DetectAllCircularLoops()
        for loopPath in circularLoops {
            issues.Push("🔄 Circular loop: " . loopPath)
        }
        
        ; Unreachable nodes
        if (Nodes.Length > 0) {
            reachable := Map()
            MarkReachable(Nodes[1]["id"], reachable)
            
            for node in Nodes {
                if (!reachable.Has(node["id"])) {
                    issues.Push("🔒 Node " . node["id"] . " (" . node["name"] . ") is unreachable")
                }
            }
        }
        
        ; Empty text warnings
        for node in Nodes {
            if (!Trim(node["text"])) {
                issues.Push("📝 Node " . node["id"] . " has empty text")
            }
        }
        
        if (issues.Length = 0) {
            MsgBox("✅ Validation passed!`n`nNo issues found.", "Success", "Iconi")
            Status("✓ Validation passed")
            LogInfo("Validation passed - no issues")
        } else {
            msg := "Found " . issues.Length . " issue(s):`n`n"
            count := 0
            for issue in issues {
                count++
                msg .= issue . "`n"
                ; Limit display to first 20 issues
                if (count >= 20 && issues.Length > 20) {
                    msg .= "`n... and " . (issues.Length - 20) . " more issues"
                    break
                }
            }
            MsgBox(msg, "Validation Issues", "Icon!")
            Status("⚠️ Found " . issues.Length . " issues")
            LogInfo("Validation found " . issues.Length . " issues")
        }
    } catch as e {
        LogError("ValidateStory failed: " . e.Message)
        Status("❌ Validation failed")
        MsgBox("Validation error: " . e.Message, "Error", "IconX")
    }
}

DetectAllCircularLoops() {
    global Nodes
    loops := []
    visited := Map()
    recStack := Map()
    
    for node in Nodes {
        if (!visited.Has(node["id"])) {
            path := []
            if (DFSCycleDetect(node["id"], visited, recStack, &path)) {
                loops.Push(JoinArray(path, "→"))
            }
        }
    }
    
    return loops
}

DFSCycleDetect(id, visited, recStack, &path) {
    visited[id] := true
    recStack[id] := true
    path.Push(id)
    
    n := FindNodeByID(id)
    if (n) {
        for ch in n["choices"] {
            target := ch["target"]
            
            if (!visited.Has(target)) {
                if (DFSCycleDetect(target, visited, recStack, &path))
                    return true
            } else if (recStack.Has(target) && recStack[target]) {
                path.Push(target)
                return true
            }
        }
    }
    
    path.Pop()
    recStack[id] := false
    return false
}

MarkReachable(id, reachable, depth := 0) {
    global MAX_DEPTH_LIMIT
    
    if (depth > MAX_DEPTH_LIMIT) {
        LogError("Max depth exceeded at node " . id)
        return
    }
    
    if (reachable.Has(id))
        return
    
    reachable[id] := true
    n := FindNodeByID(id)
    if (!n)
        return
    
    for ch in n["choices"] {
        MarkReachable(ch["target"], reachable, depth + 1)
    }
}

; ═══════════════════════════════════════════════════════════════════════════
; FILE OPERATIONS
; ═══════════════════════════════════════════════════════════════════════════

BrowseImage(*) {
    try {
        file := FileSelect(3, "", "Select Image", "Images (*.png; *.jpg; *.jpeg; *.bmp; *.gif)")
        if (file) {
            imgEdit.Value := file
            UpdateNodeImage()
        }
    } catch as e {
        LogError("BrowseImage failed: " . e.Message)
    }
}

BrowseAudio(*) {
    try {
        file := FileSelect(3, "", "Select Audio", "Audio (*.mp3; *.wav; *.ogg)")
        if (file) {
            audioEdit.Value := file
            UpdateNodeAudio()
        }
    } catch as e {
        LogError("BrowseAudio failed: " . e.Message)
    }
}

SaveStory(*) {
    try {
        file := FileSelect("S", "", "Save Story", "Inkpath Files (*.swp)")
        if (!file)
            return
        
        if (!InStr(file, "."))
            file .= ".swp"
        
        SaveStoryToFile(file)
        Status("✓ Saved to " . file)
        LogInfo("Story saved to " . file)
    } catch as e {
        LogError("SaveStory failed: " . e.Message)
        Status("❌ Save failed: " . e.Message)
        MsgBox("Save failed: " . e.Message, "Error", "IconX")
    }
}

SaveStoryToFile(file) {
    global Nodes, Categories, APP_VERSION
    
    content := "Inkpath`n"
    content .= "VERSION=" . APP_VERSION . "`n"
    content .= "TIMESTAMP=" . A_Now . "`n"
    
    ; Categories
    content .= "---CATEGORIES---`n"
    for cat, arr in Categories {
        ids := JoinArray(arr, ",")
        content .= cat . "=" . ids . "`n"
    }
    
    ; Nodes
    for node in Nodes {
        textEsc := StrReplace(node["text"], "`n", "<NL>")
        textEsc := StrReplace(textEsc, "`r", "")
        
        choicesArr := []
        for ch in node["choices"] {
            ; Escape delimiters
            chText := StrReplace(ch["text"], "|", "<PIPE>")
            chText := StrReplace(chText, "::", "<COLON>")
            choicesArr.Push(chText . "::" . ch["target"])
        }
        choicesStr := JoinArray(choicesArr, "|")
        
        content .= "---NODE---`n"
        content .= "ID=" . node["id"] . "`n"
        content .= "Name=" . node["name"] . "`n"
        content .= "Image=" . node["image"] . "`n"
        content .= "Audio=" . node["audio"] . "`n"
        content .= "Text=" . textEsc . "`n"
        content .= "Category=" . node["category"] . "`n"
        content .= "Choices=" . choicesStr . "`n"
    }
    
    ; Atomic save - write to temp first
    tempFile := file . ".tmp"
    
    try {
        if FileExist(tempFile)
            FileDelete(tempFile)
        FileAppend(content, tempFile, "UTF-8")
        
        ; Backup existing file
        if FileExist(file) {
            backupFile := file . ".backup"
            if FileExist(backupFile)
                FileDelete(backupFile)
            FileMove(file, backupFile)
        }
        
        ; Move temp to final
        FileMove(tempFile, file)
    } catch as e {
        if FileExist(tempFile)
            FileDelete(tempFile)
        throw e
    }
}

LoadStory(*) {
    try {
        file := FileSelect(3, "", "Load Story", "Inkpath Files (*.swp)")
        if (!file)
            return
        
        ; Check file size for large file warning
        fileSize := FileGetSize(file)
        if (fileSize > 5000000) { ; 5MB
            result := MsgBox("Large file detected (" . Round(fileSize/1024/1024, 1) . " MB).`n`nLoading may take a moment. Continue?", "Large File", "YesNo Icon!")
            if (result = "No")
                return
        }
        
        LoadStoryFromFile(file)
        Status("✓ Loaded from " . file)
        LogInfo("Story loaded from " . file)
    } catch as e {
        LogError("LoadStory failed: " . e.Message)
        Status("❌ Load failed: " . e.Message)
        MsgBox("Load failed: " . e.Message, "Error", "IconX")
    }
}

LoadStoryFromFile(file) {
    global Nodes, NodeMap, NextID, Categories, CurrentCategory
    
    raw := FileRead(file, "UTF-8")
    
    Nodes := []
    NodeMap := Map()
    NextID := 1
    Categories := Map()
    
    if (InStr(raw, "Inkpath")) {
        ; V2 format
        parts := StrSplit(raw, "---NODE---")
        
        ; Parse categories
        if (InStr(raw, "---CATEGORIES---")) {
            catSection := StrSplit(raw, "---CATEGORIES---")[2]
            catSection := StrSplit(catSection, "---NODE---")[1]
            
            for line in StrSplit(catSection, "`n") {
                line := Trim(line)
                if (!line || !InStr(line, "=") || InStr(line, "VERSION=") || InStr(line, "TIMESTAMP="))
                    continue
                
                p := StrSplit(line, "=", , 2)
                catName := p[1]
                idsStr := p[2]
                
                Categories[catName] := []
                if (idsStr) {
                    for idStr in StrSplit(idsStr, ",") {
                        if (Trim(idStr))
                            Categories[catName].Push(Integer(idStr))
                    }
                }
            }
        }
        
        if (!Categories.Has("Default"))
            Categories["Default"] := []
        
        ; Parse nodes
        for part in parts {
            part := Trim(part)
            If (!part)
    Continue
firstLine := StrSplit(part, "`n")[1]
If (InStr(firstLine, "Inkpath") || InStr(firstLine, "VERSION=") || InStr(firstLine, "TIMESTAMP="))
    Continue
            
            node := ParseNode(part)
            if (node && node["id"] > 0) {
                Nodes.Push(node)
                NodeMap[node["id"]] := node
                if (node["id"] >= NextID)
                    NextID := node["id"] + 1
            }
        }
    } else {
        ; Legacy format
        parts := StrSplit(raw, "---NODE---")
        Categories := Map("Default", [])
        
        for part in parts {
            part := Trim(part)
            if (!part)
                continue
            
            node := ParseNode(part)
            if (node && node["id"] > 0) {
                node["category"] := "Default"
                Nodes.Push(node)
                NodeMap[node["id"]] := node
                Categories["Default"].Push(node["id"])
                if (node["id"] >= NextID)
                    NextID := node["id"] + 1
            }
        }
    }
    
    CurrentCategory := "Default"
    UpdateCategoryList()
    UpdateNodeList()
    ClearEditor()
    UpdateStatistics()
}

ParseNode(text) {
    node := Map(
        "id", 0,
        "name", "",
        "image", "",
        "audio", "",
        "text", "",
        "category", "Default",
        "choices", []
    )
    
    for line in StrSplit(text, "`n") {
        line := Trim(line)
        if (!line)
            continue
        
        if (SubStr(line, 1, 3) = "ID=") {
            node["id"] := Integer(SubStr(line, 4))
        } else if (SubStr(line, 1, 5) = "Name=") {
            node["name"] := SubStr(line, 6)
        } else if (SubStr(line, 1, 6) = "Image=") {
            node["image"] := SubStr(line, 7)
        } else if (SubStr(line, 1, 6) = "Audio=") {
            node["audio"] := SubStr(line, 7)
        } else if (SubStr(line, 1, 5) = "Text=") {
            node["text"] := StrReplace(SubStr(line, 6), "<NL>", "`n")
        } else if (SubStr(line, 1, 9) = "Category=") {
            node["category"] := SubStr(line, 10)
        } else if (SubStr(line, 1, 8) = "Choices=") {
            cs := SubStr(line, 9)
            if (cs) {
                for partChoice in StrSplit(cs, "|") {
                    if (InStr(partChoice, "::")) {
                        p := StrSplit(partChoice, "::", , 2)
                        chText := StrReplace(p[1], "<PIPE>", "|")
                        chText := StrReplace(chText, "<COLON>", "::")
                        node["choices"].Push(Map("text", chText, "target", Integer(p[2])))
                    }
                }
            }
        }
    }
    
    return node
}

AutoSave(*) {
    global Nodes, AUTOSAVE_FILE
    
    if (Nodes.Length = 0)
        return
    
    try {
        SaveStoryToFile(AUTOSAVE_FILE)
        LogInfo("Auto-save completed")
    } catch as e {
        LogError("Auto-save failed: " . e.Message)
    }
}

; ═══════════════════════════════════════════════════════════════════════════
; CHOICES MANAGEMENT
; ═══════════════════════════════════════════════════════════════════════════

AddChoice(*) {
    global SelectedNodeID, NodeMap
    
    txt := Trim(choiceText.Value)
    tgt := choiceTarget.Text
    
    if (!txt || !tgt) {
        Status("⚠️ Enter choice text and target")
        return
    }
    
    try {
        if (!RegExMatch(tgt, "\((\d+)\)$", &m)) {
            Status("❌ Invalid target")
            return
        }
        
        targetID := Integer(m[1])
        
        ; Validate that target node exists
        if (!NodeMap.Has(targetID)) {
            Status("❌ Target node does not exist")
            MsgBox("Target node " . targetID . " does not exist!`n`nPlease select a valid target.", "Invalid Target", "IconX")
            return
        }
        
        if (!SelectedNodeID) {
            Status("⚠️ Select a node first")
            return
        }
        
        SaveState()
        
        n := FindNodeByID(SelectedNodeID)
        if (!n)
            return
        
        n["choices"].Push(Map("text", txt, "target", targetID))
        UpdateChoicesList(n)
        choiceText.Value := ""
        UpdateStatistics()
        Status("✓ Choice added")
        LogInfo("Choice added to node " . SelectedNodeID . " -> " . targetID)
    } catch as e {
        LogError("AddChoice failed: " . e.Message)
        Status("❌ Failed to add choice")
    }
}

DeleteChoice(*) {
    global SelectedNodeID
    
    sel := choicesList.Text
    if (!sel) {
        Status("⚠️ Select a choice to delete")
        return
    }
    
    try {
        SaveState()
        
        n := FindNodeByID(SelectedNodeID)
        if (!n)
            return
        
        if (RegExMatch(sel, "\((\d+)\)$", &m)) {
            targetID := Integer(m[1])
            
            newChoices := []
            removed := false
            for ch in n["choices"] {
                if (!removed && ch["target"] = targetID && InStr(sel, ch["text"])) {
                    removed := true
                    continue
                }
                newChoices.Push(ch)
            }
            n["choices"] := newChoices
            UpdateChoicesList(n)
            UpdateStatistics()
            Status("✓ Choice deleted")
            LogInfo("Choice deleted from node " . SelectedNodeID)
        }
    } catch as e {
        LogError("DeleteChoice failed: " . e.Message)
        Status("❌ Failed to delete choice")
    }
}

; ═══════════════════════════════════════════════════════════════════════════
; CATEGORY MANAGEMENT
; ═══════════════════════════════════════════════════════════════════════════

AddCategory(*) {
    try {
        IB := InputBox("Enter new category name:", "New Category")
        if (IB.Result = "Cancel")
            return
        
        catName := Trim(IB.Value)
        if (!catName) {
            Status("⚠️ Category name cannot be empty")
            return
        }
        
        if (Categories.Has(catName)) {
            Status("⚠️ Category already exists")
            return
        }
        
        Categories[catName] := []
        UpdateCategoryList()
        Status("✓ Category '" . catName . "' created")
        LogInfo("Category created: " . catName)
    } catch as e {
        LogError("AddCategory failed: " . e.Message)
        Status("❌ Failed to create category")
    }
}

DeleteCategory(*) {
    global CurrentCategory, Categories
    
    if (CurrentCategory = "Default") {
        Status("⚠️ Cannot delete Default category")
        return
    }
    
    try {
        result := MsgBox("Delete category '" . CurrentCategory . "'?`n`nNodes will move to Default.", "Confirm", "YesNo Icon!")
        if (result = "No")
            return
        
        if (Categories.Has(CurrentCategory)) {
            for id in Categories[CurrentCategory] {
                n := FindNodeByID(id)
                if (n)
                    n["category"] := "Default"
                Categories["Default"].Push(id)
            }
        }
        
        Categories.Delete(CurrentCategory)
        CurrentCategory := "Default"
        UpdateCategoryList()
        UpdateNodeList()
        Status("✓ Category deleted")
        LogInfo("Category deleted")
    } catch as e {
        LogError("DeleteCategory failed: " . e.Message)
        Status("❌ Failed to delete category")
    }
}

SwitchCategory(*) {
    global CurrentCategory, NodeListPage
    try {
        CurrentCategory := categoryDDL.Text
        NodeListPage := 1
        UpdateNodeList()
        Status("✓ Switched to " . CurrentCategory)
    } catch as e {
        LogError("SwitchCategory failed: " . e.Message)
    }
}

; ═══════════════════════════════════════════════════════════════════════════
; PAGINATION & FILTERING
; ═══════════════════════════════════════════════════════════════════════════

FilterNodes(*) {
    global NodeListPage
    NodeListPage := 1
    UpdateNodeList()
}

PreviousPage(*) {
    global NodeListPage
    if (NodeListPage > 1) {
        NodeListPage--
        UpdateNodeList()
    }
}

NextPage(*) {
    global NodeListPage
    NodeListPage++
    UpdateNodeList()
}

; ═══════════════════════════════════════════════════════════════════════════
; UNDO/REDO
; ═══════════════════════════════════════════════════════════════════════════

SaveState() {
    global Nodes, NodeMap, UndoStack, RedoStack, MAX_UNDO_STACK
    
    try {
        state := Map("nodes", [], "nodeMap", Map())
        
        for node in Nodes {
            nodeClone := CloneNode(node)
            state["nodes"].Push(nodeClone)
            state["nodeMap"][nodeClone["id"]] := nodeClone
        }
        
        UndoStack.Push(state)
        
        if (UndoStack.Length > MAX_UNDO_STACK)
            UndoStack.RemoveAt(1)
        
        RedoStack := []
    } catch as e {
        LogError("SaveState failed: " . e.Message)
    }
}

Undo(*) {
    global Nodes, NodeMap, UndoStack, RedoStack
    
    if (UndoStack.Length = 0) {
        Status("⚠️ Nothing to undo")
        return
    }
    
    try {
        ; Save current to redo
        currentState := Map("nodes", [], "nodeMap", Map())
        for node in Nodes {
            nodeClone := CloneNode(node)
            currentState["nodes"].Push(nodeClone)
            currentState["nodeMap"][nodeClone["id"]] := nodeClone
        }
        RedoStack.Push(currentState)
        
        ; Restore previous
        prevState := UndoStack.Pop()
        Nodes := prevState["nodes"]
        NodeMap := prevState["nodeMap"]
        
        UpdateNodeList()
        ClearEditor()
        UpdateStatistics()
        Status("✓ Undo successful")
        LogInfo("Undo performed")
    } catch as e {
        LogError("Undo failed: " . e.Message)
        Status("❌ Undo failed")
    }
}

Redo(*) {
    global Nodes, NodeMap, RedoStack, UndoStack
    
    if (RedoStack.Length = 0) {
        Status("⚠️ Nothing to redo")
        return
    }
    
    try {
        ; Save current to undo
        currentState := Map("nodes", [], "nodeMap", Map())
        for node in Nodes {
            nodeClone := CloneNode(node)
            currentState["nodes"].Push(nodeClone)
            currentState["nodeMap"][nodeClone["id"]] := nodeClone
        }
        UndoStack.Push(currentState)
        
        ; Restore redo
        redoState := RedoStack.Pop()
        Nodes := redoState["nodes"]
        NodeMap := redoState["nodeMap"]
        
        UpdateNodeList()
        ClearEditor()
        UpdateStatistics()
        Status("✓ Redo successful")
        LogInfo("Redo performed")
    } catch as e {
        LogError("Redo failed: " . e.Message)
        Status("❌ Redo failed")
    }
}

CloneNode(node) {
    clone := Map(
        "id", node["id"],
        "name", node["name"],
        "image", node["image"],
        "audio", node["audio"],
        "text", node["text"],
        "category", node["category"],
        "choices", []
    )
    
    for ch in node["choices"] {
        clone["choices"].Push(Map("text", ch["text"], "target", ch["target"]))
    }
    
    return clone
}

; ═══════════════════════════════════════════════════════════════════════════
; PLAY STORY
; ═══════════════════════════════════════════════════════════════════════════

PlayStory(*) {
    global SelectedNodeID, PlayHistory
    
    if (!SelectedNodeID) {
        Status("⚠️ Select a starting node")
        return
    }
    
    try {
        PlayHistory := []
        PlayWindow(SelectedNodeID)
        LogInfo("Play started from node " . SelectedNodeID)
    } catch as e {
        LogError("PlayStory failed: " . e.Message)
        Status("❌ Play failed")
    }
}

PlayWindow(startID) {
    global TypewriterSpeed, PlayHistory
    
    ; Local state for this play session
    buttons := []
    currentAudio := ""
    isTyping := false
    skipTyping := false
    currentTimer := ""
    isMuted := false
    visitedNodes := Map()
    loopWarningShown := false
    isDestroyed := false
    
    PlayGui := Gui("+Resize", "Story Play - Press SPACE to skip")
    PlayGui.SetFont("s11", "Segoe UI")
    PlayGui.BackColor := "0x2b2b2b"
    
    pic := PlayGui.Add("Picture", "x140 y10 w600 h399 vPlayPic Background0x1e1e1e Border")
    txt := PlayGui.Add("Edit", "x10 y419 w880 h251 vPlayText ReadOnly Multi Background0x1e1e1e cWhite")
    
    backBtn := PlayGui.Add("Button", "x900 y10 w200 h35 Disabled vBackBtn", "⬅️ Back")
    muteBtn := PlayGui.Add("Button", "x1110 y10 w200 h35 vMuteBtn", "🔊 Mute")
    saveProgBtn := PlayGui.Add("Button", "x900 y55 w200 h35", "💾 Save Progress")
    loadProgBtn := PlayGui.Add("Button", "x1110 y55 w200 h35", "📂 Load Progress")
    stopPlayBtn := PlayGui.Add("Button", "x900 y100 w410 h35 Background0xCC0000 cWhite", "⏹️ Stop")
    
    btnY := 180
    
    ; Cleanup function
    Cleanup() {
        isDestroyed := true
        
        try {
            SoundPlay("")
        }
        
        if (currentTimer) {
            try SetTimer(currentTimer, 0)
            currentTimer := ""
        }
        
        ; Disable Space hotkey
        try {
            HotIfWinactive("ahk_id " . PlayGui.Hwnd)
            Hotkey("Space", "Off")
            HotIf()
        }
    }
    
    ; Close handler
    ClosePlayWindow(*) {
        Cleanup()
        try {
            PlayGui.Destroy()
        }
        LogInfo("Play window closed")
    }
    PlayGui.OnEvent("Close", ClosePlayWindow)
    PlayGui.OnEvent("Escape", ClosePlayWindow)
    
    ; Mute toggle
    ToggleMute(*) {
        isMuted := !isMuted
        if (isMuted) {
            try SoundPlay("")
            currentAudio := ""
            muteBtn.Text := "🔇 Unmute"
        } else {
            muteBtn.Text := "🔊 Mute"
        }
    }
    muteBtn.OnEvent("Click", ToggleMute)
    
    ; Stop button
    StopPlay(*) {
        Cleanup()
        PlayGui.Destroy()
    }
    stopPlayBtn.OnEvent("Click", StopPlay)
    
    ; Typewriter effect
    TypewriterEffect(text, control) {
        if (isDestroyed)
            return
        
        if (currentTimer) {
            try SetTimer(currentTimer, 0)
            currentTimer := ""
        }
        
        try {
            control.Value := ""
        } catch {
            return
        }
        
        skipTyping := false
        isTyping := true
        
        textLen := StrLen(text)
        currentPos := 0
        
        TypewriterTimer() {
            if (isDestroyed) {
                SetTimer(, 0)
                currentTimer := ""
                return
            }
            
            if (skipTyping || currentPos >= textLen) {
                try {
                    if (!isDestroyed)
                        control.Value := text
                }
                isTyping := false
                SetTimer(, 0)
                currentTimer := ""
                return
            }
            
            currentPos++
            try {
                control.Value := SubStr(text, 1, currentPos)
            } catch {
                SetTimer(, 0)
                currentTimer := ""
            }
        }
        
        currentTimer := TypewriterTimer
        SetTimer(TypewriterTimer, TypewriterSpeed)
    }
    
    ; Space key handler - use Hotkey instead of polling
    SpaceHandler(*) {
        if (!isDestroyed && isTyping) {
            skipTyping := true
        }
    }
    
    ; Register Space hotkey for this window
    HotIfWinactive("ahk_id " . PlayGui.Hwnd)
    Hotkey("Space", SpaceHandler, "On")
    HotIf()
    
    ; Play audio
    PlayAudio(audioPath) {
        if (!audioPath || !FileExist(audioPath) || isMuted)
            return
        
        try {
            if (currentAudio)
                SoundPlay("")
            Sleep(100)
            SoundPlay(audioPath)
            currentAudio := audioPath
        } catch as e {
            LogError("PlayAudio failed: " . e.Message)
        }
    }
    
    ; Render node
    RenderNode(id) {
        if (isDestroyed)
            return
        
        n := FindNodeByID(id)
        if (!n) {
            MsgBox("❌ Node " . id . " not found!", "Error", "IconX")
            return
        }
        
        ; Loop detection
        if (visitedNodes.Has(id)) {
            visitCount := visitedNodes[id]
            visitedNodes[id] := visitCount + 1
            
            if (visitCount >= 3 && !loopWarningShown) {
                result := MsgBox("⚠️ Possible infinite loop!`n`nYou've visited node " . id . " " . (visitCount + 1) . " times.`n`nContinue?", "Warning", "YesNo Icon!")
                loopWarningShown := true
                if (result = "No")
                    return
            }
        } else {
            visitedNodes[id] := 1
        }
        
        ; Cleanup old state
        if (currentTimer) {
            SetTimer(currentTimer, 0)
            currentTimer := ""
        }
        skipTyping := true
        isTyping := false
        
        try {
            SoundPlay("")
        }
        currentAudio := ""
        
        ; History
        PlayHistory.Push(id)
        backBtn.Enabled := (PlayHistory.Length > 1)
        
        ; Clear old buttons
        for btn in buttons {
            try {
                btn.Visible := false
                btn.Destroy()
            }
        }
        buttons := []
        
        ; Update image
        try {
            pic.Value := ""
        }
        Sleep(30)
        
        if (n["image"] && FileExist(n["image"])) {
            try {
                pic.Value := "*w600 *h399 " . n["image"]
            } catch as e {
                LogError("Image load failed: " . e.Message)
            }
        }
        
        Sleep(100)
        
        ; Play audio
        if (n["audio"] && FileExist(n["audio"]) && !isMuted) {
            PlayAudio(n["audio"])
        }
        
        ; Typewriter
        TypewriterEffect(n["text"], txt)
        
        Sleep(30)
        
        ; Create choice buttons with proper closure
        y := btnY
        for ch in n["choices"] {
            CreateChoiceButton(ch["text"], ch["target"], y)
            y += 45
        }
    }
    
    ; Helper function to create button with proper closure
    CreateChoiceButton(btnText, targetID, yPos) {
        if (isDestroyed)
            return
        
        try {
            btn := PlayGui.Add("Button", "x900 y" . yPos . " w410 h40 Background0x3a3a3a cWhite", btnText)
            btn.OnEvent("Click", (*) => RenderNode(targetID))
            buttons.Push(btn)
        } catch as e {
            LogError("CreateChoiceButton failed: " . e.Message)
        }
    }
    
    ; Back button
    GoBack(*) {
        if (PlayHistory.Length > 1) {
            PlayHistory.Pop()
            prevID := PlayHistory.Pop()
            RenderNode(prevID)
        }
    }
    backBtn.OnEvent("Click", GoBack)
    
    ; Save progress
    SaveProgressDialog(*) {
        try {
            file := FileSelect("S", "", "Save Progress", "Progress Files (*.sav)")
            if (!file)
                return
            
            if (!InStr(file, "."))
                file .= ".sav"
            
            currentNode := PlayHistory.Length > 0 ? PlayHistory[PlayHistory.Length] : startID
            content := "NodeID=" . currentNode . "`n"
            content .= "History=" . JoinArray(PlayHistory, ",") . "`n"
            
            tempFile := file . ".tmp"
            if FileExist(tempFile)
                FileDelete(tempFile)
            FileAppend(content, tempFile, "UTF-8")
            
            if FileExist(file)
                FileDelete(file)
            FileMove(tempFile, file)
            
            MsgBox("✓ Progress saved!", "Success", "Iconi")
        } catch as e {
            LogError("Save progress failed: " . e.Message)
            MsgBox("❌ Save failed: " . e.Message, "Error", "IconX")
        }
    }
    saveProgBtn.OnEvent("Click", SaveProgressDialog)
    
    ; Load progress
    LoadProgressDialog(*) {
        try {
            file := FileSelect(3, "", "Load Progress", "Progress Files (*.sav)")
            if (!file)
                return
            
            raw := FileRead(file, "UTF-8")
            nodeID := 0
            history := []
            
            for line in StrSplit(raw, "`n") {
                line := Trim(line)
                if (SubStr(line, 1, 7) = "NodeID=") {
                    nodeID := Integer(SubStr(line, 8))
                } else if (SubStr(line, 1, 8) = "History=") {
                    histStr := SubStr(line, 9)
                    if (histStr) {
                        for idStr in StrSplit(histStr, ",") {
                            if (Trim(idStr))
                                history.Push(Integer(idStr))
                        }
                    }
                }
            }
            
            if (nodeID > 0) {
                PlayHistory := history
                RenderNode(nodeID)
                MsgBox("✓ Progress loaded!", "Success", "Iconi")
            }
        } catch as e {
            LogError("Load progress failed: " . e.Message)
            MsgBox("❌ Load failed: " . e.Message, "Error", "IconX")
        }
    }
    loadProgBtn.OnEvent("Click", LoadProgressDialog)
    
    RenderNode(startID)
    PlayGui.Show("w1320 h690")
}

; ═══════════════════════════════════════════════════════════════════════════
; UI UPDATE FUNCTIONS
; ═══════════════════════════════════════════════════════════════════════════

OnNodeSelected(*) {
    try {
        sel := nodeLb.Text
        if (!sel)
            return
        
        if (RegExMatch(sel, "\((\d+)\)$", &m)) {
            id := Integer(m[1])
            SelectNodeByID(id)
        }
    } catch as e {
        LogError("OnNodeSelected failed: " . e.Message)
    }
}

UpdateNodeName(*) {
    global SelectedNodeID
    if (!SelectedNodeID)
        return
    try {
        n := FindNodeByID(SelectedNodeID)
        if (n) {
            n["name"] := nameEdit.Value
            UpdateNodeList()
        }
    } catch as e {
        LogError("UpdateNodeName failed: " . e.Message)
    }
}

UpdateNodeImage(*) {
    global SelectedNodeID
    if (!SelectedNodeID)
        return
    try {
        n := FindNodeByID(SelectedNodeID)
        if (n) {
            n["image"] := imgEdit.Value
            UpdatePreview(n["image"])
        }
    } catch as e {
        LogError("UpdateNodeImage failed: " . e.Message)
    }
}

UpdateNodeAudio(*) {
    global SelectedNodeID
    if (!SelectedNodeID)
        return
    try {
        n := FindNodeByID(SelectedNodeID)
        if (n)
            n["audio"] := audioEdit.Value
    } catch as e {
        LogError("UpdateNodeAudio failed: " . e.Message)
    }
}

UpdateNodeText(*) {
    global SelectedNodeID
    if (!SelectedNodeID)
        return
    try {
        n := FindNodeByID(SelectedNodeID)
        if (n)
            n["text"] := textEdit.Value
    } catch as e {
        LogError("UpdateNodeText failed: " . e.Message)
    }
}

UpdateSpeed(*) {
    global TypewriterSpeed
    try {
        TypewriterSpeed := speedSlider.Value
        speedText.Value := TypewriterSpeed . " ms/char"
    } catch as e {
        LogError("UpdateSpeed failed: " . e.Message)
    }
}

UpdateNodeList() {
    global Nodes, CurrentCategory, NodeListPage, NodesPerPage
    
    try {
        search := Trim(searchBox.Value)
        filteredNodes := []
        
        for node in Nodes {
            if (node["category"] != CurrentCategory)
                continue
            
            if (search && !InStr(node["name"], search) && !InStr(node["text"], search))
                continue
            
            filteredNodes.Push(node)
        }
        
        totalPages := Max(Ceil(filteredNodes.Length / NodesPerPage), 1)
        
        if (NodeListPage > totalPages)
            NodeListPage := totalPages
        if (NodeListPage < 1)
            NodeListPage := 1
        
        startIdx := (NodeListPage - 1) * NodesPerPage + 1
        endIdx := Min(NodeListPage * NodesPerPage, filteredNodes.Length)
        
        items := []
        for i, node in filteredNodes {
            if (i >= startIdx && i <= endIdx) {
                items.Push(node["name"] . " (" . node["id"] . ")")
            }
        }
        
        nodeLb.Delete()
        if (items.Length > 0)
            nodeLb.Add(items)
        
        pageInfoTxt.Value := "Page " . NodeListPage . "/" . totalPages . " (" . filteredNodes.Length . ")"
        
        prevPageBtn.Enabled := (NodeListPage > 1)
        nextPageBtn.Enabled := (NodeListPage < totalPages)
        
        ; Update target dropdown
        allItems := []
        for node in Nodes {
            allItems.Push(node["name"] . " (" . node["id"] . ")")
        }
        choiceTarget.Delete()
        if (allItems.Length > 0)
            choiceTarget.Add(allItems)
    } catch as e {
        LogError("UpdateNodeList failed: " . e.Message)
    }
}

UpdateCategoryList() {
    global Categories, CurrentCategory
    
    try {
        cats := []
        for cat, arr in Categories {
            cats.Push(cat)
        }
        
        categoryDDL.Delete()
        if (cats.Length > 0) {
            categoryDDL.Add(cats)
            
            found := false
            Loop cats.Length {
                if (cats[A_Index] = CurrentCategory) {
                    categoryDDL.Choose(A_Index)
                    found := true
                    break
                }
            }
            if (!found)
                categoryDDL.Choose(1)
        }
    } catch as e {
        LogError("UpdateCategoryList failed: " . e.Message)
    }
}

SelectNodeByID(id) {
    global SelectedNodeID
    
    try {
        n := FindNodeByID(id)
        if (!n)
            return
        
        SelectedNodeID := id
        nameEdit.Value := n["name"]
        imgEdit.Value := n["image"]
        audioEdit.Value := n["audio"]
        textEdit.Value := n["text"]
        UpdatePreview(n["image"])
        UpdateChoicesList(n)
    } catch as e {
        LogError("SelectNodeByID failed: " . e.Message)
    }
}

FindNodeByID(id) {
    global NodeMap
    return NodeMap.Has(id) ? NodeMap[id] : ""
}

UpdatePreview(imagePath) {
    try {
        if (imagePath && FileExist(imagePath)) {
            try {
                previewPic.Value := "*w430 *h240 " . imagePath
            } catch {
                previewPic.Value := ""
            }
        } else {
            previewPic.Value := ""
        }
    } catch as e {
        LogError("UpdatePreview failed: " . e.Message)
    }
}

UpdateChoicesList(n) {
    try {
        choicesList.Delete()
        if (!n)
            return
        
        items := []
        for ch in n["choices"] {
            tname := "(unknown)"
            target := FindNodeByID(ch["target"])
            if (target)
                tname := target["name"]
            items.Push(ch["text"] . " → " . tname . " (" . ch["target"] . ")")
        }
        if (items.Length > 0)
            choicesList.Add(items)
    } catch as e {
        LogError("UpdateChoicesList failed: " . e.Message)
    }
}

UpdateStatistics() {
    global Nodes
    
    try {
        totalNodes := Nodes.Length
        totalChoices := 0
        avgChoices := 0
        deadEnds := 0
        maxDepth := 0
        
        for node in Nodes {
            totalChoices += node["choices"].Length
            if (node["choices"].Length = 0)
                deadEnds++
        }
        
        if (totalNodes > 0)
            avgChoices := Round(totalChoices / totalNodes, 1)
        
        if (Nodes.Length > 0) {
            visited := Map()
            maxDepth := CalculateDepth(Nodes[1]["id"], visited, 0)
        }
        
        stats := "Nodes: " . totalNodes . "`n"
        stats .= "Total Choices: " . totalChoices . "`n"
        stats .= "Avg Choices/Node: " . avgChoices . "`n"
        stats .= "Dead Ends: " . deadEnds . "`n"
        stats .= "Max Depth: " . maxDepth
        
        statsText.Value := stats
    } catch as e {
        LogError("UpdateStatistics failed: " . e.Message)
    }
}

CalculateDepth(id, visited, depth) {
    global MAX_DEPTH_LIMIT
    
    if (depth > MAX_DEPTH_LIMIT) {
        LogError("Max depth exceeded at node " . id)
        return depth
    }
    
    if (visited.Has(id))
        return 0
    
    visited[id] := true
    n := FindNodeByID(id)
    if (!n)
        return 0
    
    maxChild := 0
    for ch in n["choices"] {
        childDepth := CalculateDepth(ch["target"], visited, depth + 1)
        if (childDepth > maxChild)
            maxChild := childDepth
    }
    
    return 1 + maxChild
}

ClearEditor() {
    try {
        nameEdit.Value := ""
        imgEdit.Value := ""
        audioEdit.Value := ""
        textEdit.Value := ""
        previewPic.Value := ""
        choicesList.Delete()
    } catch as e {
        LogError("ClearEditor failed: " . e.Message)
    }
}

Status(txt) {
    try {
        statusTxt.Value := txt
        SetTimer(() => statusTxt.Value := "Ready.", -4000)
    } catch as e {
        LogError("Status failed: " . e.Message)
    }
}

; ═══════════════════════════════════════════════════════════════════════════
; UTILITY FUNCTIONS
; ═══════════════════════════════════════════════════════════════════════════

EscapeHTML(text) {
    text := StrReplace(text, "&", "&amp;")
    text := StrReplace(text, "<", "&lt;")
    text := StrReplace(text, ">", "&gt;")
    text := StrReplace(text, '"', "&quot;")
    text := StrReplace(text, "'", "&#39;")
    return text
}

EscapeJS(text) {
    ; JavaScript string escaping for use in single-quoted strings
    text := StrReplace(text, "\", "\\")      ; Backslash must be first
    text := StrReplace(text, "'", "\'")      ; Single quote
    text := StrReplace(text, "`n", "\n")     ; Newline
    text := StrReplace(text, "`r", "\r")     ; Carriage return
    text := StrReplace(text, "`t", "\t")     ; Tab
    text := StrReplace(text, Chr(0x08), "\b") ; Backspace
    text := StrReplace(text, Chr(0x0C), "\f") ; Form feed
    return text
}

JoinArray(arr, delimiter) {
    result := ""
    for i, item in arr {
        result .= item . (i < arr.Length ? delimiter : "")
    }
    return result
}

LogInfo(msg) {
    global LOG_FILE
    try {
        FileAppend(FormatNow() . " [INFO] " . msg . "`n", LOG_FILE, "UTF-8")
    }
}

LogError(msg) {
    global LOG_FILE
    try {
        FileAppend(FormatNow() . " [ERROR] " . msg . "`n", LOG_FILE, "UTF-8")
    }
}

FormatNow() {
    return FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
}

; Helper function for date difference calculation
DateDiff(date1, date2, unit) {
    ; Convert dates to timestamps and calculate difference
    ts1 := DateAdd(date1, 0, "Seconds")
    ts2 := DateAdd(date2, 0, "Seconds")
    
    diff := DateDiff(ts1, ts2, unit)
    return diff
}

; ═══════════════════════════════════════════════════════════════════════════
; END OF INKPATH v1.0 - PRODUCTION READY
; ═══════════════════════════════════════════════════════════════════════════