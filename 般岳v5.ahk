#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================
; 般岳宏 v5.0 - 绝区零 (Zenless Zone Zero)
; ============================================
; Home = 开启/关闭宏
; PgDn = 切换搓招/连招模式
; Delete = 退出脚本
; PgUp = 显示帮助
; Ctrl+PgUp = 显示/隐藏按键悬浮窗
; ============================================

; =================================================================================================
; 1. 全局变量区 (Global Variables)
; =================================================================================================

; --- 宏状态控制 ---
global MacroEnabled := true       ; 宏开关状态
global ComboMode := true          ; false=搓招模式, true=连招模式(默认)
global KeyOverlayEnabled := false ; 按键显示开关 (默认关闭)
global LastManualKey := 0         ; 上一次搓招按键 (用于搓招模式下的派生逻辑)

; --- GUI 对象引用 ---
global KeyOverlayGui := ""        ; 按键显示GUI对象
global KeyControls := Map()       ; 按键控件集合
global StatusTextCtrl := ""       ; 状态文本控件
global GlobalHelpGui := ""        ; 帮助窗口GUI对象

; --- 连招中断控制 ---
global IsComboRunning := false    ; 连招是否正在运行
global StopComboRequest := false  ; 是否收到中断请求

; --- 游戏按键映射 (根据游戏实际设置调整) ---
global KeyAttack := "LButton"     ; 普攻 - 鼠标左键
global KeyDodge := "RButton"      ; 闪避 - 鼠标右键
global KeySpecial := "e"          ; 强化/特殊技
global KeyUltimate := "q"         ; 大招
global KeySupport := "Space"      ; 支援/切人

; --- 基础延迟配置 ---
global GlobalLatency := 0              ; 全局延迟补偿(ms)，可填负值。正值=增加延迟(慢)，负值=减少延迟(快)。例: -20
global KeyPressDelay := 100            ; 单次按键按下时长(ms)
global KeyIntervalDelay_Manual := 50   ; 搓招模式 - 连续按键间隔(ms)
global KeyIntervalDelay_Combo := 80    ; 连招模式 - 连续按键间隔(ms)
global TauntDirectionDelay := 25       ; 叫阵方向键间隔(ms)

; --- 连招延迟配置 (核心调优区) ---

; [1键] 三连招延迟 (闪能不足时最优)
; 路线: 地动(510%) → 山摇·怒(650.6%) → 狮子吼(307.7%)
global Key1Delay1 := 900       ; 地动后 → 山摇·怒 延迟 (等待完美取消)
global Key1Delay2 := 550        ; 山摇·怒后 → 狮子吼 延迟 (等待完美取消)

; [2键] 短轴双连 (EEE启动)
; 路线: 论道 → 狮子吼·怒 → 山摇
global Key2Delay1 := 150          ; 论道 → 狮子吼·怒 延迟 (等待完美取消)
global Key2Delay2 := 300          ; 狮子吼·怒 → 山摇 延迟 (等待完美取消)

; [X键] 怒吼瞬山 (EEE启动)
; 路线: 论道 → 狮子吼·怒 → 按住A(蓄力) → 瞬山
global XKeyHoldADelay := 1250      ; 按住A的时长

; [3键] 四连招延迟 (地动起手，闪反后用) - 原 Key 2
; 路线: 地动 → 山摇·怒 → 论道 → 狮子吼·怒 (最高总倍率)
global XStartDelay := 10          ; 完美取消手感调整（±5ms）
global XHoldE := 1100             ; 长按E时长 (触发地动)
global XDelay1 := 600             ; 地动 → 山摇·怒 延迟
global XDelay2 := 500             ; 山摇·怒 → 论道 延迟
global XDelay3 := 500             ; 论道 → 狮子吼·怒 延迟

; [4键] 四连招延迟 (论道起手，闪反/不动如山后用) - 原 Key 3
; 路线: 论道 → 狮子吼·怒 → 地动 → 山摇·怒 (狮子吼怒优先)
global CStartDelay := 10          ; 完美取消手感调整（±5ms）
global CHoldA := 700              ; 长按A时长 (触发论道)
global CDelay1 := 300             ; 论道 → 狮子吼·怒 延迟
global CDelay2 := 350             ; 狮子吼·怒 → 地动 延迟
global CDelay3 := 1150            ; 地动 → 山摇·怒 延迟

