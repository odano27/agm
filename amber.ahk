#MaxHotkeysPerInterval 9999
#NoEnv
#SingleInstance Force

; --- AUTO-ADMIN ELEVATION ---
if !A_IsAdmin
{
    Run *RunAs "%A_ScriptFullPath%"
    ExitApp
}

; --- HIGH PERFORMANCE SETTINGS ---
SetBatchLines, -1
Process, Priority, , H     
TargetCore := 3 ; 0=Core1, 1=Core2, 2=Core3, 3=Core4...
hProcess := DllCall("GetCurrentProcess")
DllCall("SetProcessAffinityMask", "Ptr", hProcess, "Ptr", 1 << TargetCore)
DllCall("winmm\timeBeginPeriod", "UInt", 1) 
OnExit, CleanupTimer

SendMode Input
SetWorkingDir %A_ScriptDir%

; ==============================================================================
; CONFIGURATION & INITIALIZATION
; ==============================================================================
global TriggerButton := "XButton2" ; Default value
global fps := 60                   ; Default value
global autoclicker := false
global cps := 6
global first_run := true
global SettingsFile := A_ScriptDir . "\macro_settings.json"
global LastMacroType := 0 ; 0: None, 1: Skirk, 2: Tao, 3: Mav
global LastMacroMode := 0 ; Stores the specific mode index
global XB1Clicks := 0     ; Click counter

; Set up Enhanced Tray Menu
Menu, Tray, NoStandard
Menu, Tray, Add, Reset Trigger, ResetTriggerMenu
Menu, Tray, Add, Reset FPS, ResetFPSMenu
Menu, Tray, Add, Open Settings Folder, OpenSettingsFolder
Menu, Tray, Add
Menu, Tray, Standard

; Load settings or prompt for first run
LoadSettings()

; Show launch info if not in setup mode
ShowLaunchDialog()

; Initialize toggles
media_override := false
ping := 40 
ghostState := 0
SkirkMacroEnabled := 0 ; 0: Off, 1: 9N2 2N5 N3, 2: 10N2 2N5 N3 CA, 3: 12N2 4N3
TaoMacroEnabled := 0 ; 0: Off, 1: 10N2CD, 2: 9N2CJ, 3: 11N2CD
MavMacroEnabled := 0 ; 0: Off, 1: Melt, 2: Overload
NeferMacroEnabled := 0 ;

; Bind the dynamic hotkey ($ prefix allows sending the key itself)
Hotkey, *$%TriggerButton%, MainTriggerLabel
return

; ==============================================================================
; SETTINGS MANAGEMENT
; ==============================================================================

LoadSettings() {
    if FileExist(SettingsFile) {
        FileRead, json, %SettingsFile%
        
        ; Extract Trigger
        if RegExMatch(json, "i)""trigger""\s*:\s*""([^""]+)""", tMatch){
            TriggerButton := tMatch1
            first_run := false
        }
        else
            SetupNewTrigger()

        ; Extract FPS
        if RegExMatch(json, "i)""fps""\s*:\s*(\d+)", fMatch){
            fps := fMatch1
            first_run := false
        }
        else
            SetupFPS()
        
        ; Extract Autoclicker
        if RegExMatch(json, "i)""autoclicker""\s*:\s*(true|false)", aMatch){
            autoclicker := (aMatch1 = "true")
        }

        ; Extract CPS
        if RegExMatch(json, "i)""cps""\s*:\s*(\d+)", cMatch){
            cps := cMatch1
        }
        return
    }
    ; If file doesn't exist, run both setups
    SetupNewTrigger()
    SetupFPS()
}

