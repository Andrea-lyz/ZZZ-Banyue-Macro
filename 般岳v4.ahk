#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================
; 般岳宏 v4.0 - 绝区零 (Zenless Zone Zero)
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
global GlobalLatency := 0         ; 全局延迟补偿(ms)，正式服有延迟时增加此值
global KeyPressDelay := 100       ; 单次按键按下时长(ms)
global KeyIntervalDelay_Manual := 50   ; 搓招模式 - 连续按键间隔(ms)
global KeyIntervalDelay_Combo := 80    ; 连招模式 - 连续按键间隔(ms)
global TauntDirectionDelay := 10  ; 叫阵方向键间隔(ms)

; --- 连招延迟配置 (核心调优区) ---

; [1键] 三连招延迟 (闪能不足时最优)
; 路线: 地动(510%) → 山摇·怒(650.6%) → 狮子吼(307.7%)
global ZComboDelay1 := 1000       ; 地动后 → 山摇·怒 延迟 (等待完美取消)
global ZComboDelay2 := 550        ; 山摇·怒后 → 狮子吼 延迟 (等待完美取消)

; [2键] 四连招延迟 (地动起手，闪反后用)
; 路线: 地动 → 山摇·怒 → 论道 → 狮子吼·怒 (最高总倍率)
global XStartDelay := 100         ; 闪反/不动如山后起手延迟
global XHoldE := 1100             ; 长按E时长 (触发地动)
global XDelay1 := 600             ; 地动 → 山摇·怒 延迟
global XDelay2 := 500             ; 山摇·怒 → 论道 延迟
global XDelay3 := 500             ; 论道 → 狮子吼·怒 延迟

; [3键] 四连招延迟 (论道起手，闪反/不动如山后用)
; 路线: 论道 → 狮子吼·怒 → 地动 → 山摇·怒 (狮子吼怒优先)
global CStartDelay := 0           ; 闪反/不动如山后起手延迟
global CHoldA := 750              ; 长按A时长 (触发论道)
global CDelay1 := 300             ; 论道 → 狮子吼·怒 延迟
global CDelay2 := 350             ; 狮子吼·怒 → 地动 延迟
global CDelay3 := 1150            ; 地动 → 山摇·怒 延迟

; [侧键4] 四连招延迟 (怒相爆发: 狮子吼起手4点山威循环)
; 路线: 狮子吼(起手) → 地动 → 山摇·怒 → 论道
global Side4Delay1 := 100         ; 狮子吼(AAE) → 地动(AEA) 延迟
global Side4Delay2 := 1100        ; 地动(AEA) → 山摇·怒(EEA) 延迟
global Side4Delay3 := 500         ; 山摇·怒(EEA) → 论道(EAE) 延迟

; =================================================================================================
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
    ; 模拟半圈摇杆: 快速单击 W -> A -> S
    SendEvent("{w down}")
    Sleep(TauntDirectionDelay)
    SendEvent("{w up}")
    Sleep(TauntDirectionDelay)

    SendEvent("{a down}")
    Sleep(TauntDirectionDelay)
    SendEvent("{a up}")
    Sleep(TauntDirectionDelay)

    SendEvent("{s down}")
    Sleep(TauntDirectionDelay)
    SendEvent("{s up}")

    ; 鼠标右键闪避
    Sleep(TauntDirectionDelay)
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
    global ComboMode
    currentMode := ComboMode ? "连招模式" : "搓招模式"

    helpGui := Gui("+AlwaysOnTop", "般岳宏帮助")
    helpGui.SetFont("s9", "Consolas")
    helpGui.BackColor := "2d2d30"

    leftText := "
    (
    ══════════════════════════
    当前模式: " currentMode "
    
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
    )"

    rightText := "
    (
    ══════════════════════════
    【连招模式】- 最大化倍率
    ══════════════════════════
    1 = 地动→山摇·怒→狮子吼 
        完美时机：A3最后一拳/A4腿下砸触地前
        (总1468.3%，闪能不足最优)
        前置: 手动AAA/AAAA后按1
    
    2 = 地动→山摇·怒→论道→狮子吼·怒
        (总2086.2%，山摇怒优先)
        前置: 闪反/不动如山后按2
        完美时机：闪反立刻按2/不动E第一拳打中
    
    3 = 论道→狮子吼·怒→地动→山摇·怒
        (总2086.2%，狮子吼怒优先)
        前置: 闪反/不动如山后按3
        完美时机：闪反立刻按3/不动E第一拳打中
    
    ══════════════════════════
    【通用功能】
    ══════════════════════════
    侧键4 = 狮子吼起手→4山威爆发 (最优)
    侧键5 = 叫阵
    
    【倍率参考】
    山摇·怒 650.6% > 狮子吼·怒 600.4%
    > 地动 510% > 山摇 342.9%
    > 论道 325.2% > 狮子吼 307.7%
    )"

    helpGui.SetFont("s9 cWhite", "Consolas")
    helpGui.Add("Text", "x10 y10 w280", leftText)
    helpGui.Add("Text", "x300 y10 w280", rightText)

    helpGui.SetFont("s10 norm")
    closeBtn := helpGui.Add("Button", "x240 y480 w100 h30 Default", "关闭(ESC)")
    closeBtn.OnEvent("Click", (*) => helpGui.Destroy())
    helpGui.OnEvent("Escape", (*) => helpGui.Destroy())

    helpGui.Show("w590 h520")
}

