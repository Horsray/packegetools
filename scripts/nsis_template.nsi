; ===========================
; HueyingAI Photoshop 插件 安装器（简化稳定版 · 修正版）
; 保存为: installer.nsi
; 准备: 将你的插件文件放在脚本同级目录的 payload\ 下
; 编译: makensis installer.nsi
; ===========================

Unicode True
RequestExecutionLevel admin

!include "MUI2.nsh"
!include "FileFunc.nsh"
!include "nsDialogs.nsh"

; ---------- 基本信息 ----------
!define APP_NAME        "HueyingAI Photoshop 插件"
!define APP_PUBLISHER   "Hueying Studio"
!define APP_VERSION     "1.0.0"
!define APP_DIRNAME     "HueyingAI"  ; 安装到 Plug-ins 下的目录名
!define OUT_FILENAME    "HueyingAI_Plugin_Installer_${APP_VERSION}.exe"

Name        "${APP_NAME}"
OutFile     "${OUT_FILENAME}"
BrandingText "Installer • ${APP_PUBLISHER}"

; InstallDir 只是占位；真正安装路径用 $PSPATH 拼出来
InstallDir  "$PROGRAMFILES\${APP_DIRNAME}"

; ---------- UI 页面 ----------
!define MUI_ABORTWARNING
!insertmacro MUI_PAGE_WELCOME
Page custom SelectPhotoshopPage LeaveSelectPhotoshopPage
Page custom PreInstallConfirm
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_LANGUAGE "SimpChinese"

; ---------- 变量 ----------
Var PSPATH
Var _found
Var _tmp
Var PSCount
Var PSListFile
Var HWND_PS_COMBO
Var HWND_PS_INFO
Var HWND_PS_HELP

; ---------- Photoshop 目录收集 ----------
Function PathAlreadyRecorded
  Push $0
  Push $1
  Push $2
  StrCpy $_found "0"
  StrCpy $1 1
PathAlreadyRecorded_Loop:
  IntCmp $1 $PSCount PathAlreadyRecorded_Done PathAlreadyRecorded_Done PathAlreadyRecorded_Continue
PathAlreadyRecorded_Continue:
  ReadINIStr $2 $PSListFile "Photoshop" "Path$1"
  StrCmp $2 "" PathAlreadyRecorded_Next
  StrCmp $2 $_tmp PathAlreadyRecorded_Found PathAlreadyRecorded_Next
PathAlreadyRecorded_Next:
  IntOp $1 $1 + 1
  Goto PathAlreadyRecorded_Loop
PathAlreadyRecorded_Found:
  StrCpy $_found "1"
PathAlreadyRecorded_Done:
  Pop $2
  Pop $1
  Pop $0
FunctionEnd

Function AddCandidate
  Pop $0
  Push $1
  StrCmp $0 "" AddCandidate_Done
  IfFileExists "$0\Photoshop.exe" 0 AddCandidate_Done
  StrCpy $_tmp "$0"
  Call PathAlreadyRecorded
  StrCmp $_found "1" AddCandidate_Done
  IntOp $PSCount $PSCount + 1
  WriteINIStr $PSListFile "Photoshop" "Path$PSCount" "$0"
  StrCmp $PSPATH "" 0 +2
    StrCpy $PSPATH "$0"
AddCandidate_Done:
  Pop $1
FunctionEnd

Function NormalizeFromTmp
  StrCmp $_tmp "" Normalize_Done
  IfFileExists "$_tmp\*.*" 0 Normalize_CheckFile
    Push $_tmp
    Call AddCandidate
    Goto Normalize_Done
Normalize_CheckFile:
  IfFileExists "$_tmp" 0 Normalize_Done
    ${GetParent} "$_tmp" $0
    StrCmp $0 "" Normalize_Done
    Push $0
    Call AddCandidate
Normalize_Done:
FunctionEnd

Function FillPSCombo
  Pop $0
  Push $1
  Push $2
  StrCpy $1 1
FillPSCombo_Loop:
  IntCmp $1 $PSCount FillPSCombo_Done FillPSCombo_Done FillPSCombo_Continue
FillPSCombo_Continue:
  ReadINIStr $2 $PSListFile "Photoshop" "Path$1"
  StrCmp $2 "" FillPSCombo_Next
  ${NSD_CB_AddString} $0 "$2"
FillPSCombo_Next:
  IntOp $1 $1 + 1
  Goto FillPSCombo_Loop
FillPSCombo_Done:
  Pop $2
  Pop $1
FunctionEnd

Function OnPSComboChange
  Pop $0
  ${NSD_CB_GetText} $HWND_PS_COMBO $PSPATH
FunctionEnd

