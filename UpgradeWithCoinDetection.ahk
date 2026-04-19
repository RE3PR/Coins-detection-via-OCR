;Consists out of a script to look at a link.txt and then it will read whether or not coin_enabled= is 0 or 1. If it is 1 then the script will follow a sequence of looking for your coin value and then proceeds to upgrade depending on link.txt value (This will be integerated better on a ui in the future)
#Requires AutoHotkey v2.0
#SingleInstance Force
CoordMode "Pixel", "Screen"
CoordMode "Mouse", "Screen"
SendMode "Event"
SetWorkingDir A_ScriptDir

#Include Gdip_All.ahk

global tesseractPath := "C:\Program Files\Tesseract-OCR\tesseract.exe"
global isRunning := false
global linkFile := A_ScriptDir "\link.txt"
global upgradeType := ""

; =========================
; START GDI+
; =========================
if !pToken := Gdip_Startup() {
    MsgBox "Failed to start GDI+"
    ExitApp
}
OnExit (*) => Gdip_Shutdown(pToken)

; =========================
; HOTKEYS
; =========================
k::StartMacro()
j::ExitApp()

; =========================
; READ CONFIG
; =========================
ReadConfig() {
    global linkFile
    config := Map()

    if !FileExist(linkFile)
        return config

    Loop Read linkFile {
        line := Trim(A_LoopReadLine)
        if (line = "" || !InStr(line, "="))
            continue

        parts := StrSplit(line, "=")
        key := Trim(parts[1])
        val := Trim(parts[2])
        config[key] := val
    }
    return config
}

; =========================
; CLEAN NUMBER
; =========================
CleanNumber(val) {
    val := StrReplace(val, ",")
    val := RegExReplace(val, "[^\d\.]")
    return (val = "" || val = ".") ? 0 : Number(val)
}

; =========================
; START MACRO
; =========================
StartMacro() {
    global isRunning

    config := ReadConfig()

    ToolTip "StartMacro triggered"

    if (!config.Has("coin_enabled") || config["coin_enabled"] != "1") {
        ToolTip "coin_enabled != 1 → stopping"
        return
    }

    if (isRunning) {
        ToolTip "Already running"
        return
    }

    isRunning := true

    ToolTip "Macro started"

    CoinDetection()
    SetTimer(CoinDetection, 2000)
}


; =========================
; MAIN LOOP
; =========================
CoinDetection() {
ToolTip "Running..."
    global isRunning, upgradeType

    config := ReadConfig()

    if (!config.Has("coin_enabled") || config["coin_enabled"] != "1") {
        SetTimer(CoinDetection, 0)
        isRunning := false
        return
    }

    upgrade := config.Has("upgrade") ? config["upgrade"] : "Size"

    ; Costs
    Cost_Max := CleanNumber(config.Has("Cost_Max") ? config["Cost_Max"] : "0")
    Cost_Walkspeed := CleanNumber(config.Has("Cost_Walkspeed") ? config["Cost_Walkspeed"] : "0")
    Cost_Multiplier := CleanNumber(config.Has("Cost_Multiplier") ? config["Cost_Multiplier"] : "0")
    Cost_EatSpeed := CleanNumber(config.Has("Cost_EatSpeed") ? config["Cost_EatSpeed"] : "0")

    ; OCR Coins
    value := GetOCR_Yellow(559, 103, 1030, 175)
    value := CleanNumber(value)

    shouldUpgrade := ""

    switch upgrade {
        case "Size":
            if (value >= Cost_Max)
                shouldUpgrade := "Size"

        case "Walkspeed":
            if (value >= Cost_Walkspeed)
                shouldUpgrade := "Walkspeed"

        case "Multiplier":
            if (value >= Cost_Multiplier)
                shouldUpgrade := "Multiplier"

        case "EatSpeed":
            if (value >= Cost_EatSpeed)
                shouldUpgrade := "EatSpeed"

        case "Ratio":
        {
            ratioVal := CleanNumber(config.Has("ratio") ? config["ratio"] : "1")
            coin_max := CleanNumber(config.Has("coin_max") ? config["coin_max"] : "0")
            coin_multi := CleanNumber(config.Has("coin_multi") ? config["coin_multi"] : "0")

            expectedMax := ratioVal * coin_multi

            if (coin_max < expectedMax) {
                if (value >= Cost_Max)
                    shouldUpgrade := "Size"
            }
            else if (coin_max > expectedMax) {
                if (value >= Cost_Multiplier)
                    shouldUpgrade := "Multiplier"
            }
            else {
                if (value >= Cost_Max)
                    shouldUpgrade := "Size"
            }
        }
    }

    ; =========================
    ; TRIGGER UPGRADE
    ; =========================
if (shouldUpgrade != "") {
    ToolTip "Triggering upgrade: " shouldUpgrade
    SetTimer(CoinDetection, 0)
    isRunning := false
    upgradeType := shouldUpgrade
    Upgrades()
}
}

