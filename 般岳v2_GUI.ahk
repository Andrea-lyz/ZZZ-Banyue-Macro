#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================
; 般岳宏 - 绝区零 (Zenless Zone Zero)
; ============================================
; Home = 开启/关闭宏
; PgDn = 切换搓招/连招模式
; Delete = 退出脚本
; PgUp = 显示帮助
; ============================================

; === 宏状态 ===
global MacroEnabled := true       ; 宏开关状态
global ComboMode := true          ; false=搓招模式, true=连招模式(默认)
global KeyOverlayGui := ""        ; 按键显示GUI对象
global KeyControls := Map()       ; 按键控件集合
global StatusTextCtrl := ""       ; 状态文本控件
global LastManualKey := 0         ; 上一次搓招按键
global KeyOverlayEnabled := false ; 按键显示开关 (默认关闭)

; === 全局网络延迟补偿 (正式服可能需要调整) ===
global GlobalLatency := 0         ; 全局延迟补偿(ms)，正式服有延迟时增加此值

; === 统一延迟配置区 (方便调试) ===
global KeyPressDelay := 100        ; 单次按键按下时长(ms)
global KeyIntervalDelay_Manual := 50   ; 搓招模式 - 连续按键间隔(ms)
global KeyIntervalDelay_Combo := 200    ; 连招模式 - 连续按键间隔(ms)
global TauntDirectionDelay := 25  ; 叫阵方向键间隔(ms)
global ZKeyDelay := 800           ; Z键怒版延迟(ms) - 论道→狮子吼·怒
global XKeyDelay := 1450          ; X键怒版延迟(ms) - 地动→山摇·怒 (闪避反击后)
global ParryXDelay := 1750        ; 完美格挡后X延迟(ms) - 可单独调整

; === 侧键4连招延迟 (怒相爆发: 狮子吼起手4点山威循环) ===
; 顺序: 狮子吼(起手) → 地动 → 山摇·怒 → 论道
global Side4Delay1 := 20           ; 狮子吼(AAE)→地动(AEA)延迟
global Side4Delay2 := 850          ; 地动(AEA)→山摇·怒(EEA)延迟
global Side4Delay3 := 300          ; 山摇·怒(EEA)→论道(EAE)延迟

; === 2键四连招延迟 (地动起手，闪反后用) ===
; 2路线: 地动→山摇·怒→论道→狮子吼·怒 (最高总倍率)
; 前置: 闪反后按X (宏自动长按E触发地动)
; 宏序列: 长按E(地动) → EEA(山摇怒) → EAE(论道) → AAE(狮子吼怒)
global XStartDelay := 80          ; 闪反/不动如山后起手延迟 (±5ms调整手感)
global XHoldE := 1100             ; 长按E时长 (触发地动)
global XDelay1 := 275             ; 地动→山摇·怒延迟
global XDelay2 := 275             ; 山摇·怒→论道延迟
global XDelay3 := 275             ; 论道→狮子吼·怒延迟

; === 3键四连招延迟 (论道起手，闪反/不动如山后用) ===
; 3路线: 论道→狮子吼·怒→地动→山摇·怒 (狮子吼怒优先)
; 前置: 闪反/不动如山后按C (宏自动长按A触发论道)
; 宏序列: 长按A(论道) → AAE(狮子吼怒) → AEA(地动) → EEA(山摇怒)
global CStartDelay := 0          ; 闪反/不动如山后起手延迟 (±5ms调整手感)
global CHoldA := 750              ; 长按A时长 (触发论道)
global CDelay1 := 30              ; 论道→狮子吼·怒延迟
global CDelay2 := 50             ; 狮子吼·怒→地动延迟
global CDelay3 := 850             ; 地动→山摇·怒延迟

; === 1键三连招延迟 (闪能不足时最优) ===
; 1路线: 地动(510%)→山摇·怒(650.6%)→狮子吼(307.7%) = 总1468.3%
; 前置: 手动AAA或AAAA(峥嵘A3/A4)后按Z
; 宏序列: E(地动)+EE(预输入) → [delay] → A(山摇怒)+AA(预输入) → [delay] → E(狮子吼)
global ZComboDelay1 := 850       ; 地动后→山摇·怒延迟 (等待完美取消)
global ZComboDelay2 := 500        ; 山摇·怒后→狮子吼延迟 (等待完美取消)