Function OnSelectCustomPS
  Pop $0
  nsDialogs::SelectFolderDialog "选择 Photoshop 安装目录（包含 Photoshop.exe 的那一层）" "$PROGRAMFILES\Adobe"
  Pop $1
  StrCmp $1 "" OnSelectCustomPS_Done
  IfFileExists "$1\Photoshop.exe" 0 OnSelectCustomPS_Invalid
  StrCpy $PSPATH "$1"
  StrCpy $_tmp "$1"
  Call PathAlreadyRecorded
  StrCmp $_found "1" OnSelectCustomPS_Existing
  IntOp $PSCount $PSCount + 1
  WriteINIStr $PSListFile "Photoshop" "Path$PSCount" "$PSPATH"
  ${NSD_CB_AddString} $HWND_PS_COMBO "$PSPATH"
  EnableWindow $HWND_PS_COMBO 1
OnSelectCustomPS_Existing:
  ${NSD_CB_SelectString} $HWND_PS_COMBO "$PSPATH"
  ${NSD_SetText} $HWND_PS_INFO "请选择要安装的 Photoshop："
  Goto OnSelectCustomPS_Done
OnSelectCustomPS_Invalid:
  MessageBox MB_ICONSTOP "选择的目录下未找到 Photoshop.exe，请重新选择。"
OnSelectCustomPS_Done:
FunctionEnd

Function SelectPhotoshopPage
  Push $R0
  StrCpy $R0 $PSPATH
  Call FindPhotoshop
  IfFileExists "$R0\Photoshop.exe" 0 SelectPhotoshop_Create
    Push $R0
    Call AddCandidate
    StrCpy $PSPATH "$R0"
SelectPhotoshop_Create:
  nsDialogs::Create 1018
  Pop $0
  ${If} $0 == error
    Pop $R0
    Abort
  ${EndIf}

  ${NSD_CreateLabel} 0 0 100% 18u "请选择要安装的 Photoshop："
  Pop $HWND_PS_INFO

  ${NSD_CreateDropList} 0 20u 100% 12u ""
  Pop $HWND_PS_COMBO
  Push $HWND_PS_COMBO
  Call FillPSCombo
  ${NSD_OnChange} $HWND_PS_COMBO OnPSComboChange

  ${NSD_CreateButton} 0 40u 50% 14u "浏览其他版本..."
  Pop $0
  ${NSD_OnClick} $0 OnSelectCustomPS

  ${NSD_CreateLabel} 0 60u 100% 30u "若列表为空或想安装到其他 Photoshop，请点击“浏览其他版本...”并选择包含 Photoshop.exe 的目录。"
  Pop $HWND_PS_HELP

  IntCmp $PSCount 0 SelectPhotoshop_NoList SelectPhotoshop_HasList SelectPhotoshop_HasList
SelectPhotoshop_HasList:
  StrCmp $PSPATH "" SelectPhotoshop_SetFirst
  Goto SelectPhotoshop_DoSelect
SelectPhotoshop_SetFirst:
  ReadINIStr $PSPATH $PSListFile "Photoshop" "Path1"
SelectPhotoshop_DoSelect:
  ${NSD_CB_SelectString} $HWND_PS_COMBO "$PSPATH"
  ${NSD_CB_GetText} $HWND_PS_COMBO $PSPATH
  ${NSD_SetText} $HWND_PS_INFO "请选择要安装的 Photoshop："
  Goto SelectPhotoshop_Show
SelectPhotoshop_NoList:
  EnableWindow $HWND_PS_COMBO 0
  StrCpy $PSPATH ""
  ${NSD_SetText} $HWND_PS_INFO "未检测到已安装的 Photoshop，请点击下方按钮手动选择。"
SelectPhotoshop_Show:
  nsDialogs::Show
  Pop $R0
FunctionEnd

Function LeaveSelectPhotoshopPage
  ${NSD_CB_GetText} $HWND_PS_COMBO $PSPATH
  StrCmp "$PSPATH" "" LeaveSelectPhotoshop_NeedChoose
  IfFileExists "$PSPATH\Photoshop.exe" 0 LeaveSelectPhotoshop_Invalid
  Return
LeaveSelectPhotoshop_NeedChoose:
  MessageBox MB_ICONEXCLAMATION "请选择一个 Photoshop 安装目录，或点击“浏览其他版本...”手动选择。"
  Abort
LeaveSelectPhotoshop_Invalid:
  MessageBox MB_ICONSTOP "所选目录下未找到 Photoshop.exe，请重新选择。"
  Abort
FunctionEnd

Function PreInstallConfirm
  nsDialogs::Create 1018
  Pop $0
  ${If} $0 == error
    Abort
  ${EndIf}

  ${NSD_CreateLabel} 0 0 100% 30u "将插件安装到：$PSPATH$$
确认无误后点击“下一步”开始安装。"
  Pop $1

  nsDialogs::Show
FunctionEnd

; ---------- 查找 Photoshop ----------
Function FindPhotoshop
  InitPluginsDir
  StrCpy $PSListFile "$PLUGINSDIR\pspaths.ini"
  Delete "$PSListFile"
  StrCpy $PSCount 0
  StrCpy $PSPATH ""
  StrCpy $_tmp ""

  SetRegView 64
  StrCpy $0 0
