/*
Script: Inkpath Changer
Συγγραφέας: Tasos
Έτος: 2025
MIT License
Copyright (c) 2025 Tasos
*/

#Requires AutoHotkey v2.0

; Δημιουργία GUI
TraySetIcon("Shell32.dll", 44)
MyGui := Gui(, "Inkpath Path Changer")
MyGui.SetFont("s9", "Segoe UI")
MyGui.BackColor := "0xF0F0F0"

; === ΑΡΧΕΙΟ ΕΙΣΟΔΟΥ ===
MyGui.SetFont("s9 Bold")
MyGui.Add("GroupBox", "x10 y10 w580 h60", "Αρχείο Εισόδου")
MyGui.SetFont("s9", "Segoe UI")  ; Αλλαγή εδώ
InputFileEdit := MyGui.Add("Edit", "x20 y30 w470 h25 ReadOnly")
BrowseInputBtn := MyGui.Add("Button", "x500 y30 w80 h25", "Επιλογή...")
BrowseInputBtn.OnEvent("Click", SelectInputFile)

; === ΤΡΕΧΟΥΣΕΣ ΔΙΑΔΡΟΜΕΣ ===
MyGui.SetFont("s9 Bold")
MyGui.Add("GroupBox", "x10 y80 w580 h80", "Τρέχουσες Διαδρομές")
MyGui.SetFont("s9", "Segoe UI")  ; Αλλαγή εδώ
MyGui.Add("Text", "x20 y100 w60", "Images:")
OldImagePathEdit := MyGui.Add("Edit", "x85 y100 w495 h22 ReadOnly")
MyGui.Add("Text", "x20 y130 w60", "Audio:")
OldAudioPathEdit := MyGui.Add("Edit", "x85 y130 w495 h22 ReadOnly")

; === ΝΕΕΣ ΔΙΑΔΡΟΜΕΣ ===
MyGui.SetFont("s9 Bold")
MyGui.Add("GroupBox", "x10 y170 w580 h80", "Νέες Διαδρομές")
MyGui.SetFont("s9", "Segoe UI")  ; Αλλαγή εδώ
MyGui.Add("Text", "x20 y190 w60", "Images:")
NewImagePathEdit := MyGui.Add("Edit", "x85 y190 w495 h22", "C:\Inkpath\EP\EPImages")
MyGui.Add("Text", "x20 y220 w60", "Audio:")
NewAudioPathEdit := MyGui.Add("Edit", "x85 y220 w495 h22", "C:\Inkpath\EP\EPSounds")

; === ΑΡΧΕΙΟ ΕΞΟΔΟΥ ===
MyGui.SetFont("s9 Bold")
MyGui.Add("GroupBox", "x10 y260 w580 h60", "Αρχείο Εξόδου")
MyGui.SetFont("s9", "Segoe UI")  ; Αλλαγή εδώ
OutputFileEdit := MyGui.Add("Edit", "x20 y280 w470 h25 ReadOnly")
BrowseOutputBtn := MyGui.Add("Button", "x500 y280 w80 h25", "Επιλογή...")
BrowseOutputBtn.OnEvent("Click", SelectOutputFile)

; === ΚΟΥΜΠΙ ΜΕΤΑΤΡΟΠΗΣ ===
MyGui.SetFont("s10 Bold")
ConvertBtn := MyGui.Add("Button", "x10 y330 w580 h40", "⚡ ΜΕΤΑΤΡΟΠΗ ΑΡΧΕΙΟΥ")
ConvertBtn.OnEvent("Click", ConvertFile)

; === STATUS ===
MyGui.SetFont("s8", "Segoe UI")  ; Αλλαγή εδώ
StatusText := MyGui.Add("Text", "x10 y380 w580 h25 +Center", "Επιλέξτε αρχείο για να ξεκινήσετε...")

MyGui.Show("w600 h415")

; Συνάρτηση επιλογής αρχείου εισόδου
SelectInputFile(*) {
    global InputFileEdit, OutputFileEdit, OldImagePathEdit, OldAudioPathEdit
    SelectedFile := FileSelect(3, , "Επιλέξτε αρχείο Inkpath", "Inkpath Files (*.swp)")
    if (SelectedFile != "") {
        InputFileEdit.Value := SelectedFile
        
        ; Ανάγνωση του αρχείου για να βρούμε τα παλιά paths
        try {
            FileContent := FileRead(SelectedFile, "UTF-8")
            
            ; Αναζήτηση του πρώτου Image path (ολόκληρο)
            if (RegExMatch(FileContent, "Image=(.*?)\\([^\\]+\.(png|jpg|jpeg|gif|bmp))", &Match)) {
                OldImagePath := Match[1]  ; Χωρίς το όνομα αρχείου
                OldImagePathEdit.Value := OldImagePath
            } else {
                OldImagePathEdit.Value := "Δεν βρέθηκε Image path"
            }
            
            ; Αναζήτηση του πρώτου Audio path (ολόκληρο)
            if (RegExMatch(FileContent, "Audio=(.*?)\\([^\\]+\.(mp3|wav|ogg|m4a))", &Match)) {
                OldAudioPath := Match[1]  ; Χωρίς το όνομα αρχείου
                OldAudioPathEdit.Value := OldAudioPath
            } else {
                OldAudioPathEdit.Value := "Δεν βρέθηκε Audio path"
            }
            
        } catch {
            OldImagePathEdit.Value := "Σφάλμα ανάγνωσης"
            OldAudioPathEdit.Value := "Σφάλμα ανάγνωσης"
        }
        
        ; Αυτόματη πρόταση για το output file
        if (OutputFileEdit.Value = "") {
            SplitPath(SelectedFile, , &Dir, , &NameNoExt)
            OutputFileEdit.Value := Dir "\" NameNoExt "_modified.swp"
        }
    }
}