Upgrades() {
    global isRunning


    SetTimer(CoinDetection, 0)
    isRunning := false

    filePath := A_ScriptDir "\link.txt"
    if !FileExist(filePath) {
        MsgBox "link.txt not found!"
        return
    }

    content := FileRead(filePath)

    upgradeType := ""
    ratioValue := ""

    ; ==================== ALWAYS RUN FIRST ====================
    color := PixelGetColor(1411, 207, "RGB")

    if (color = 0xD10000) {
        Click 1411, 222
    }

    Sleep 100

    color := PixelGetColor(554, 364, "RGB")

    if (color != 0x000000) {
        Click 62, 434
    }

    Sleep 200

    ; ==================== READ SETTINGS ====================
    for line in StrSplit(content, "`n") {
        line := Trim(line)

        if InStr(line, "upgrade=")
            upgradeType := Trim(StrReplace(line, "upgrade="))

        if InStr(line, "ratio=")
            ratioValue := Trim(StrReplace(line, "ratio="))
    }

    ; ==================== DECISION ====================
    if (upgradeType = "Ratio") {
        RatioUpgrade(ratioValue)
    } 
    else if (upgradeType != "") {
        NormalUpgrade(upgradeType)
    } 
    else {
        MsgBox "No upgrade type found!"
        return
    }

    AfterUpgrade()
}


; ==================== NORMAL UPGRADES ====================
NormalUpgrade(type) {

    if (type = "Size") {
        Click 1268, 449
    }
    else if (type = "Walkspeed") {
        Click 1267, 649
    }
    else if (type = "Multiplier") {
        Click 1266, 842
    }
    else if (type = "EatSpeed") {
        Click 1036, 354
        start := A_TickCount
        while (A_TickCount - start < 300) {
            Send "{WheelDown}"
        }
        Sleep 250
        Click 1266, 867
    }
}

; ==================== AFTER UPGRADE ====================
AfterUpgrade() {

    Sleep 2000

    ; Fail check first
    if (PixelGetColor(63, 606, "RGB") = 0xFFFFFF) {
        HandleRecovery()
        return
    }

    loop {
        ; Wait for the blue button/state
        if (PixelGetColor(642, 616, "RGB") = 0x335FFF) {

            ; Click WHILE it is still visible
            while (PixelGetColor(642, 616, "RGB") = 0x335FFF) {

                Click 1037, 381
                Sleep 100

                ; emergency fail check
                if (PixelGetColor(63, 606, "RGB") = 0xFFFFFF) {
                    HandleRecovery()
                    return
                }
            }

            ; Once it disappears → move on
            HandleRecovery()
            return
        }
        else {
            Sleep 200
        }
    }
}