; [侧键4] 完美取消2怒爆发 (论道前置均可用)
; 路线: 论道→狮子吼·怒→地动→山摇·怒
global Side4Delay1 := 400         ;论道(EAE) → 狮子吼·怒(AAE) 延迟
global Side4Delay2 := 300          ;狮子吼·怒(AAE) → 地动(AEA) 延迟
global Side4Delay3 := 1100          ;地动(AEA) → 山摇·怒(EEA)延迟

; [Shift] 闪反振击上切人 (右键→左键→Shift)
global ShiftKeyDelay1 := 50           ; 右键 → 左键 延迟
global ShiftKeyDelay2 := 5          ; 左键 → Shift 延迟

; 2. 核心功能函数 (Core Functions)
; =================================================================================================

; --- 基础输入函数 ---

; 统一延迟等待 (包含中断检查)
MacroSleep(delay) {
    Sleep(delay + GlobalLatency)
    CheckInterrupt()
}

; 模拟按键按下与释放
PressKey(key, duration := KeyPressDelay) {
    Send("{" key " down}")
    Sleep(duration)
    Send("{" key " up}")
}

; 快速键入指令序列 (例如 "AAE")
QuickInput(sequence) {
    global ComboMode, KeyIntervalDelay_Manual, KeyIntervalDelay_Combo
    ; 根据模式选择延迟
    interval := ComboMode ? KeyIntervalDelay_Combo : KeyIntervalDelay_Manual

    loop parse, sequence {
        CheckInterrupt()
        switch A_LoopField {
            case "A": PressKey(KeyAttack)
            case "E": PressKey(KeySpecial)
        }
        CheckInterrupt()
        if (A_Index < StrLen(sequence)) {
            Sleep(interval)
            CheckInterrupt()
        }
    }
}

; 叫阵动作 (半圈方向键 + 闪避)
DoTaunt() {
    ; 使用 SendInput 极速发送指令 (比 SendEvent 更快，且无默认延迟)
    ; 模拟半圈摇杆: W -> A -> S

    SendInput "{w down}"
    Sleep(TauntDirectionDelay)
    SendInput "{w up}"

    SendInput "{a down}"
    Sleep(TauntDirectionDelay)
    SendInput "{a up}"

    SendInput "{s down}"
    Sleep(TauntDirectionDelay)
    SendInput "{s up}"

    ; 鼠标右键闪避
    Click("Right")
}

; --- 中断控制函数 ---

StartInterruptionMonitor() {
    global IsComboRunning, StopComboRequest
    StopComboRequest := false
    IsComboRunning := true
}

StopInterruptionMonitor() {
    global IsComboRunning
    IsComboRunning := false
}

CheckInterrupt() {
    global StopComboRequest, IsComboRunning
    if (IsComboRunning && StopComboRequest) {
        throw Error("ComboInterrupted")
    }
}

; --- GUI 与状态显示函数 ---

UpdateStatusText(text) {
    global StatusTextCtrl
    if StatusTextCtrl {
        SetTimer(ClearStatusText, 0) ; 取消之前的清除定时器
        StatusTextCtrl.Value := text
        StatusTextCtrl.Opt("+cWhite") ; 高亮显示
    }
}

ClearStatusText() {
    global StatusTextCtrl
    if StatusTextCtrl {
        StatusTextCtrl.Value := ""
    }
}

ToggleKeyOverlay() {
    global KeyOverlayEnabled, KeyOverlayGui
    KeyOverlayEnabled := !KeyOverlayEnabled
    if KeyOverlayEnabled {
        if KeyOverlayGui
            KeyOverlayGui.Show("NoActivate x100 y100 w270 h200")
        ToolTip("按键显示: 已开启")
    } else {
        if KeyOverlayGui
            KeyOverlayGui.Hide()
        ToolTip("按键显示: 已关闭")
    }
    SetTimer(() => ToolTip(), -1500)
}