; === 游戏按键映射 (根据游戏实际设置调整) ===
global KeyAttack := "LButton"     ; 普攻 - 鼠标左键
global KeyDodge := "RButton"      ; 闪避 - 鼠标右键
global KeySpecial := "e"          ; 强化/特殊技
global KeyUltimate := "q"         ; 大招
global KeySupport := "Space"      ; 支援/切人

; === 连招中断监控 (Hotkey 方式 - 更灵敏) ===
global IsComboRunning := false
global StopComboRequest := false

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

; 仅在连招运行时生效的中断热键
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

; === 延迟函数 (自动加上全局延迟) ===
MacroSleep(delay) {
    Sleep(delay + GlobalLatency)
    CheckInterrupt()
}

; === 辅助函数 ===
PressKey(key, duration := KeyPressDelay) {
    Send("{" key " down}")
    Sleep(duration)
    Send("{" key " up}")
}

; 快速键入指令 - 核心函数
QuickInput(sequence) {
    global ComboMode, KeyIntervalDelay_Manual, KeyIntervalDelay_Combo
    ; 根据模式选择延迟
    interval := ComboMode ? KeyIntervalDelay_Combo : KeyIntervalDelay_Manual
    ; sequence 为字符串如 "AAE", "AEA" 等
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

; 叫阵 - 半圈方向键 + 闪避 (was顺序)
DoTaunt() {
    ; 模拟半圈摇杆: 快速单击 W -> A -> S
    ; 使用 SendEvent 确保游戏能识别按键

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

; ============================================
; 按键显示 GUI 启动
; ============================================
CreateKeyOverlay()

; ============================================
; 全局热键 (不受宏开关影响)
; ============================================

; Home - 开启/关闭宏
Home:: {
    global MacroEnabled
    MacroEnabled := !MacroEnabled
    if MacroEnabled {
        ToolTip("般岳宏: 已开启")
    } else {
        ToolTip("般岳宏: 已关闭")
    }
    SetTimer(() => ToolTip(), -1500)
}

; Delete - 退出脚本
Delete:: {
    ToolTip("般岳宏: 已退出")
    Sleep(500)
    ExitApp()
}

; PgDn - 切换搓招/连招模式
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

; Ctrl+PgUp - 开启/关闭按键显示
^PgUp:: {
    ToggleKeyOverlay()
}

ToggleKeyOverlay() {
    global KeyOverlayEnabled, KeyOverlayGui
    KeyOverlayEnabled := !KeyOverlayEnabled
    if KeyOverlayEnabled {
        if KeyOverlayGui
            KeyOverlayGui.Show("NoActivate x100 y100 w360 h270")
        ToolTip("按键显示: 已开启")
    } else {
        if KeyOverlayGui
            KeyOverlayGui.Hide()
        ToolTip("按键显示: 已关闭")
    }
    SetTimer(() => ToolTip(), -1500)
}

; PgUp - 显示帮助
PgUp:: {
    global ComboMode
    currentMode := ComboMode ? "连招模式" : "搓招模式"

    ; 创建自定义GUI窗口实现两列显示
    helpGui := Gui("+AlwaysOnTop", "般岳宏帮助")
    helpGui.SetFont("s9", "Consolas")
    helpGui.BackColor := "2d2d30"

    ; 左列内容
    leftText := "
    (
══════════════════════════
当前模式: " currentMode "

【控制键】
Home   = 开启/关闭宏
PgDn   = 切换搓招/连招模式
Delete = 退出脚本
PgUp   = 显示此帮助
Ctrl+PgUp  = 开启/关闭按键显示 （悬浮窗可拖动）

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

    ; 右列内容
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

【延迟调整】
修改 GlobalLatency 值 (默认0ms)
    )"

    ; 添加两列文本
    helpGui.SetFont("s9 cWhite", "Consolas")
    helpGui.Add("Text", "x10 y10 w280", leftText)
    helpGui.Add("Text", "x300 y10 w280", rightText)

    ; 添加关闭按钮
    helpGui.SetFont("s10 norm") ; 恢复默认字体样式，避免按钮点击问题
    closeBtn := helpGui.Add("Button", "x240 y480 w100 h30 Default", "关闭(ESC)")
    closeBtn.OnEvent("Click", (*) => helpGui.Destroy())

    ; ESC关闭
    helpGui.OnEvent("Escape", (*) => helpGui.Destroy())

    helpGui.Show("w590 h520")
}

; ============================================
; 游戏热键 (受宏开关控制)
; ============================================

; --- 仅在游戏窗口激活且宏开启时生效 ---
#HotIf WinActive("ahk_exe ZenlessZoneZero.exe") or WinActive("ahk_exe ZenlessZoneZeroBeta.exe")
#HotIf (WinActive("ahk_exe ZenlessZoneZero.exe") or WinActive("ahk_exe ZenlessZoneZeroBeta.exe")) and MacroEnabled

; === 数字键 1-4: 根据模式切换功能 ===

; 1 - 搓招:狮子吼(AAE) / 连招:Z三连招
1:: {
    global ComboMode, LastManualKey
    if ComboMode {
        try {
            StartInterruptionMonitor()
            UpdateStatusText("连招1：地动→山摇·怒→狮子吼 (1468%)`n前置：3A/4A后 | 适用：闪能不足`n完美时机：A3最后一拳/A4腿下砸触地前")
            ; 连招模式: Z三连招 (地动→山摇·怒→狮子吼)
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

; 2 - 搓招:论道(EAE) / 连招:X四连招
2:: {
    global ComboMode, LastManualKey
    if ComboMode {
        try {
            StartInterruptionMonitor()
            UpdateStatusText("连招2：地动→山摇·怒→论道→狮子吼·怒 (2086%)`n前置：闪反/不动如山后 | 优先：山摇·怒`n完美时机：闪反立刻按2/不动E第一拳打中")
            ; 连招模式: X四连招 (地动→山摇·怒→论道→狮子吼·怒)
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

; 3 - 搓招:山摇(EEA) / 连招:C四连招
3:: {
    global ComboMode, LastManualKey
    if ComboMode {
        try {
            StartInterruptionMonitor()
            UpdateStatusText("连招3：论道→狮子吼·怒→地动→山摇·怒 (2086%)`n前置：闪反/不动如山后 | 优先：狮子吼·怒`n完美时机：闪反立刻按3/不动E第一拳打中")
            ; 连招模式: C四连招 (论道→狮子吼·怒→地动→山摇·怒)
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

; 4 - 搓招:地动(AEA) / 连招模式下无功能
4:: {
    global ComboMode, LastManualKey
    if !ComboMode {
        ; 搓招模式: 地动 (AEA)
        UpdateStatusText("搓招4：启动状态(闪反) + 4 (AEA) = 地动")
        QuickInput("AEA")
        LastManualKey := 4
        SetTimer(ClearStatusText, -1500)
    }
    ; 连招模式下4键无功能
    KeyWait("4")
}

; === 鼠标侧键 ===

; 鼠标侧键4 - 怒相4点山威爆发 (狮子吼起手)
; 路线: 狮子吼(起手) → 地动 → 山摇·怒 → 论道
; 总倍率约 1794% (无启动状态下最优)
; 鼠标侧键4 - 怒相4点山威爆发 (狮子吼起手)
; 路线: 狮子吼(起手) → 地动 → 山摇·怒 → 论道
; 总倍率约 1794% (无启动状态下最优)
XButton1:: {
    try {
        StartInterruptionMonitor()
        UpdateStatusText("侧键4：狮子吼→地动→山摇·怒→论道 (1794%)`n怒相4点山威爆发 | 无启动最优")
        QuickInput("AAE")           ; 1. 狮子吼 (307.7%) - 消耗1点
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

; 鼠标侧键5 - 叫阵
XButton2:: {
    UpdateStatusText("侧键5：叫阵 (WAS + 闪避)")
    DoTaunt()
    SetTimer(ClearStatusText, -1500)
    KeyWait("XButton2")
}

#HotIf

; ============================================
; 脚本启动提示
; ============================================
ToolTip("般岳宏已启动!`n连招模式`n1=三连 2=四连(地动起) 3=四连(论道起)`nPgDn=切换模式 | PgUp=帮助", 100, 100)
SetTimer(() => ToolTip(), -3000)

; ============================================
; 按键显示 GUI 函数
; ============================================

CreateKeyOverlay() {
    global KeyOverlayGui, KeyControls
    KeyOverlayGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner", "按键显示")
    KeyOverlayGui.BackColor := "1e1e1e"
    KeyOverlayGui.SetFont("s10 bold", "Verdana")

    ; 样式辅助函数
    AddKey := "w50 h50 center 0x200 cWhite Background333333 border"

    ; --- 键盘区 (左侧) ---
    ; 第一排: 1 2 3 4
    KeyControls["1"] := KeyOverlayGui.Add("Text", "x10 y10 " AddKey, "1")
    KeyControls["2"] := KeyOverlayGui.Add("Text", "x+5 " AddKey, "2")
    KeyControls["3"] := KeyOverlayGui.Add("Text", "x+5 " AddKey, "3")
    KeyControls["4"] := KeyOverlayGui.Add("Text", "x+5 " AddKey, "4")

    ; 第二排: Q E
    KeyControls["q"] := KeyOverlayGui.Add("Text", "x10 y+5 " AddKey, "Q")
    KeyControls["e"] := KeyOverlayGui.Add("Text", "x+60 " AddKey, "E")

    ; 第三排: Shift Space
    KeyControls["LShift"] := KeyOverlayGui.Add("Text", "x10 y+5 w105 h40 center 0x200 cWhite Background333333 border",
        "Shift")
    KeyControls["Space"] := KeyOverlayGui.Add("Text", "x+5 w105 h40 center 0x200 cWhite Background333333 border",
        "Space")

    ; --- 鼠标区 (右侧) ---
    ; 第一排: LMB RMB
    KeyControls["LButton"] := KeyOverlayGui.Add("Text", "x240 y10 " AddKey, "LMB")
    KeyControls["RButton"] := KeyOverlayGui.Add("Text", "x+5 " AddKey, "RMB")

    ; 第二排: M4 M5
    KeyControls["XButton1"] := KeyOverlayGui.Add("Text", "x240 y+5 " AddKey, "M4")
    KeyControls["XButton2"] := KeyOverlayGui.Add("Text", "x+5 " AddKey, "M5")

    ; 拖动支持 (点击背景或控件移动)
    DragFunc := (*) => PostMessage(0xA1, 2, 0, , "ahk_id " KeyOverlayGui.Hwnd)
    OnMessage(0x0201, (wParam, lParam, msg, hwnd) => hwnd = KeyOverlayGui.Hwnd ? PostMessage(0xA1, 2, 0, , "ahk_id " hwnd
    ) : "")
    for keyName, ctrl in KeyControls {
        ctrl.OnEvent("Click", DragFunc)
    }

    ; --- 状态显示区 ---
    KeyOverlayGui.SetFont("s11 bold cWhite", "Microsoft YaHei")
    ; 使用绝对坐标 y175 避免被上方控件遮挡 (Row3 Bottom approx 160)
    global StatusTextCtrl := KeyOverlayGui.Add("Text", "x10 y175 w340 h80 cGray Background1e1e1e Wrap", "等待指令...")

    if KeyOverlayEnabled {
        KeyOverlayGui.Show("NoActivate x100 y100 w360 h270")
    }

    ; 启动定时器更新状态 (16ms approx 60fps)
    SetTimer(UpdateKeyOverlay, 16)
}

UpdateKeyOverlay() {
    global KeyControls

    for keyName, ctrl in KeyControls {
        ; 检查物理按键状态 (P)
        if GetKeyState(keyName, "P") {
            ctrl.Opt("+BackgroundFF9900 +cBlack") ; 按下时: 橙底黑字
        } else {
            ctrl.Opt("+Background333333 +cWhite") ; 默认: 深灰底白字
        }
    }
}

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