SaveSettings() {
    jsonString := "{""trigger"": """ . TriggerButton . """, ""fps"": " . fps . ", ""autoclicker"": " . (autoclicker ? "true" : "false") . ", ""cps"": " . cps . "}"
    file := FileOpen(SettingsFile, "w")
    file.Write(jsonString)
    file.Close()
}

ShowLaunchDialog() {
    Gui, Launch:New, +AlwaysOnTop -Caption +Border +ToolWindow, MacroLaunch
    Gui, Launch:Color, 1A1A1A
    Gui, Launch:Font, s12 cWhite, Segoe UI
    if first_run
        Gui, Launch:Add, Text, Center w300, Macro Setup Complete!
    else{
        Gui, Launch:Add, Text, Center w300, Remember to set the correct FPS.
        Gui, Launch:Font, s10
        Gui, Launch:Add, Text, Center w300, -Improved and reimplemented N3W. C1 Skirk macro is better on paper but usually performs worse than N3W before C6`n-Combo optimizations improvements
        Gui, Launch:Font, s10
    }
    Gui, Launch:Add, Text, Center w300, Trigger: %TriggerButton% | FPS: %fps%`n`nF8: Skirk | F9: Hu Tao | F10: Mavuika`nCtrl+Alt+Space: Active Macro Help`nCtrl+Shift+End: Reset All
    Gui, Launch:Show, w320
    
    ; Display for 5 seconds then destroy
    SetTimer, DestroyLaunchGui, -5000
}

DestroyLaunchGui:
    Gui, Launch:Destroy
return

SetupFPS() {
    Gui, FPS:New, +AlwaysOnTop -Caption +Border +ToolWindow, MacroFPS
    Gui, FPS:Color, 1A1A1A
    Gui, FPS:Font, s12 cWhite, Segoe UI
    Gui, FPS:Add, Text, Center w300, PERFORMANCE SETUP
    Gui, FPS:Font, s10
    Gui, FPS:Add, Text, Center w300, Enter your in-game FPS (1-1000):`n(values over 120 are treated the same for now)`nMake sure your FPS is stable at this value.
    Gui, FPS:Add, Edit, vTempFPS Center w60 x130 Color000000, %fps%
    Gui, FPS:Add, Button, gSubmitFPS w80 x120 Default, OK
    Gui, FPS:Show, w320 h180
    
    ; Pause script execution until GUI is closed
    WinWaitClose, MacroFPS
}

SubmitFPS:
    Gui, Submit
    if TempFPS is not integer
    {
        MsgBox, 48, Error, Please enter a whole number.
        Gui, FPS:Show
        return
    }
    if (TempFPS < 1 || TempFPS > 1000)
    {
        MsgBox, 48, Error, Please enter a value between 1 and 1000.
        Gui, FPS:Show
        return
    }
    fps := TempFPS
    SaveSettings()
    Gui, Destroy
return

SetupNewTrigger() {
    Sleep 1000
    Gui, Setup:New, +AlwaysOnTop -Caption +Border +ToolWindow, MacroSetup
    Gui, Setup:Color, 1A1A1A
    Gui, Setup:Font, s12 cWhite, Segoe UI
    Gui, Setup:Add, Text, Center w300, INITIAL SETUP
    Gui, Setup:Font, s10
    Gui, Setup:Add, Text, Center w300, Press the key to use as your macro trigger.`n(Mouse/Keyboard supported. Ctrl, Alt, F8-F10 ignored.)
    Gui, Setup:Font, s16 cFF6600
    Gui, Setup:Add, Text, Center w300, [Waiting for input]
    Gui, Setup:Font, s10 cFF6600
    Gui, Setup:Add, Text, Center w300, Relaunch the script if this dialog becomes unresponsive.
    Gui, Setup:Show, w320
    
    OldTrigger := TriggerButton
    if (OldTrigger != "")
        Hotkey, *$%OldTrigger%, Off, UseErrorLevel

    TriggerButton := GetPressedKey()
    
    Hotkey, *$%TriggerButton%, MainTriggerLabel, On
    
    SaveSettings()
    
    Gui, Setup:Destroy
    ToolTip, Trigger set to: %TriggerButton%
    SetTimer, RemoveToolTip, -3000
}

GetPressedKey() {
    mouseButtons := ["LButton", "RButton", "MButton", "XButton1", "XButton2"]
    ignoreKeys := ["Control", "LControl", "RControl", "Alt", "LAlt", "RAlt", "F8", "F9", "F10", "F11" "LWin", "RWin", "Shift", "LShift", "RShift"]
    
    Loop {
        for each, btn in mouseButtons {
            if GetKeyState(btn, "P") {
                KeyWait, %btn%
                return btn
            }
        }
        Loop, 255 {
            code := Format("vk{:x}", A_Index)
            if GetKeyState(code, "P") {
                key := GetKeyName(code)
                isIgnored := false
                for each, ignore in ignoreKeys {
                    if (key = ignore) {
                        isIgnored := true
                        break
                    }
                }
                if !isIgnored {
                    KeyWait, %key%
                    return key
                }
            }
        }
        Sleep, 10
    }
}

^+End::
    SetupNewTrigger()
    SetupFPS()
return

; ==============================================================================
; MAIN MACRO DISPATCHER
; ==============================================================================

#IfWinActive ahk_exe GenshinImpact.exe

^!Space::
    if (SkirkMacroEnabled) {
        title := "SKIRK MACRO HELP"
        if (SkirkMacroEnabled = 1)
            msg := "Current Mode: 9N2 2N5 N3 Skirk`nTarget: 60 FPS / C0`nCombo: 2N2D N2Q 2N2D N5D N2D N2C 2N2D N5D N3`nTiming: Hold trigger right after swapping to Skirk."
        else if (SkirkMacroEnabled = 2)
            msg := "Current Mode: 11N2 2N5 CA Skirk`nTarget: C1+ / 120+ FPS`nCombo: N2Q 2N2D N5D N2D N2C 2N2D N5D N2C N2D N2`nTiming: Hold trigger right after swapping to Skirk."
        else
            msg := "Current Mode: 12N2 4N3 Skirk (increase wCount if N3W doesn't cancel properly)`nTarget: Stable 144+ FPS, loses 1 N3 at 120 FPS`nCombo: 2N2D N2Q 2N2D N3W 2N2D N3W N2D N2C N2D N3W 2N2D N3(N2)`nTiming: Hold trigger right after swapping to Skirk."
    }
    else if (TaoMacroEnabled) {
        title := "HU TAO MACRO HELP"
        if (TaoMacroEnabled = 1)
            msg := "Current Mode: 10N2CD`nBest for: C1 vaporize gameplay without Xingqiu.`n`nTiming: hold trigger button right after switching to Hu Tao."
        else if (TaoMacroEnabled = 2)
            msg := "Current Mode: 9N2CJ`nBest for: C0 gameplay (without Xianyun).`n`nTiming: hold trigger button right after switching to Hu Tao."
        else if (TaoMacroEnabled = 3)
            msg := "Current Mode: Xianyun Plunge 6N1CJP, at 120 FPS becomes 4N1CJP + 2N2CJP`nBest for: Plunge Tao with Xianyun.`n`nTiming: hold trigger button right after switching to Hu Tao."
        else if (TaoMacroEnabled = 4)
            msg := "Current Mode: 11N2CD (unstable)`nBest for: C1 non-vaporize/vaporize with Xingqiu.`n`nTiming: hold trigger button right after switching to Hu Tao."
    }
    else if (MavMacroEnabled) {
        title := "MAVUIKA MACRO HELP"
        if (MavMacroEnabled = 1)
            msg := "Current Mode: Mavuika Melt with Citlali, might not work with ping over 100ms`nCombo: CQ -> c -> dCccF -> dcF -> dcF -> dc F`n`nIMPORTANT - Cit E Q swap to Mavuika must be done as quickly as possible.`nTiming: Start holding the trigger button the moment you see Mavuika on the field.`nThis is the most timing-sensitive macro in the set, so it may take some (but not much) practice to get the timing down consistently."
        else if (MavMacroEnabled = 2)
            msg := "Current Mode: Overload/Mono Pyro`nCombo: qc -> 3(dcdccf) -> dcf`n`nTiming: hold trigger button right after swapping to Mavuika."
        else if (MavMacroEnabled = 3)
            msg := "Current Mode: 6 Melt (unoptimized lenient timing)`nCombo: Q -> C -> dcF -> dcF -> dcF -> dc F`n`nIMPORTANT - Cit E Q N1 is compulsory for application window.`nTiming: Start holding the trigger button the moment you see Mavuika on the field."
    }
    else {
        title := "MACRO HELP"
        msg := "No macro is currently active.`n`nF8: Skirk`nF9: Hu Tao`nF10: Mavuika"
    }
    msg .= "`n`nCurrent Global FPS Setting: " . fps
    msg .= "`nCurrent Trigger Button: " . TriggerButton
    MsgBox, 64, %title%, %msg%
return

MainTriggerLabel:
    if media_override
        return
    if (SkirkMacroEnabled>0)
        Gosub, SkirkLogic
    else if (TaoMacroEnabled>0)
        Gosub, TaoLogic
    else if (MavMacroEnabled>0)
        Gosub, MavLogic
    else if (NeferMacroEnabled>0)
        Gosub, NeferLogic
    else if (TriggerButton != "LButton" || autoclicker){
        delay := (1000 / cps) - 22
        Loop {
            HardwareClickDown()
            PreciseSleep(20)
            HardwareClickUp()
            PreciseSleep(delay)
            If !GetKeyState(TriggerButton, "P")
                break
        }
    }
    else {
        SendInput {%TriggerButton% down}
        KeyWait, %TriggerButton%
        SendInput {%TriggerButton% up}
    }
return

#IfWinActive

; ==============================================================================
; MACRO TOGGLES
; ==============================================================================

F8::
    SkirkMacroEnabled := SkirkMacroEnabled + 1
    if (SkirkMacroEnabled > 4)
        SkirkMacroEnabled := 0
    else {
        TaoMacroEnabled := 0 
        MavMacroEnabled := 0
        LastMacroType := 1
        LastMacroMode := SkirkMacroEnabled
    }
    status := (SkirkMacroEnabled = 1) ? "C0 N5 (60 fps)" : (SkirkMacroEnabled = 2) ? "C1+ (120 fps)" : (SkirkMacroEnabled = 3) ? "C0 N3W (usable 120, better at 144)" : (SkirkMacroEnabled = 4) ? "Testing" : "OFF"
    ToolTip, % "Skirk Macro: " . status
    SetTimer, RemoveToolTip, -2500
return

F9::
    TaoMacroEnabled := TaoMacroEnabled + 1
    if (TaoMacroEnabled > 4)
        TaoMacroEnabled := 0
    else {
        SkirkMacroEnabled := 0 
        MavMacroEnabled := 0   
        LastMacroType := 2
        LastMacroMode := TaoMacroEnabled
    }
    status := (TaoMacroEnabled = 1) ? "10N2CD" : (TaoMacroEnabled = 2) ? "9N2CJ" : (TaoMacroEnabled = 3) ? "Xianyun 6N1CJP" : (TaoMacroEnabled = 4) ? "11N2CD" : "OFF"
    ToolTip, % "Tao Macro: " . status
    SetTimer, RemoveToolTip, -2000
return

F10::
    MavMacroEnabled := MavMacroEnabled + 1
    if (MavMacroEnabled > 3)
        MavMacroEnabled := 0
    else {
        SkirkMacroEnabled := 0 
        TaoMacroEnabled := 0   
        LastMacroType := 3
        LastMacroMode := MavMacroEnabled
    }
    status := (MavMacroEnabled = 1) ? "7 Melt (EQ Cit)" : (MavMacroEnabled = 2) ? "Overload" : (MavMacroEnabled = 3) ? "6 Melt (EQN1 Cit)" : "OFF"
    ToolTip, % "Mavuika Macro: " . status
    SetTimer, RemoveToolTip, -2000
return

F11::
    NeferMacroEnabled := NeferMacroEnabled + 1
    if (NeferMacroEnabled > 1)
        NeferMacroEnabled := 0
    else {
        LastMacroMode := NeferMacroEnabled
        LastMacroType := 4
        TaoMacroEnabled := 0
        MavMacroEnabled := 0
        SkirkMacroEnabled := 0
    }
    status := NeferMacroEnabled ? "ON" : "OFF"
    ToolTip, % "Nefer Macro: " . status
    SetTimer, RemoveToolTip, -2000

; ==============================================================================
; MACRO LOGIC BLOCKS
; ==============================================================================

SkirkLogic:
    if (SkirkMacroEnabled > 0) {
        eSleep := fps <= 60 ? 300 : 280
        HardwareEDown()
        SendInput {e down}
        PreciseSleep(10)
        HardwareEUp()
        SendInput {e up}
        PreciseSleep(eSleep)
    }

    if (SkirkMacroEnabled = 1) { ; 60 fps/C0
        if !DoClicksAndCheck(10,,,19)        ;N2D
            return
        if !DoClicksAndCheck(10,,,19)        ;N2D
            return
        if !DoClicksAndQCheck(10,655,20)     ;N2Q
            return
        if !DoClicksAndCheck(10,,,19)        ;N2D
            return
        if !DoClicksAndCheck(10,,,19)        ;N2D
            return
        if !DoClicksAndCheck(46,310,,20)     ;N5D
            return
        if !DoClicksAndCheck(10,,,19)        ;N2D
            return
        if !DoChargedAttackCheck(10,575,20)  ;N2C
            return
        if !DoClicksAndCheck(10,,,19)        ;N2D
            return
        if !DoClicksAndCheck(10,,,19)        ;N2D
            return
        if !DoClicksAndCheck(46,310,,20)     ;N5D
            return
        DoClicksOnly(20,20)                     ;N3
    }
    else if (SkirkMacroEnabled = 2) { ; 120 fps/C1+
        count1 := 17
        prerd := 30
        postrd := 160
        if !DoClicksAndQCheck(18,650,10)  ;N2Q
            return
        if !DoClicksAndRCheck(count1, prerd, postrd, 10)     ; N2D
            return
        if !DoClicksAndRCheck(count1, prerd, postrd, 10)     ; N2D
            return
        if !DoClicksAndCheck(84,285,175,10)     ;N5D
            return
        if !DoClicksAndRCheck(count1, prerd, postrd, 10)     ; N2D
            return
        if !DoChargedAttackCheck(17,575,10)  ;N2C
            return
        if !DoClicksAndRCheck(count1, prerd, postrd, 10)     ; N2D
            return
        if !DoClicksAndRCheck(count1, prerd, postrd, 10)     ; N2D
            return
        if !DoClicksAndCheck(84,285,175,10)     ;N5D
            return
        if !DoChargedAttackCheck(17,575,10)  ;N2C
            return
        if !DoClicksAndRCheck(count1, prerd, postrd, 10)     ; N2D
            return
        ;DoClicksOnly(36,10) ; N3
        if !DoChargedAttackCheck(36,575,10)  ;N3C (C6)
            return
    }
    else if (SkirkMacroEnabled = 3) { ; very stable 120 fps C0
        wCount := 33
        count1 := 17
        prerd := 30
        postrd := 160
        postwd := 10
        prewd := 40
        if !DoClicksAndRCheck(count1, prerd + 5, postrd, 10) ; N2D
            return
        if !DoClicksAndRCheck(count1, prerd, postrd, 10)     ; N2D
            return
        if !DoClicksAndQCheck(17, 655, 10, 40)            ; N2Q
            return
        if !DoClicksAndRCheck(count1, prerd, postrd, 10)     ; N2D
            return
        if !DoClicksAndRCheck(count1, prerd, postrd, 10)     ; N2D
            return
        if !DoClicksAndWCheck(27, wCount, prewd, 10, 10)     ; N3W
            return
        PreciseSleep(postwd)
        if !DoClicksAndRCheck(count1, prerd, postrd, 10)     ; N2D
            return
        if !DoClicksAndRCheck(count1, prerd, postrd, 10)     ; N2D
            return
        if !DoClicksAndWCheck(27, wCount, prewd, 10, 10)     ; N3W
            return
        PreciseSleep(postwd)
        if !DoClicksAndRCheck(count1, prerd, postrd, 10)     ; N2D
            return
        if !DoChargedAttackCheck(17, 580, 10)             ; N2C
            return
        if !DoClicksAndRCheck(count1, prerd, postrd, 10)     ; N2D
            return
        if !DoClicksAndWCheck(27, wCount, prewd, 10, 10)     ; N3W
            return
        PreciseSleep(postwd+15)
        if !DoClicksAndRCheck(count1, prerd, postrd, 10)     ; N2D
            return
        if !DoClicksAndRCheck(count1, prerd, postrd, 10)     ; N2D
            return
        DoClicksOnly(36, 10)                              ; N3 Final
    }
    else if (SkirkMacroEnabled = 4){ ; some chinese magic doesn't work with actual combat
        HardwareEDown() ; EN2Q
        HardwareEUp()
        PreciseSleep(320)
        HardwareClickDown()
        HardwareClickUp()
        PreciseSleep(130)
        HardwareClickDown()
        HardwareClickUp()
        PreciseSleep(220)
        HardwareQDown()
        HardwareQUp()
        PreciseSleep(660)
        HardwareClickDown() ; N2D
        HardwareClickUp()
        PreciseSleep(131)
        HardwareClickDown()
        HardwareClickUp()
        PreciseSleep(231)
        HardwareRClickDown()
        HardwareRClickUp()
        PreciseSleep(20)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(40)
        HardwareClickDown() ; N2D
        HardwareClickUp()
        PreciseSleep(131)
        HardwareClickDown()
        HardwareClickUp()
        PreciseSleep(231)
        HardwareRClickDown()
        HardwareRClickUp()
        PreciseSleep(20)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(40)
        HardwareClickDown() ; N5D
        HardwareClickUp()
        PreciseSleep(101)
        HardwareClickDown()
        HardwareClickUp()
        PreciseSleep(340)
        HardwareClickDown()
        HardwareClickUp()
        PreciseSleep(620)
        HardwareClickDown()
        HardwareClickUp()
        PreciseSleep(575)
        HardwareClickDown()
        HardwareClickUp()
        PreciseSleep(500)
        HardwareRClickDown()
        HardwareRClickUp()
        PreciseSleep(20)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(40)
        HardwareClickDown() ; N2D
        HardwareClickUp()
        PreciseSleep(131)
        HardwareClickDown()
        HardwareClickUp()
        PreciseSleep(231)
        HardwareRClickDown()
        HardwareRClickUp()
        PreciseSleep(20)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(40)
        HardwareClickDown() ; N2C
        HardwareClickUp()
        PreciseSleep(131)
        HardwareClickDown()
        HardwareClickUp()
        PreciseSleep(200)
        HardwareClickDown()
        PreciseSleep(200)
        HardwareClickUp()
        PreciseSleep(700)
        HardwareClickDown() ; N2D
        HardwareClickUp()
        PreciseSleep(131)
        HardwareClickDown()
        HardwareClickUp()
        PreciseSleep(231)
        HardwareRClickDown()
        HardwareRClickUp()
        PreciseSleep(20)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(40)
        HardwareClickDown() ; N2D
        HardwareClickUp()
        PreciseSleep(131)
        HardwareClickDown()
        HardwareClickUp()
        PreciseSleep(231)
        HardwareRClickDown()
        HardwareRClickUp()
        PreciseSleep(20)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(40)
        HardwareClickDown() ; N5D
        HardwareClickUp()
        PreciseSleep(101)
        HardwareClickDown()
        HardwareClickUp()
        PreciseSleep(340)
        HardwareClickDown()
        HardwareClickUp()
        PreciseSleep(620)
        HardwareClickDown()
        HardwareClickUp()
        PreciseSleep(575)
        HardwareClickDown()
        HardwareClickUp()
        PreciseSleep(500)
        HardwareRClickDown()
        HardwareRClickUp()
        PreciseSleep(20)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(40)
        HardwareClickDown() ; N2D
        HardwareClickUp()
        PreciseSleep(131)
        HardwareClickDown()
        HardwareClickUp()
        PreciseSleep(231)
        HardwareRClickDown()
        HardwareRClickUp()
        PreciseSleep(20)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(40)
        HardwareClickDown() ; N2C
        HardwareClickUp()
        PreciseSleep(131)
        HardwareClickDown()
        HardwareClickUp()
        PreciseSleep(200)
        HardwareClickDown()
        PreciseSleep(200)
        HardwareClickUp()
        PreciseSleep(700)
        HardwareClickDown() ; N2D
        HardwareClickUp()
        PreciseSleep(131)
        HardwareClickDown()
        HardwareClickUp()
        PreciseSleep(231)
        HardwareRClickDown()
        HardwareRClickUp()
        PreciseSleep(20)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(30)
        HardwareWDown()
        HardwareWUp()
        PreciseSleep(40)
        HardwareClickDown() ; N3 Final
        HardwareClickUp()
        PreciseSleep(100)
        HardwareClickDown()
        HardwareClickUp()
        PreciseSleep(450)
        HardwareClickDown()
        HardwareClickUp()
        PreciseSleep(100)
    }
return

;        count1 := 17
;        prerd := 33
;        postrd := 155
;        if !DoClicksAndRCheck(count1, prerd + 5, postrd, 10)     ; N2D
;            return
;        if !DoClicksAndRCheck(count1, prerd, postrd, 10)     ; N2D
;            return
;        if !DoClicksAndQCheck(17,655,10,40)  ;N2Q
;            return
;        if !DoClicksAndRCheck(count1, prerd, postrd, 10)     ; N2D
;            return
;        if !DoClicksAndRCheck(count1, prerd, postrd, 10)     ; N2D
;            return
;        if !DoClicksAndCheck(84,310,170,10)     ;N5D
;            return
;        if !DoClicksAndRCheck(count1, prerd, postrd, 10)     ; N2D
;            return
;        if !DoChargedAttackCheck(17,400,10)  ;N2C
;            return
;        HardwareRClickDown()
;        PreciseSleep(10)
;        HardwareRClickUp()
;        PreciseSleep(170)
;        if !DoClicksAndRCheck(count1, prerd, postrd, 10)     ; N2D
;            return
;        if !DoClicksAndRCheck(count1, prerd, postrd, 10)     ; N2D
;            return
;        if !DoClicksAndCheck(84,310,170,10)     ;N5D
;            return
;        if !DoClicksAndRCheck(count1, prerd, postrd, 10)     ; N2D
;            return
;        DoClicksOnly(58,10) ; N3

TaoLogic:
    plungeCount := 0
    XYcDelay := fps <= 60 ? 500 : 450
    HardwareEDown()
    PreciseSleep(10)
    HardwareEUp()
    PreciseSleep(fps <= 60 ? 450 : 425)
    Loop {
        if !GetKeyState(TriggerButton, "P")
            break   
        if (TaoMacroEnabled = 1) { ; 10N2CD
            HardwareClickDown()
            PreciseSleep(20)
            HardwareClickUp()
            PreciseSleep(175)
            if !GetKeyState(TriggerButton, "P")
                break 
            HardwareClickDown()
            PreciseSleep(20)
            HardwareClickUp()
            PreciseSleep(120)
            if !GetKeyState(TriggerButton, "P")
                break  
            HardwareClickDown()
            PreciseSleep(275)
            HardwareClickUp()
            if !GetKeyState(TriggerButton, "P")
                break 
            PreciseSleep(50)
            HardwareRClickDown()
            PreciseSleep(50)
            HardwareRClickUp()
            SendInput {a down}
            PreciseSleep(20)
            SendInput {a up}
            PreciseSleep(55)
            SendInput {d down}
            PreciseSleep(20)
            SendInput {d up}
            PreciseSleep(55)
            PreciseSleep(125)
            if !GetKeyState(TriggerButton, "P")
                break
        }
        else if (TaoMacroEnabled = 2) { ; 9N2CJ
            HardwareClickDown()
            PreciseSleep(10)
            HardwareClickUp()
            if !GetKeyState(TriggerButton, "P")
                break
            PreciseSleep(175)
            HardwareClickDown()
            PreciseSleep(10)
            HardwareClickUp()
            if !GetKeyState(TriggerButton, "P")
                break
            PreciseSleep(120)
            HardwareClickDown()
            PreciseSleep(300)
            HardwareClickUp()
            HardwareSpaceDown()
            HardwareSpaceUp()
            PreciseSleep(560)
        }
        else if (TaoMacroEnabled = 3) { ; Xianyun 6N1CJP
            if !GetKeyState(TriggerButton, "P"){
                break
                plungeCount := 0
            }
            if (plungeCount > 10){
                break
                plungeCount := 0
            }
            HardwareClickDown()
            PreciseSleep(XYcDelay)
            HardwareClickUp()
            if !GetKeyState(TriggerButton, "P"){
                break
                plungeCount := 0
            }
            HardwareSpaceDown()
            PreciseSleep(20)
            HardwareSpaceUp()
            PreciseSleep(20)
            if !GetKeyState(TriggerButton, "P"){
                break
                plungeCount := 0
            }
            plungeClicks := 10
            if (plungeCount > 3 || fps < 120)
                plungeClicks := 6
            Loop %plungeClicks% {
                HardwareClickDown()
                PreciseSleep(20)
                HardwareClickUp()
                PreciseSleep(20)
            }
            if !GetKeyState(TriggerButton, "P"){
                break
                plungeCount := 0
            }
            plungeCount:= plungeCount + 1
        }
        else if (TaoMacroEnabled = 4) { ; 11N2CD
            HardwareClickDown()
            PreciseSleep(20)
            HardwareClickUp()
            PreciseSleep(165)
            if !GetKeyState(TriggerButton, "P")
                break
            HardwareClickDown()
            PreciseSleep(20)
            HardwareClickUp()
            PreciseSleep(110)
            if !GetKeyState(TriggerButton, "P")
                break
            HardwareClickDown()
            PreciseSleep(250)
            HardwareClickUp()
            if !GetKeyState(TriggerButton, "P")
                break
            PreciseSleep(50)
            SendInput {LShift down}
            PreciseSleep(50)
            SendInput {LShift up}
            SendInput {a down}
            PreciseSleep(20)
            SendInput {a up}
            PreciseSleep(55)
            SendInput {d down}
            PreciseSleep(20)
            SendInput {d up}
            PreciseSleep(55)
            PreciseSleep(135)
            if !GetKeyState(TriggerButton, "P")
                break
        }
    }
return
MavLogic:
    if (MavMacroEnabled = 1) { ; 7 melt
        PreciseSleep(200) ; jsbqjnbrjwq3nrjkn
        HardwareEDown()
        PreciseSleep(10)
        HardwareEUp()
        PreciseSleep(50) 
        HardwareClickDown()
        PreciseSleep(610)
        HardwareClickUp()
        
        if !GetKeyState(TriggerButton, "P")
            return
            
        SendInput {q down}
        PreciseSleep(20)
        SendInput {q up}
        PreciseSleep(1670)
        
        if !GetKeyState(TriggerButton, "P")
            return
        
        HardwareClickDown()
        PreciseSleep(400)
        HardwareClickUp()
        
        if !GetKeyState(TriggerButton, "P")
            return
        PreciseSleep(60)
        
        HardwareClickDown()
        PreciseSleep(180)
        SendInput {LShift down}
        PreciseSleep(90)
        SendInput {LShift up}
        PreciseSleep(2300) 
        HardwareClickUp()
        
        if !GetKeyState(TriggerButton, "P")
            return
        PreciseSleep(590) 
        
        HardwareClickDown()
        PreciseSleep(180)
        SendInput {LShift down}
        PreciseSleep(90)
        SendInput {LShift up}
        PreciseSleep(600)
        HardwareClickUp()
        
        if !GetKeyState(TriggerButton, "P")
            return
        PreciseSleep(585) 
        
        HardwareClickDown()
        PreciseSleep(200)
        SendInput {LShift down}
        PreciseSleep(90)
        SendInput {LShift up}
        PreciseSleep(600)
        HardwareClickUp()
        
        if !GetKeyState(TriggerButton, "P")
            return
        PreciseSleep(800)
        if !GetKeyState(TriggerButton, "P")
            return
        HardwareClickDown()
        PreciseSleep(200)
        SendInput {LShift down}
        PreciseSleep(90)
        SendInput {LShift up}
        PreciseSleep(800) 
        HardwareClickUp()
        PreciseSleep(1200)
        
        if !GetKeyState(TriggerButton, "P")
            return
        SendInput {e}
    }
    else if (MavMacroEnabled = 3) { ; 6 melt testing
        PreciseSleep(ping)
        HardwareQDown()
        PreciseSleep(20)
        HardwareQUp()
        PreciseSleep(1900-ping)
        
        if !GetKeyState(TriggerButton, "P")
            return
        
        HardwareClickDown() 
        PreciseSleep(400)
        HardwareClickUp()
        
        if !GetKeyState(TriggerButton, "P")
            return
        PreciseSleep(60)
        
        HardwareClickDown()
        PreciseSleep(200)
        HardwareShiftDown()
        PreciseSleep(90)
        HardwareShiftUp()
        PreciseSleep(900)
        HardwareClickUp()
        
        if !GetKeyState(TriggerButton, "P")
            return
        PreciseSleep(700) 
        
        HardwareClickDown()
        PreciseSleep(180)
        HardwareShiftDown()
        PreciseSleep(90)
        HardwareShiftUp()
        PreciseSleep(900)
        HardwareClickUp()
        
        if !GetKeyState(TriggerButton, "P")
            return
        PreciseSleep(700) 
        
        HardwareClickDown()
        PreciseSleep(180)
        HardwareShiftDown()
        PreciseSleep(90)
        HardwareShiftUp()
        PreciseSleep(900)
        HardwareClickUp()
        
        if !GetKeyState(TriggerButton, "P")
            return
        PreciseSleep(700) 

        HardwareClickDown()
        PreciseSleep(180)
        HardwareShiftDown()
        PreciseSleep(90)
        HardwareShiftUp()
        PreciseSleep(900)
        HardwareClickUp()
        
        if !GetKeyState(TriggerButton, "P")
            return
        PreciseSleep(1200) 
        
        if !GetKeyState(TriggerButton, "P")
            return
        SendInput {e}
    }
    else if (MavMacroEnabled = 2) { ; overload 
        HardwareClickDown()
        PreciseSleep(300)
        HardwareClickUp()
        
        if !GetKeyState(TriggerButton, "P")
            return
        PreciseSleep(60)
        HardwareClickDown()
        PreciseSleep(200)
        SendInput {LShift down}
        PreciseSleep(90)
        SendInput {LShift up}
        PreciseSleep(150)
        HardwareClickUp()
        
        if !GetKeyState(TriggerButton, "P")
            return
        PreciseSleep(90)
        
        HardwareClickDown()
        PreciseSleep(200)
        SendInput {LShift down}
        PreciseSleep(90)
        SendInput {LShift up}
        PreciseSleep(1000)
        HardwareClickUp()
        
        if !GetKeyState(TriggerButton, "P")
            return
        PreciseSleep(850)
        HardwareClickDown()
        PreciseSleep(200)
        SendInput {LShift down}
        PreciseSleep(90)
        SendInput {LShift up}

        SendInput {q down}
        PreciseSleep(200)
        SendInput {q up}
        BurstTimer := 0
        While (BurstTimer < 1550) {
            if !GetKeyState(TriggerButton, "P")
                return
            PreciseSleep(50)
            BurstTimer += 50
        }
        HardwareClickDown()
        PreciseSleep(300)
        HardwareClickUp()
        
        if !GetKeyState(TriggerButton, "P")
            return
        PreciseSleep(60)
        
        Loop 3 { 
            HardwareClickDown()
            PreciseSleep(200)
            SendInput {LShift down}
            PreciseSleep(90)
            SendInput {LShift up}
            PreciseSleep(150)
            HardwareClickUp()
            
            if !GetKeyState(TriggerButton, "P")
                return
            PreciseSleep(90)
            
            HardwareClickDown()
            PreciseSleep(200)
            SendInput {LShift down}
            PreciseSleep(90)
            SendInput {LShift up}
            PreciseSleep(1000)
            HardwareClickUp()
            
            if !GetKeyState(TriggerButton, "P")
                return
            PreciseSleep(850)
        }
        HardwareClickDown()
        PreciseSleep(200)
        SendInput {LShift down}
        PreciseSleep(90)
        SendInput {LShift up}
        PreciseSleep(150)
        HardwareClickUp()
    }
return
NeferLogic:
    loop 1{
        SendInput, e
        PreciseSleep(600)
        if !GetKeyState(TriggerButton, "P")
            break
        HardwareClickDown()
        PreciseSleep(600)
        if !GetKeyState(TriggerButton, "P"){
            Break
            HardwareClickUp()
        }
        HardwareShiftDown()
        PreciseSleep(20)
        HardwareShiftUp()
        PreciseSleep(1050)
        if !GetKeyState(TriggerButton, "P"){
            Break
            HardwareClickUp()
        }
        HardwareShiftDown()
        PreciseSleep(20)
        HardwareShiftUp()
        PreciseSleep(1050)
        if !GetKeyState(TriggerButton, "P"){
            Break
            HardwareClickUp()
        }
        HardwareShiftDown()
        PreciseSleep(20)
        HardwareShiftUp()
        HardwareClickUp()
        PreciseSleep(400)
        SendInput, e
        PreciseSleep(600)
        if !GetKeyState(TriggerButton, "P")
            break
        HardwareClickDown()
        PreciseSleep(600)
        if !GetKeyState(TriggerButton, "P"){
            Break
            HardwareClickUp()
        }
        HardwareClickUp()
        HardwareQDown()
        PreciseSleep(10)
        HardwareQUp()
        if !GetKeyState(TriggerButton, "P"){
            Break
            HardwareClickUp()
        }
        PreciseSleep(1700)
        if !GetKeyState(TriggerButton, "P"){
            Break
            HardwareClickUp()
        }
        HardwareClickDown()
        PreciseSleep(800)
        if !GetKeyState(TriggerButton, "P"){
            Break
            HardwareClickUp()
        }
        HardwareShiftDown()
        PreciseSleep(20)
        HardwareShiftUp()
        PreciseSleep(1050)
        if !GetKeyState(TriggerButton, "P"){
            Break
            HardwareClickUp()
        }
        HardwareShiftDown()
        PreciseSleep(20)
        HardwareShiftUp()
        HardwareClickUp()
        PreciseSleep(400)
    }
return

; ==============================================================================
; CLEANUP & TIMING HELPERS
; ==============================================================================

RemoveToolTip:
    ToolTip
return

CleanupTimer:
    DllCall("winmm\timeEndPeriod", "UInt", 1)
    ExitApp

ResetTriggerMenu:
    SetupNewTrigger()
return

ResetFPSMenu:
    SetupFPS()
return

OpenSettingsFolder:
    Run %A_ScriptDir%
return

PreciseSleep(Delay) {
    static freq := 0
    if (!freq)
        DllCall("QueryPerformanceFrequency", "Int64*", freq)

    DllCall("QueryPerformanceCounter", "Int64*", start)
    target := Delay * freq / 1000
    Loop {
        DllCall("QueryPerformanceCounter", "Int64*", now)
        remaining := (target - (now - start)) * 1000 / freq

        if (remaining <= 1.2)
            break

        if (remaining > 10)
            DllCall("Sleep", "UInt", 5)
        else
            DllCall("Sleep", "UInt", 1)
    }
    Loop {
        DllCall("QueryPerformanceCounter", "Int64*", now)
        if ((now - start) >= target)
            break
        DllCall("Sleep", "UInt", 0)
    }
}

HardwareClickDown() {
    DllCall("mouse_event", "UInt", 0x0002) 
}
HardwareClickUp() {
    DllCall("mouse_event", "UInt", 0x0004) 
}

HardwareRClickDown() {
    DllCall("mouse_event", "UInt", 0x0008) 
}
HardwareRClickUp() {
    DllCall("mouse_event", "UInt", 0x0010) 
}

HardwareWDown() {
    DllCall("keybd_event", "UChar", 0x57, "UChar", 0, "UInt", 0, "Ptr", 0)
}
HardwareWUp() {
    DllCall("keybd_event", "UChar", 0x57, "UChar", 0, "UInt", 2, "Ptr", 0)
}

HardwareEDown() {
    DllCall("keybd_event", "UChar", 0x45, "UChar", 0, "UInt", 0, "Ptr", 0)
}
HardwareEUp() {
    DllCall("keybd_event", "UChar", 0x45, "UChar", 0, "UInt", 2, "Ptr", 0)
}

HardwareQDown() {
    DllCall("keybd_event", "UChar", 0x51, "UChar", 0, "UInt", 0, "Ptr", 0)
}
HardwareQUp() {
    DllCall("keybd_event", "UChar", 0x51, "UChar", 0, "UInt", 2, "Ptr", 0)
}

HardwareSpaceDown() {
    DllCall("keybd_event", "UChar", 0x20, "UChar", 0, "UInt", 0, "Ptr", 0)
}
HardwareSpaceUp() {
    DllCall("keybd_event", "UChar", 0x20, "UChar", 0, "UInt", 2, "Ptr", 0)
}

HardwareShiftDown() {
    DllCall("keybd_event", "UChar", 0x10, "UChar", 0, "UInt", 0, "Ptr", 0)
}
HardwareShiftUp() {
    DllCall("keybd_event", "UChar", 0x10, "UChar", 0, "UInt", 2, "Ptr", 0)
}

DoClicksAndCheck(count, preShiftDelay := 50, postShiftDelay:= 210, click_delay := 39) {
    Loop % count - 1 {
        HardwareClickDown()
        PreciseSleep(click_delay-5)
        HardwareClickUp()
        PreciseSleep(click_delay+5)
    }
    HardwareClickDown()
    PreciseSleep(click_delay)
    HardwareClickUp()
    PreciseSleep(preShiftDelay)
    if !GetKeyState(TriggerButton, "P")
        return false 
    SendInput {Shift down}
    PreciseSleep(20)
    SendInput {Shift up}
    PreciseSleep(postShiftDelay)
    return true
}

DoClicksAndRCheck(count, preRDelay := 50, postRDelay:= 210, click_delay := 39) {
    Loop % count - 1 {
        HardwareClickDown()
        PreciseSleep(click_delay-5)
        HardwareClickUp()
        PreciseSleep(click_delay+5)
    }
    HardwareClickDown()
    PreciseSleep(click_delay)
    HardwareClickUp()
    PreciseSleep(preRDelay)
    if !GetKeyState(TriggerButton, "P")
        return false 
    HardwareRClickDown()
    PreciseSleep(20)
    HardwareRClickUp()
    PreciseSleep(postRDelay)
    return true
}

DoClicksAndWCheck(count, Wcount, preWalkDelay := 200, WDelay := 50, click_delay := 40) {
    Loop % count - 1 {
        HardwareClickDown()
        PreciseSleep(click_delay-5)
        HardwareClickUp()
        PreciseSleep(click_delay+5)
    }
    HardwareClickDown()
    PreciseSleep(click_delay)
    HardwareClickUp()
    PreciseSleep(preWalkDelay)
    if !GetKeyState(TriggerButton, "P")
        return false 
    Loop % Wcount {
        HardwareWDown()
        PreciseSleep(WDelay)
        HardwareWUp()
        PreciseSleep(WDelay)
    }
    return true
}

DoClicksAndQCheck(count, q_delay := 700, click_delay := 39, preQDelay := 50) {
    Loop % count - 1 {
        HardwareClickDown()
        PreciseSleep(click_delay-5)
        HardwareClickUp()
        PreciseSleep(click_delay+5)
    }
    HardwareClickDown()
    PreciseSleep(click_delay)
    HardwareClickUp()
    PreciseSleep(preQDelay)
    if !GetKeyState(TriggerButton, "P")
        return false 
    SendInput {q down}
    PreciseSleep(20)
    SendInput {q up}
    PreciseSleep(q_delay)
    return true
}

DoChargedAttackCheck(count, delay := 600, click_delay := 39) {
    Loop % count - 1 {
        HardwareClickDown()
        PreciseSleep(click_delay-5)
        HardwareClickUp()
        PreciseSleep(click_delay+5)
    }
    if !GetKeyState(TriggerButton, "P")
        return false 
    HardwareClickDown()
    PreciseSleep(300)
    HardwareClickUp()
    PreciseSleep(delay)
    return GetKeyState(TriggerButton, "P")
}

DoClicksOnly(count, click_delay := 39) {
    Loop % count {
        HardwareClickDown()
        PreciseSleep(click_delay)
        HardwareClickUp()
        PreciseSleep(click_delay)
        if !GetKeyState(TriggerButton, "P")
            return false 
    }
}

; ==============================================================================
; MEDIA & VOLUME LAYER (Controlled by XButton1 / M5) + TRIPLE CLICK TOGGLE
; ==============================================================================

*XButton1:: 
    media_override := true
    XB1Clicks++
    if (XB1Clicks = 1)
        SetTimer, ResetXB1Clicks, -1000 ; 1 second window
    
    if (XB1Clicks = 3) {
        Gosub, ToggleLastMacro
        XB1Clicks := 0
    }
return

ResetXB1Clicks:
    XB1Clicks := 0
return

ToggleLastMacro:
    ; Check if ANY macro is currently on
    if (SkirkMacroEnabled || TaoMacroEnabled || MavMacroEnabled || NeferMacroEnabled) {
        SkirkMacroEnabled := 0
        TaoMacroEnabled := 0
        MavMacroEnabled := 0
        NeferMacroEnabled := 0
        ToolTip, Macros: DISABLED
    } 
    else {
        ; If everything is off, restore the last used type and mode
        if (LastMacroType = 1) {
            SkirkMacroEnabled := LastMacroMode
            ToolTip, Restored Skirk Mode %LastMacroMode%
        } else if (LastMacroType = 2) {
            TaoMacroEnabled := LastMacroMode
            ToolTip, Restored Hu Tao Mode %LastMacroMode%
        } else if (LastMacroType = 3) {
            MavMacroEnabled := LastMacroMode
            ToolTip, Restored Mavuika Mode %LastMacroMode%
        } else if (LastMacroType = 4) {
            NeferMacroEnabled := LastMacroMode
            ToolTip, Restored Nefer Mode %LastMacroMode%
        } else {
            ToolTip, No Macro History Found
        }
    }
    SetTimer, RemoveToolTip, -1500
return

#If GetKeyState("XButton1","P")
*WheelUp::Send {Volume_Up}
*WheelDown::Send {Volume_Down}
*LButton::Send {Media_Prev}
*RButton::Send {Media_Next}
*MButton::Send {Media_Play_Pause}

*XButton2::
    if GetKeyState("Alt") {
        Send {Tab}
    } else {
        Send {Alt Down}{Tab}
    }
return
#If

*XButton1 Up::
    if (GetKeyState("Alt") or GetKeyState("Alt", "P")) {
        Send {Alt Up}
    }
    media_override := false
return


; ==============================================================================
; GHOST MODE TOGGLE (F1)
; ==============================================================================

F1::
    ghostState++
    if (ghostState > 2) {
        ghostState := 0
    }

    if (ghostState == 1) {
        WinGet, targetWindow, ID, A 
        WinSet, Transparent, 80, ahk_id %targetWindow%
        WinSet, ExStyle, +0x20, ahk_id %targetWindow%
        WinSet, AlwaysOnTop, On, ahk_id %targetWindow%
        ToolTip, Ghost Mode: 80 (Heavy)
    }
    else if (ghostState == 2) {
        WinSet, Transparent, 160, ahk_id %targetWindow%
        WinSet, ExStyle, +0x20, ahk_id %targetWindow%
        WinSet, AlwaysOnTop, On, ahk_id %targetWindow%
        ToolTip, Ghost Mode: 160 (Light)
    }
    else {
        WinSet, Transparent, OFF, ahk_id %targetWindow%
        WinSet, ExStyle, -0x20, ahk_id %targetWindow%
        WinSet, AlwaysOnTop, Off, ahk_id %targetWindow%
        ToolTip, Normal Mode
        targetWindow := "" 
    }
    SetTimer, RemoveToolTip, -1000
return