CreateKeyOverlay() {
    global KeyOverlayGui, KeyControls, StatusTextCtrl, KeyOverlayEnabled
    KeyOverlayGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner", "按键显示")
    KeyOverlayGui.BackColor := "1e1e1e"
    KeyOverlayGui.SetFont("s8 bold", "Verdana")

    ; 样式辅助函数
    AddKey := "w38 h38 center 0x200 cWhite Background333333 border"

    ; --- 键盘区 (左侧) ---
    KeyControls["1"] := KeyOverlayGui.Add("Text", "x8 y8 " AddKey, "1")
    KeyControls["2"] := KeyOverlayGui.Add("Text", "x+4 " AddKey, "2")
    KeyControls["3"] := KeyOverlayGui.Add("Text", "x+4 " AddKey, "3")
    KeyControls["4"] := KeyOverlayGui.Add("Text", "x+4 " AddKey, "4")

    KeyControls["q"] := KeyOverlayGui.Add("Text", "x8 y+4 " AddKey, "Q")
    KeyControls["e"] := KeyOverlayGui.Add("Text", "x+45 " AddKey, "E")

    KeyControls["LShift"] := KeyOverlayGui.Add("Text", "x8 y+4 w80 h30 center 0x200 cWhite Background333333 border",
        "Shift")
    KeyControls["Space"] := KeyOverlayGui.Add("Text", "x+4 w80 h30 center 0x200 cWhite Background333333 border",
        "Space")

    ; --- 鼠标区 (右侧) ---
    KeyControls["LButton"] := KeyOverlayGui.Add("Text", "x180 y8 " AddKey, "LMB")
    KeyControls["RButton"] := KeyOverlayGui.Add("Text", "x+4 " AddKey, "RMB")

    KeyControls["XButton1"] := KeyOverlayGui.Add("Text", "x180 y+4 " AddKey, "M4")
    KeyControls["XButton2"] := KeyOverlayGui.Add("Text", "x+4 " AddKey, "M5")

    ; 拖动支持
    DragFunc := (*) => PostMessage(0xA1, 2, 0, , "ahk_id " KeyOverlayGui.Hwnd)
    OnMessage(0x0201, (wParam, lParam, msg, hwnd) => hwnd = KeyOverlayGui.Hwnd ? PostMessage(0xA1, 2, 0, , "ahk_id " hwnd
    ) : "")
    for keyName, ctrl in KeyControls {
        ctrl.OnEvent("Click", DragFunc)
    }

    ; --- 状态显示区 ---
    KeyOverlayGui.SetFont("s9 bold cWhite", "Microsoft YaHei")
    StatusTextCtrl := KeyOverlayGui.Add("Text", "x8 y130 w254 h60 cGray Background1e1e1e Wrap", "等待指令...")

    if KeyOverlayEnabled {
        KeyOverlayGui.Show("NoActivate x100 y100 w270 h200")
    }

    SetTimer(UpdateKeyOverlay, 16)
}

UpdateKeyOverlay() {
    global KeyControls
    for keyName, ctrl in KeyControls {
        if GetKeyState(keyName, "P") {
            ctrl.Opt("+BackgroundFF9900 +cBlack")
        } else {
            ctrl.Opt("+Background333333 +cWhite")
        }
    }
}