Find_HKLM64_Loop:
  ClearErrors
  EnumRegKey $1 HKLM "SOFTWARE\Adobe\Photoshop" $0
  IfErrors Find_HKCU64_Start
  ReadRegStr $_tmp HKLM "SOFTWARE\Adobe\Photoshop\$1\ApplicationPath" ""
  Call NormalizeFromTmp
  IntOp $0 $0 + 1
  Goto Find_HKLM64_Loop

Find_HKCU64_Start:
  StrCpy $0 0
Find_HKCU64_Loop:
  ClearErrors
  EnumRegKey $1 HKCU "SOFTWARE\Adobe\Photoshop" $0
  IfErrors Check_AppPaths64
  ReadRegStr $_tmp HKCU "SOFTWARE\Adobe\Photoshop\$1\ApplicationPath" ""
  Call NormalizeFromTmp
  IntOp $0 $0 + 1
  Goto Find_HKCU64_Loop

Check_AppPaths64:
  ReadRegStr $_tmp HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Photoshop.exe" ""
  Call NormalizeFromTmp
  ReadRegStr $_tmp HKCU "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Photoshop.exe" ""
  Call NormalizeFromTmp

  SetRegView 32
  StrCpy $0 0
Find_HKLM32_Loop:
  ClearErrors
  EnumRegKey $1 HKLM "SOFTWARE\Adobe\Photoshop" $0
  IfErrors Find_HKCU32_Start
  ReadRegStr $_tmp HKLM "SOFTWARE\Adobe\Photoshop\$1\ApplicationPath" ""
  Call NormalizeFromTmp
  IntOp $0 $0 + 1
  Goto Find_HKLM32_Loop

Find_HKCU32_Start:
  StrCpy $0 0
Find_HKCU32_Loop:
  ClearErrors
  EnumRegKey $1 HKCU "SOFTWARE\Adobe\Photoshop" $0
  IfErrors Check_AppPaths32
  ReadRegStr $_tmp HKCU "SOFTWARE\Adobe\Photoshop\$1\ApplicationPath" ""
  Call NormalizeFromTmp
  IntOp $0 $0 + 1
  Goto Find_HKCU32_Loop

Check_AppPaths32:
  ReadRegStr $_tmp HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Photoshop.exe" ""
  Call NormalizeFromTmp
  ReadRegStr $_tmp HKCU "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Photoshop.exe" ""
  Call NormalizeFromTmp
FunctionEnd
; ---------- 安装前置 ----------
; 不在 .onInit 里做任何检测或弹窗，避免启动即闪退
Function .onInit
FunctionEnd


; ---------- 安装 ----------
Section "Install"
  SetShellVarContext all

  ; 进入安装阶段再兜底检测（仅当前面页面未选定时）
  StrCmp "$PSPATH" "" 0 +3
    Call FindPhotoshop
    StrCmp "$PSPATH" "" 0 +5

  ; 若仍未检测到，则提示手动选择；循环直到选对或取消
  StrCmp "$PSPATH" "" 0 +5
    MessageBox MB_ICONEXCLAMATION|MB_OKCANCEL "未能自动找到 Photoshop 安装目录。是否手动选择？$\r$\n（请选择包含 Photoshop.exe 的目录）" IDCANCEL _abort_install
    nsDialogs::SelectFolderDialog "选择 Photoshop 安装目录（包含 Photoshop.exe 的那一层）" "$PROGRAMFILES\Adobe"
    Pop $PSPATH
    StrCmp "$PSPATH" "" _abort_install
    IfFileExists "$PSPATH\Photoshop.exe" 0 _retry_select

  ; 到这里 $PSPATH 一定有效
  DetailPrint "使用 Photoshop 目录：$PSPATH"

  ; 安装到：<PS>\Plug-ins\${APP_DIRNAME}
  StrCpy $INSTDIR "$PSPATH\Plug-ins\${APP_DIRNAME}"
  CreateDirectory "$INSTDIR"
  SetOutPath "$INSTDIR"
  File /r "payload\*.*"

  ; 写入卸载器
  WriteUninstaller "$INSTDIR\Uninstall.exe"

  DetailPrint "已安装到：$INSTDIR"
  Goto _end

_retry_select:
  MessageBox MB_ICONSTOP "选择的目录下未找到 Photoshop.exe，请重试。"
  Goto -6  ; 回到 MessageBox 询问是否手选

_abort_install:
  MessageBox MB_ICONINFORMATION "已取消安装。"
  Abort

_end:
SectionEnd


; ---------- 卸载 ----------
Section "Uninstall"
  SetShellVarContext all
  RMDir /r "$INSTDIR"
  DetailPrint "已卸载：$INSTDIR"
SectionEnd
