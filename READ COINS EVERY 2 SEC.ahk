#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir A_ScriptDir

#Include Gdip_All.ahk

global tesseractPath := "C:\Program Files\Tesseract-OCR\tesseract.exe"
global isRunning := false
global coinText := "0"
global myGui := 0
global textControl := 0

; Start GDI+
if !pToken := Gdip_Startup() {
    MsgBox "Failed to start GDI+"
    ExitApp
}
OnExit (*) => Gdip_Shutdown(pToken)

; Hotkeys
F1::ToggleMacro()
F2::ExitApp()

; =========================
; TOGGLE LOOP
; =========================
ToggleMacro() {
    global isRunning

    isRunning := !isRunning

    if (isRunning) {
        SetTimer(MainMacro, 2000)
        ShowGUI()
    } else {
        SetTimer(MainMacro, 0)
    }
}

; =========================
; MAIN LOOP
; =========================
MainMacro() {
    global coinText

    value := GetOCR(559, 103, 1030, 175)

    if (value = "")
        value := "0"

    coinText := value
    UpdateGUI()
}

; =========================
; OCR FUNCTION
; =========================
GetOCR(x1, y1, x2, y2) {
    global tesseractPath

    w := x2 - x1
    h := y2 - y1

    filteredImage := A_Temp "\filtered.png"
    tempOutput := A_Temp "\ocr_result"

    pBitmap := Gdip_BitmapFromScreen(x1 "|" y1 "|" w "|" h)

    pFiltered := Gdip_CloneBitmapArea(pBitmap, 0, 0, w, h)
    FilterYellow(pFiltered)

    Gdip_SaveBitmapToFile(pFiltered, filteredImage)

    RunWait '"' tesseractPath '" "' filteredImage '" "' tempOutput '" --psm 7 -c tessedit_char_whitelist=0123456789,', , "Hide"

    text := ""
    if FileExist(tempOutput ".txt") {
        text := Trim(FileRead(tempOutput ".txt"))
        FileDelete tempOutput ".txt"
    }

    Gdip_DisposeImage(pBitmap)
    Gdip_DisposeImage(pFiltered)

    return text
}

; =========================
; COLOR FILTER
; =========================
FilterYellow(pBitmap) {
    width := Gdip_GetImageWidth(pBitmap)
    height := Gdip_GetImageHeight(pBitmap)

    Loop height {
        y := A_Index - 1
        Loop width {
            x := A_Index - 1

            color := Gdip_GetPixel(pBitmap, x, y)

            r := (color >> 16) & 0xFF
            g := (color >> 8) & 0xFF
            b := color & 0xFF

            brightness := (r + g + b) // 3

            ; Handles both yellow + dark backgrounds
            isGold := (
                (r > 120 && g > 80 && b < 200 && brightness < 230) ||
                (r > 150 && g > 120 && b < 210)
            )

            if (isGold)
                Gdip_SetPixel(pBitmap, x, y, 0xFFFFFFFF)
            else
                Gdip_SetPixel(pBitmap, x, y, 0xFF000000)
        }
    }
}

; =========================
; GUI
; =========================
ShowGUI() {
    global myGui, textControl, coinText

    if (myGui)
        return

    myGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
    myGui.BackColor := "Black"
    myGui.SetFont("s14 cWhite", "Segoe UI")

    textControl := myGui.AddText("w220 Center", "Coins: " coinText)

    myGui.Show("x10 y10")
}

UpdateGUI() {
    global textControl, coinText

    if (textControl)
        textControl.Value := "Coins: " coinText
}

j::ExitApp()