ShowHelpGui() {
    global ComboMode, GlobalHelpGui

    ; 如果帮助窗口已存在，则关闭它 (Toggle功能)
    if (GlobalHelpGui) {
        GlobalHelpGui.Destroy()
        GlobalHelpGui := ""
        return
    }

    currentMode := ComboMode ? "连招模式" : "搓招模式"

    GlobalHelpGui := Gui("+AlwaysOnTop", "般岳宏帮助")
    GlobalHelpGui.SetFont("s9", "Consolas")
    GlobalHelpGui.BackColor := "2d2d30"

    leftText := Format("
    (
    ══════════════════════════
    当前模式: {}
    
    【控制键】
    Home   = 开启/关闭宏
    PgDn   = 切换搓招/连招模式
    Delete = 退出脚本
    PgUp   = 显示此帮助
    Ctrl+PgUp  = 开启/关闭按键显示
    
    ══════════════════════════
    【搓招模式】- 提高操作上限
    ══════════════════════════
    启动状态(闪反/不动如山等)下:
    1 = 狮子吼 (AAE)
    2 = 论道 (EAE)
    3 = 山摇 (EEA)
    4 = 地动 (AEA)
    
    无启动 - 从普攻派生:
    峥嵘A1 → 任意键 = 狮子吼
    峥嵘A1A2 → 1/4=地动, 2/3=狮子吼
    峥嵘A3/A4 → 任意键 = 地动
    崔巍E1/E2 → 任意键 = 山摇
    崔巍E3/E4 → 任意键 = 论道
    
    怒版连招:
    闪反 → 2→1 = 狮子吼·怒
    闪反 → 4→3 = 山摇·怒
    )",
        currentMode)

    rightText := "
    (
    ══════════════════════════
    【连招模式】- 最大化倍率
    ══════════════════════════
    1 = 地动→山摇·怒→狮子吼 
        前置: "手动3A/4A"或"金身格挡反击/闪反/闪反叫阵长按A"+点按A接峥嵘3A后按1" 
        (闪能不足时的最优短轴输出爆发)        
    2 = 论道→狮子吼·怒→山摇
        前置: "手动3E/4E"或"金身格挡反击/闪反/闪反叫阵长按A"+点按E接崔巍3E后按2"
        (闪能不足时的最优短轴聚怪爆发)   
    3 = 地动→山摇·怒→论道→狮子吼·怒
        前置: 闪反/不动如山A后按3 (山摇怒优先)
        (总2086.2%，最高总倍率)
    4 = 论道→狮子吼·怒→地动→山摇·怒 （怒相状态下不建议用,容易触发摧山）
        前置: 闪反/不动如山A后按4 (狮子吼怒优先)(总2086.2%)
    X = 论道→狮子吼·怒→蓄力A (怒吼瞬山，怒相中打失衡前用，类似仪玄瞬大)
        前置："手动3E/4E"或"金身格挡反击/闪反/闪反叫阵长按A"+点按E触发崔巍3E后按X
    
    ══════════════════════════
    【通用功能】
    ══════════════════════════
    侧键4 = 完美取消2怒爆发 (论道前置均可用，需要自行判断释放时机方可完美取消)
    例如: 大招最后砸地开始、连携放冲击波开始、支援和长A进怒相基本立刻就得按...等
    侧键5 = 叫阵
    Shift = 闪反振击上切人 (右键→左键→Shift)
    )"

    GlobalHelpGui.SetFont("s9 cWhite", "Consolas")
    GlobalHelpGui.Add("Text", "x10 y10 w280", leftText)
    GlobalHelpGui.Add("Text", "x300 y10 w280", rightText)

    GlobalHelpGui.SetFont("s10 norm")
    closeBtn := GlobalHelpGui.Add("Button", "x240 y480 w100 h30 Default", "关闭(ESC)")
    closeBtn.OnEvent("Click", (*) => (GlobalHelpGui.Destroy(), GlobalHelpGui := ""))
    GlobalHelpGui.OnEvent("Escape", (*) => (GlobalHelpGui.Destroy(), GlobalHelpGui := ""))

    ; 窗口关闭时清空变量，防止逻辑状态不一致
    GlobalHelpGui.OnEvent("Close", (*) => (GlobalHelpGui := ""))

    GlobalHelpGui.Show("w590 h520")
}

; =================================================================================================
; 3. 初始化与全局热键 (Initialization & Global Hotkeys)
; =================================================================================================

; 启动按键显示 GUI
CreateKeyOverlay()

; 脚本启动提示
ToolTip("般岳宏 v5.0 已启动!`n默认启动连招模式`n可用按键：1/2/3/4/X(仅连招)/鼠标侧键4/5`nPgDn=切换模式 | PgUp=帮助", 100, 100)
SetTimer(() => ToolTip(), -3000)

; --- 全局功能热键 ---

Home:: {
    global MacroEnabled
    MacroEnabled := !MacroEnabled
    ToolTip(MacroEnabled ? "般岳宏: 已开启" : "般岳宏: 已关闭")
    SetTimer(() => ToolTip(), -1500)
}

Delete:: {
    ToolTip("般岳宏: 已退出")
    Sleep(500)
    ExitApp()
}

PgDn:: {
    global ComboMode
    ComboMode := !ComboMode
    if ComboMode {
        ToolTip("连招模式 (1,2,3,4,X)`n最大化倍率，保软弱")
    } else {
        ToolTip("搓招模式 (1,2,3,4)`n提高操作上限")
    }
    SetTimer(() => ToolTip(), -2000)
}

^PgUp:: ToggleKeyOverlay()

PgUp:: ShowHelpGui()

; =================================================================================================
; 4. 游戏内热键配置 (Game Hotkeys)
; =================================================================================================

#HotIf WinActive("ahk_exe ZenlessZoneZero.exe") or WinActive("ahk_exe ZenlessZoneZeroBeta.exe")

