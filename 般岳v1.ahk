#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================
; 般岳宏 - 绝区零 (Zenless Zone Zero)
; ============================================
; Home = 开启/关闭宏
; Delete = 退出脚本
; PgUp = 显示帮助
; ============================================

; === 宏状态 ===
global MacroEnabled := true       ; 宏开关状态

; === 全局网络延迟补偿 (正式服可能需要调整) ===
global GlobalLatency := 0         ; 全局延迟补偿(ms)，正式服有延迟时增加此值

; === 统一延迟配置区 (方便调试) ===
global KeyPressDelay := 30        ; 单次按键按下时长(ms)
global KeyIntervalDelay := 50     ; 连续按键之间间隔(ms)
global TauntDirectionDelay := 25  ; 叫阵方向键间隔(ms)
global ZKeyDelay := 950           ; Z键怒版延迟(ms) - 论道→狮子吼·怒
global XKeyDelay := 1450          ; X键怒版延迟(ms) - 地动→山摇·怒 (闪避反击后)
global ParryXDelay := 1750        ; 完美格挡后X延迟(ms) - 可单独调整

; === 侧键4连招延迟 (1→2→3→4 完美取消连招) ===
global Side4Delay1 := 500         ; 键1(EAE论道)后→键2(AAE狮子吼)延迟
global Side4Delay2 := 800         ; 键2(AAE狮子吼)后→键3(AEA地动)延迟
global Side4Delay3 := 1400        ; 键3(AEA地动)后→键4(EEA山摇)延迟

; === 游戏按键映射 (根据游戏实际设置调整) ===
global KeyAttack := "LButton"     ; 普攻 - 鼠标左键
global KeyDodge := "RButton"      ; 闪避 - 鼠标右键  
global KeySpecial := "e"          ; 强化/特殊技
global KeyUltimate := "q"         ; 大招
global KeySupport := "Space"      ; 支援/切人

; === 延迟函数 (自动加上全局延迟) ===
MacroSleep(delay) {
    Sleep(delay + GlobalLatency)
}

; === 辅助函数 ===
PressKey(key, duration := KeyPressDelay) {
    Send("{" key " down}")
    Sleep(duration)
    Send("{" key " up}")
}

; 快速键入指令 - 核心函数
QuickInput(sequence) {
    ; sequence 为字符串如 "AAE", "AEA" 等
    Loop Parse, sequence {
        switch A_LoopField {
            case "A": PressKey(KeyAttack)
            case "E": PressKey(KeySpecial)
        }
        if (A_Index < StrLen(sequence))
            Sleep(KeyIntervalDelay)
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

; PgUp - 显示帮助
PgUp:: {
    helpText := "
    (
    ══════════════════════════════════
           般岳宏 - 按键说明
    ══════════════════════════════════
    
    【控制键】
    Home   = 开启/关闭宏
    Delete = 退出脚本
    PgUp   = 显示此帮助
    
    【强化特殊技 - 启动状态(闪反/不动如山等)下使用】
    1 = 论道 (EAE)
    2 = 狮子吼 (AAE)
    3 = 地动 (AEA)
    4 = 山摇 (EEA)

    【无启动 - 从普攻派生】
    峥嵘A1/A2 → 1/2/3/4 = 狮子吼
    峥嵘A3/A4 → 1/2/3/4 = 地动
    崔巍E1/E2 → 1/2/3/4 = 山摇
    崔巍E3/E4 → 1/2/3/4 = 论道
    
    【怒版连招】
    1→2 = 狮子吼·怒
    3→4 = 山摇·怒
    Z   = 论道→狮子吼·怒 (自动)
    X   = 地动→山摇·怒 (闪避反击后)
    C   = 地动→山摇·怒 (完美格挡后)
    
    【鼠标侧键】
    侧键4 = 1→2→3→4 完美取消连招
    侧键5 = 叫阵
    
    【延迟调整】
    正式服有延迟时，修改脚本中的
    GlobalLatency 值 (默认0ms)
    ══════════════════════════════════
    )"
    MsgBox(helpText, "般岳宏帮助", "0x40")
}

; ============================================
; 游戏热键 (受宏开关控制)
; ============================================

; --- 仅在游戏窗口激活且宏开启时生效 ---
#HotIf WinActive("ahk_exe ZenlessZoneZero.exe") or WinActive("ahk_exe ZenlessZoneZeroBeta.exe")
#HotIf (WinActive("ahk_exe ZenlessZoneZero.exe") or WinActive("ahk_exe ZenlessZoneZeroBeta.exe")) and MacroEnabled

; === 数字键 1-4: 单个强化技快速指令 ===
; 键位设计：1→2 = 狮子吼·怒，3→4 = 山摇·怒

; 1 - 论道 (EAE)
1:: {
    QuickInput("EAE")
    KeyWait("1")  ; 防止长按重复触发
}

; 2 - 狮子吼 (AAE) - 论道后接此键触发狮子吼·怒
2:: {
    QuickInput("AAE")
    KeyWait("2")
}

; 3 - 地动 (AEA)
3:: {
    QuickInput("AEA")
    KeyWait("3")
}

; 4 - 山摇 (EEA) - 地动后接此键触发山摇·怒
4:: {
    QuickInput("EEA")
    KeyWait("4")
}

; === Z/X键: 怒版连招（点按触发） ===

; Z - 论道 → 狮子吼·怒 (1→2 带延迟)
z:: {
    QuickInput("EAE")           ; 论道 (键1)
    MacroSleep(ZKeyDelay)       ; Z键专用延迟 + 全局延迟
    QuickInput("AAE")           ; 狮子吼 (键2)
    KeyWait("z")
}

; X - 地动 → 山摇·怒 (3→4 带延迟) - 闪避反击后用
x:: {
    QuickInput("AEA")           ; 地动 (键3)
    MacroSleep(XKeyDelay)       ; X键专用延迟 + 全局延迟
    QuickInput("EEA")           ; 山摇 (键4)
    KeyWait("x")
}

; C - 地动 → 山摇·怒 - 完美格挡(不动如山)后用
c:: {
    QuickInput("AEA")           ; 地动 (键3)
    MacroSleep(ParryXDelay)     ; 完美格挡专用延迟 + 全局延迟
    QuickInput("EEA")           ; 山摇 (键4)
    KeyWait("c")
}

; === 鼠标侧键 ===

; 鼠标侧键4 - 1→2→3→4 完美取消连招
; 路线: 1(EAE论道) → 2(AAE狮子吼怒) → 3(AEA地动) → 4(EEA山摇怒)
XButton1:: {
    QuickInput("EAE")           ; 键1 - 论道
    MacroSleep(Side4Delay1)     ; 延迟1 + 全局延迟
    QuickInput("AAE")           ; 键2 - 狮子吼(怒)
    MacroSleep(Side4Delay2)     ; 延迟2 + 全局延迟
    QuickInput("AEA")           ; 键3 - 地动
    MacroSleep(Side4Delay3)     ; 延迟3 + 全局延迟
    QuickInput("EEA")           ; 键4 - 山摇(怒)
    KeyWait("XButton1")
}

; 鼠标侧键5 - 叫阵
XButton2:: {
    DoTaunt()
    KeyWait("XButton2")
}

#HotIf

; ============================================
; 脚本启动提示
; ============================================
ToolTip("般岳宏已启动!`nHome=开关 | PgUp=帮助 | Del=退出", 100, 100)
SetTimer(() => ToolTip(), -3000)