; =================================================================================================
; 3. 初始化与全局热键 (Initialization & Global Hotkeys)
; =================================================================================================

; 启动按键显示 GUI
CreateKeyOverlay()

; 脚本启动提示
ToolTip("般岳宏已启动!`n连招模式`n1=三连 2=四连(地动起) 3=四连(论道起)`nPgDn=切换模式 | PgUp=帮助", 100, 100)
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
        ToolTip("连招模式`n1=Z连招 2=X连招 3=C连招`n(最大化倍率，保软弱)")
    } else {
        ToolTip("搓招模式`n1=狮子吼 2=论道 3=山摇 4=地动`n(提高操作上限)")
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

; [1键] 搓招:狮子吼 / 连招:地动起手三连
1:: {
    global ComboMode, LastManualKey
    if ComboMode {
        try {
            StartInterruptionMonitor()
            UpdateStatusText("连招1：地动→山摇·怒→狮子吼 (1468%)`n前置：3A/4A后 | 适用：闪能不足`n完美时机：A3最后一拳/A4腿下砸触地前")
            ; 连招模式: 地动→山摇·怒→狮子吼
            Sleep(50)
            QuickInput("E")
            Sleep(100)
            QuickInput("EE")
            MacroSleep(ZComboDelay1)
            QuickInput("A")
            Sleep(100)
            QuickInput("AA")
            MacroSleep(ZComboDelay2)
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

; [2键] 搓招:论道 / 连招:地动起手四连
2:: {
    global ComboMode, LastManualKey
    if ComboMode {
        try {
            StartInterruptionMonitor()
            UpdateStatusText("连招2：地动→山摇·怒→论道→狮子吼·怒 (2086%)`n前置：闪反/不动如山后 | 优先：山摇·怒`n完美时机：闪反立刻按2/不动E第一拳打中")
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
        ; 搓招模式: 论道 (EAE)
        UpdateStatusText("搓招2：启动状态(闪反) + 2 (EAE) = 论道")
        QuickInput("EAE")
        LastManualKey := 2
        SetTimer(ClearStatusText, -1500)
    }
    KeyWait("2")
}

; [3键] 搓招:山摇 / 连招:论道起手四连
3:: {
    global ComboMode, LastManualKey
    if ComboMode {
        try {
            StartInterruptionMonitor()
            UpdateStatusText("连招3：论道→狮子吼·怒→地动→山摇·怒 (2086%)`n前置：闪反/不动如山后 | 优先：狮子吼·怒`n完美时机：闪反立刻按3/不动E第一拳打中")
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

; [4键] 搓招:地动 (连招模式下无功能)
4:: {
    global ComboMode, LastManualKey
    if !ComboMode {
        ; 搓招模式: 地动 (AEA)
        UpdateStatusText("搓招4：启动状态(闪反) + 4 (AEA) = 地动")
        QuickInput("AEA")
        LastManualKey := 4
        SetTimer(ClearStatusText, -1500)
    }
    KeyWait("4")
}

; [侧键4] 怒相4点山威爆发 (狮子吼起手)
XButton1:: {
    try {
        StartInterruptionMonitor()
        UpdateStatusText("侧键4：狮子吼→地动→山摇·怒→论道 (1794%)`n怒相4点山威爆发 | 无启动最优")
        QuickInput("AE")           ; 1. 狮子吼 (307.7%) - 消耗1点
        MacroSleep(Side4Delay1)
        QuickInput("AEA")           ; 2. 地动 (510%) - 消耗1点
        MacroSleep(Side4Delay2)
        QuickInput("EEA")           ; 3. 山摇·怒 (650.6%) - 消耗1点
        MacroSleep(Side4Delay3)
        QuickInput("EAE")           ; 4. 论道 (325.2%) - 消耗1点
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
    UpdateStatusText("侧键5：叫阵 (WAS + 闪避)")
    DoTaunt()
    SetTimer(ClearStatusText, -1500)
    KeyWait("XButton2")
}

#HotIf