; --- 连招中断监听 (仅在连招运行时生效) ---
#HotIf IsComboRunning
~*LShift::
~*RShift::
~*RButton::
~*Space::
~*q::
~*c:: {
    global StopComboRequest := true
    UpdateStatusText("已打断：按下了 " SubStr(A_ThisHotkey, 3))
}
#HotIf

; --- 核心功能键 (需宏开启) ---
#HotIf (WinActive("ahk_exe ZenlessZoneZero.exe") or WinActive("ahk_exe ZenlessZoneZeroBeta.exe")) and MacroEnabled

; [1键] 搓招:狮子吼 / 连招:输出三连
1:: {
    global ComboMode, LastManualKey
    if ComboMode {
        try {
            StartInterruptionMonitor()
            UpdateStatusText("连招1：地动→山摇·怒→狮子吼`n前置：手动3A/4A/金身/闪反/闪反叫阵长按A后点按A接峥嵘3A后按1`n(闪能不足时的最优短轴输出爆发)")
            ; 连招模式: 地动→山摇·怒→狮子吼
            Sleep(50)
            QuickInput("E")
            Sleep(100)
            QuickInput("EE")
            MacroSleep(Key1Delay1)
            QuickInput("A")
            Sleep(100)
            QuickInput("AA")
            MacroSleep(Key1Delay2)
            QuickInput("E")
        } catch Error as e {
            if (e.Message != "ComboInterrupted")
                throw e
        } finally {
            StopInterruptionMonitor()
            SetTimer(ClearStatusText, -1500)
        }
    } else {
        ; 搓招模式: 狮子吼 (AAE)
        if (LastManualKey == 2)
            UpdateStatusText("搓招1：狮子吼·怒 (2→1 论道狮子吼派生)")
        else
            UpdateStatusText("搓招1：直接/启动状态(闪反) + 1 (AAE) = 狮子吼")
        QuickInput("AAE")
        LastManualKey := 1
        SetTimer(ClearStatusText, -1500)
    }
    KeyWait("1")
}

; [2键] 搓招:论道 / 连招:聚怪三连
2:: {
    global ComboMode, LastManualKey
    if ComboMode {
        try {
            StartInterruptionMonitor()
            UpdateStatusText("连招2：论道→狮子吼·怒→山摇`n前置：手动3E/4E/金身/闪反/闪反叫阵长按A后点按E接崔巍3E后按2`n(闪能不足时的最优短轴聚怪爆发)")
            ; 连招模式: 论道→狮子吼·怒→山摇
            Sleep(50)
            QuickInput("A")
            Sleep(100)
            QuickInput("AA")
            MacroSleep(Key2Delay1)
            QuickInput("E")
            Sleep(100)
            QuickInput("EE")
            MacroSleep(Key2Delay2)
            QuickInput("A")
        } catch Error as e {
            if (e.Message != "ComboInterrupted")
                throw e
        } finally {
            StopInterruptionMonitor()
            SetTimer(ClearStatusText, -1500)
        }
    } else {
        ; 搓招模式: 论道 (EAE)
        UpdateStatusText("搓招2：启动状态(闪反) + 2 (EAE) = 论道")
        QuickInput("EAE")
        LastManualKey := 2
        SetTimer(ClearStatusText, -1500)
    }
    KeyWait("2")
}

; [3键] 搓招:山摇 / 连招:地动起手四连 (原Key2)
3:: {
    global ComboMode, LastManualKey
    if ComboMode {
        try {
            StartInterruptionMonitor()
            UpdateStatusText("连招3：地动→山摇·怒→论道→狮子吼·怒 (2086%)`n前置：闪反/不动如山后 | 优先：山摇·怒`n完美时机：闪反立刻按3/不动E第一拳打中")
            ; 连招模式: 地动→山摇·怒→论道→狮子吼·怒
            MacroSleep(XStartDelay)
            Send("{e down}")
            Sleep(XHoldE)
            Send("{e up}")
            CheckInterrupt()
            MacroSleep(XDelay1)
            QuickInput("EEA")
            MacroSleep(XDelay2)
            QuickInput("EAE")
            MacroSleep(XDelay3)
            QuickInput("AAE")
        } catch Error as e {
            if (e.Message != "ComboInterrupted")
                throw e
        } finally {
            StopInterruptionMonitor()
            SetTimer(ClearStatusText, -1500)
        }
    } else {
        ; 搓招模式: 山摇 (EEA)
        if (LastManualKey == 4)
            UpdateStatusText("搓招3：山摇·怒 (4→3 地动山摇派生)")
        else
            UpdateStatusText("搓招3：启动状态(闪反) + 3 (EEA) = 山摇")
        QuickInput("EEA")
        LastManualKey := 3
        SetTimer(ClearStatusText, -1500)
    }
    KeyWait("3")
}