; Συνάρτηση επιλογής αρχείου εξόδου
SelectOutputFile(*) {
    global OutputFileEdit
    SelectedFile := FileSelect("S16", , "Αποθήκευση ως", "Inkpath Files (*.swp)")
    if (SelectedFile != "") {
        ; Προσθήκη επέκτασης αν λείπει
        if (!InStr(SelectedFile, ".swp"))
            SelectedFile .= ".swp"
        OutputFileEdit.Value := SelectedFile
    }
}

; Συνάρτηση μετατροπής
ConvertFile(*) {
    global InputFileEdit, NewImagePathEdit, NewAudioPathEdit, OutputFileEdit, StatusText
    global OldImagePathEdit, OldAudioPathEdit
    
    InputFile := InputFileEdit.Value
    NewImagePath := NewImagePathEdit.Value
    NewAudioPath := NewAudioPathEdit.Value
    OutputFile := OutputFileEdit.Value
    OldImagePath := OldImagePathEdit.Value
    OldAudioPath := OldAudioPathEdit.Value
    
    ; Έλεγχος πεδίων
    if (InputFile = "") {
        MsgBox("Παρακαλώ επιλέξτε αρχείο εισόδου!", "Σφάλμα", 16)
        return
    }
    if (NewImagePath = "") {
        MsgBox("Παρακαλώ εισάγετε το νέο Image path!", "Σφάλμα", 16)
        return
    }
    if (NewAudioPath = "") {
        MsgBox("Παρακαλώ εισάγετε το νέο Audio path!", "Σφάλμα", 16)
        return
    }
    if (OutputFile = "") {
        MsgBox("Παρακαλώ επιλέξτε αρχείο εξόδου!", "Σφάλμα", 16)
        return
    }
    
    ; Έλεγχος ύπαρξης αρχείου εισόδου
    if (!FileExist(InputFile)) {
        MsgBox("Το αρχείο εισόδου δεν υπάρχει!`n" InputFile, "Σφάλμα", 16)
        return
    }
    
    ; Αφαίρεση trailing backslash αν υπάρχει
    NewImagePath := RTrim(NewImagePath, "\")
    NewAudioPath := RTrim(NewAudioPath, "\")
    
    try {
        ; Διάβασμα αρχείου
        StatusText.Value := "Διάβασμα αρχείου..."
        FileContent := FileRead(InputFile, "UTF-8")
        
        ; Μέτρηση αλλαγών
        ImageCount := 0
        AudioCount := 0
        
        ; Αντικατάσταση paths για Image
        StatusText.Value := "Αντικατάσταση Image paths..."
        ; Βρίσκει το path μέχρι το τελευταίο \ πριν το όνομα αρχείου και το αντικαθιστά
        FileContent := RegExReplace(FileContent, "Image=.*?\\([^\\]+\.(png|jpg|jpeg|gif|bmp))", "Image=" NewImagePath "\$1", &ImageCount)
        
        ; Αντικατάσταση paths για Audio
        StatusText.Value := "Αντικατάσταση Audio paths..."
        FileContent := RegExReplace(FileContent, "Audio=.*?\\([^\\]+\.(mp3|wav|ogg|m4a))", "Audio=" NewAudioPath "\$1", &AudioCount)
        
        ; Εγγραφή στο νέο αρχείο
        StatusText.Value := "Αποθήκευση αρχείου..."
        
        ; Διαγραφή αν υπάρχει
        if (FileExist(OutputFile))
            FileDelete(OutputFile)
            
        FileAppend(FileContent, OutputFile, "UTF-8")
        
        StatusText.Value := "✓ Επιτυχής μετατροπή! Images: " ImageCount " | Audio: " AudioCount
        MsgBox("Η μετατροπή ολοκληρώθηκε με επιτυχία!`n`n" 
               . "Αλλαγές Image paths: " ImageCount "`n"
               . "Αλλαγές Audio paths: " AudioCount "`n`n"
               . "Αρχείο εξόδου: " OutputFile, "Επιτυχία", 64)
        
    } catch as err {
        StatusText.Value := "✗ Σφάλμα κατά τη μετατροπή!"
        MsgBox("Προέκυψε σφάλμα: " err.Message "`n`nΑρχείο: " err.File "`nΓραμμή: " err.Line, "Σφάλμα", 16)
    }
}

; Κλείσιμο του παραθύρου
MyGui.OnEvent("Close", (*) => ExitApp())