RatioUpgrade(ratio) {

    ; ==================== OCR READ ====================
    sizeText := GetOCR(967, 429, 1119, 461)
    multiText := GetOCR(960, 823, 1140, 855)

    ; ==================== DEBUG RAW OCR ====================
    ToolTip(
        "RAW OCR:`n"
        . "SizeText: [" sizeText "]`n"
        . "MultiText: [" multiText "]"
    , 10, 200)

    ; ==================== SAFE NUMBER CONVERSION ====================
    size := CleanNumber(sizeText)
    multi := CleanNumber(multiText)
    ratioVal := CleanNumber(ratio)

    ; ==================== VALIDATION ====================
    if (size = 0 || multi = 0 || ratioVal = 0) {
        ToolTip(
            "OCR FAILED:`n"
            . "Size: " size "`n"
            . "Multi: " multi "`n"
            . "Ratio: " ratioVal
        , 10, 260)

        return
    }

    ; ==================== CALCULATIONS ====================
    expectedSize := ratioVal * multi
    tolerance := 0.2

    ; ==================== DEBUG VALUES ====================
    ToolTip(
        "CALC:`n"
        . "Size: " size "`n"
        . "Multi: " multi "`n"
        . "Expected: " expectedSize "`n"
        . "Ratio: " ratioVal
    , 10, 320)

    ; ==================== DECISION ====================
    if (Abs(size - expectedSize) <= tolerance) {
        ToolTip("Decision: SIZE (stable)", 10, 400)
        Click 1268, 449
    }
    else if (size < expectedSize) {
        ToolTip("Decision: SIZE (too small)", 10, 400)
        Click 1268, 449
    }
    else {
        ToolTip("Decision: MULTIPLIER (too big)", 10, 400)
        Click 1266, 842
    }

    ; ==================== CLEAN TOOLTIP AFTER 2s ====================
    SetTimer(() => ToolTip(), -2000)
}


; ==================== REJOIN ====================
MegaMaps() {
    MsgBox "Rejoining..."
}


HandleRecovery() {
    global isRunning

    config := ReadConfig()

    coinEnabled := config.Has("coin_enabled") ? config["coin_enabled"] : "0"

    if (coinEnabled = "0") {
        MegaMaps()
        return
    }

    ; If enabled → recover and restart macro
    Click 1454, 239
    Sleep 300

    ; restart main macro
    isRunning := false
    MainMacro()
}

MainMacro() {
MsgBox("End") 
}







GetOCR(x1, y1, x2, y2)
{
    global tesseractPath

    w := x2 - x1
    h := y2 - y1

    tempImage := A_Temp "\ocr_" A_TickCount ".png"
    tempOutput := A_Temp "\ocr_" A_TickCount

    ; =========================
    ; CAPTURE WITH GDI+
    ; =========================
    pBitmap := Gdip_BitmapFromScreen(x1 "|" y1 "|" w "|" h)

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

            ; threshold (tweak if needed)
            if (r > 200 && g > 200 && b > 200) {
                Gdip_SetPixel(pBitmap, x, y, 0xFFFFFFFF)
            } else {
                Gdip_SetPixel(pBitmap, x, y, 0xFF000000)
            }
        }
    }

    Gdip_SaveBitmapToFile(pBitmap, tempImage)
    Gdip_DisposeImage(pBitmap)

    ; =========================
    ; OCR WITH TESSERACT
    ; =========================
    RunWait '"' tesseractPath '" "' tempImage '" "' tempOutput '" --oem 3 --psm 7 -c tessedit_char_whitelist=0123456789.', , "Hide"

    ; =========================
    ; READ RESULT
    ; =========================
    text := ""
    if FileExist(tempOutput ".txt") {
        text := Trim(FileRead(tempOutput ".txt"))
    }

    ; =========================
    ; CLEANUP
    ; =========================
    FileDelete tempImage
    FileDelete tempOutput ".txt"

    return text
}
























; =========================
; OCR FUNCTION
; =========================
GetOCR_Yellow(x1, y1, x2, y2) {
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