; [4键] 搓招:地动 / 连招:论道起手四连 (原Key3)
4:: {
    global ComboMode, LastManualKey
    if ComboMode {
        try {
            StartInterruptionMonitor()
            UpdateStatusText("连招4：论道→狮子吼·怒→地动→山摇·怒 (2086%)`n前置：闪反/不动如山后 | 优先：狮子吼·怒`n完美时机：闪反立刻按4/不动E第一拳打中")
            ; 连招模式: 论道→狮子吼·怒→地动→山摇·怒
            MacroSleep(CStartDelay)
            Send("{LButton down}")
            Sleep(CHoldA)
            Send("{LButton up}")
            CheckInterrupt()
            MacroSleep(CDelay1)
            QuickInput("AAE")
            MacroSleep(CDelay2)
            QuickInput("AEA")
            MacroSleep(CDelay3)
            QuickInput("EEA")
        } catch Error as e {
            if (e.Message != "ComboInterrupted")
                throw e
        } finally {
            StopInterruptionMonitor()
            SetTimer(ClearStatusText, -1500)
        }
    } else {
        ; 搓招模式: 地动 (AEA)
        UpdateStatusText("搓招4：启动状态(闪反) + 4 (AEA) = 地动")
        QuickInput("AEA")
        LastManualKey := 4
        SetTimer(ClearStatusText, -1500)
    }
    KeyWait("4")
}

; [x键] 怒吼瞬山 (Combo Mode Only)
x:: {
    global ComboMode
    if ComboMode {
        try {
            StartInterruptionMonitor()
            UpdateStatusText("连招X：论道→狮子吼·怒→蓄力A`n前置：手动3E/4E/闪反/叫阵点按E接崔巍3E后")
            Sleep(50)
            QuickInput("A")
            Sleep(100)
            QuickInput("AA")
            MacroSleep(Key2Delay1)
            QuickInput("E")
            Sleep(50)
            Send("{LButton down}")
            MacroSleep(XKeyHoldADelay)
            Send("{LButton up}")

        } catch Error as e {
            if (e.Message != "ComboInterrupted")
                throw e
        } finally {
            StopInterruptionMonitor()
            SetTimer(ClearStatusText, -1500)
        }
    }
    KeyWait("x")
}

; [Shift] 闪反振击上切人 (右键→左键→Shift)
LShift:: {
    try {
        StartInterruptionMonitor()
        UpdateStatusText("Shift：闪反振击上切人 (右键→左键→Shift)")

        ; 临时屏蔽用户左键输入
        Hotkey("*LButton", (*) => "", "On")

        Click("Right")
        MacroSleep(ShiftKeyDelay1)
        Click("Left")
        MacroSleep(ShiftKeyDelay2)
        Send("{LShift}")
    } catch Error as e {
        if (e.Message != "ComboInterrupted")
            throw e
    } finally {
        ; 恢复左键输入
        Hotkey("*LButton", "Off")
        StopInterruptionMonitor()
        SetTimer(ClearStatusText, -1500)
    }
    KeyWait("LShift")
}

; [侧键4] 完美取消2怒爆发
XButton1:: {
    try {
        StartInterruptionMonitor()
        UpdateStatusText("侧键4：完美取消2怒爆发，论道前置均可用")
        QuickInput("EAE")
        MacroSleep(Side4Delay1)
        QuickInput("AAE")
        MacroSleep(Side4Delay2)
        QuickInput("AEA")
        MacroSleep(Side4Delay3)
        QuickInput("EEA")
    } catch Error as e {
        if (e.Message != "ComboInterrupted")
            throw e
    } finally {
        StopInterruptionMonitor()
        SetTimer(ClearStatusText, -1500)
    }
    KeyWait("XButton1")
}

; [侧键5] 叫阵
XButton2:: {
    DoTaunt() ; 优先执行动作，减少 GUI 更新带来的潜在延迟
    UpdateStatusText("侧键5：叫阵 (WAS + 闪避)")
    SetTimer(ClearStatusText, -1500)
    KeyWait("XButton2")
}

#HotIf