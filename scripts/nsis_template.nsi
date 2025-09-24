; ======== NSIS TEMPLATE (Windows installer) ========
!include "MUI2.nsh"
!include "nsDialogs.nsh"
!include "FileFunc.nsh"
!include "LogicLib.nsh"
!include "x64.nsh"

!ifndef CB_FINDSTRINGEXACT
!define CB_FINDSTRINGEXACT 0x0158
!endif

Unicode true
RequestExecutionLevel admin

; --------- Defines (filled by main.js via string replace) ----------
!define APP_NAME_FILE "__APP_NAME_FILE__"
!define APP_DIRNAME  "__APP_DIRNAME__"
!define APP_VERSION   __APP_VERSION__
!define APP_VERSION_4 __APP_VERSION_4__
!define APP_PUBLISHER "__APP_PUBLISHER__"
!define PAYLOAD_DIR   "__PAYLOAD_DIR__"

; 显示用名称（main.js 已做转义，这里直接放进引号）
Name "__APP_NAME__"

; 生成的安装器文件名（仅 ASCII）
OutFile "dist\\Setup-__APP_NAME_FILE__-__APP_VERSION__.exe"
SetCompressor /SOLID lzma
CRCCheck on
VIProductVersion "${APP_VERSION_4}"
VIAddVersionKey "FileDescription" "__APP_NAME__ 安装程序"
VIAddVersionKey "ProductName" "__APP_NAME__"
VIAddVersionKey "ProductVersion" "${APP_VERSION}"
VIAddVersionKey "CompanyName" "${APP_PUBLISHER}"
VIAddVersionKey "OriginalFilename" "Setup-__APP_NAME_FILE__-__APP_VERSION__.exe"
VIAddVersionKey "FileVersion" "${APP_VERSION}"
VIAddVersionKey "LegalCopyright" "Copyright (C) ${APP_PUBLISHER}"
VIAddVersionKey "Comments" "__APP_NAME__ Windows 安装器"

; --------- Variables ----------
Var TARGET_DIR
Var hCombo
Var firstItem

!define UXP_FALLBACK "$LOCALAPPDATA\\Adobe\\UXP\\Plugins\\External\\__APP_DIRNAME__"

!macro ADD_REG_STR ROOT KEY VALUE
  ClearErrors
  ReadRegStr $7 ${ROOT} "${KEY}" "${VALUE}"
  IfErrors +3
  StrCpy $0 $7
  Call AddPSItem
!macroend

!macro ENUM_REG_VALUES ROOT KEY ID
  StrCpy $8 0
${ID}_loop:
  EnumRegValue $9 ${ROOT} "${KEY}" $8
  StrCmp $9 "" ${ID}_done
  !insertmacro ADD_REG_STR ${ROOT} "${KEY}" "$9"
  IntOp $8 $8 + 1
  Goto ${ID}_loop
${ID}_done:
!macroend

!macro PROCESS_PS_KEY ROOT KEY ID
  !insertmacro ADD_REG_STR ${ROOT} "${KEY}" ""
  !insertmacro ADD_REG_STR ${ROOT} "${KEY}" "ApplicationPath"
  !insertmacro ADD_REG_STR ${ROOT} "${KEY}" "InstallPath"
  !insertmacro ADD_REG_STR ${ROOT} "${KEY}" "InstallPathMT"
  !insertmacro ADD_REG_STR ${ROOT} "${KEY}" "PluginInstallPath"
  !insertmacro ADD_REG_STR ${ROOT} "${KEY}" "PluginPath"
  !insertmacro ADD_REG_STR ${ROOT} "${KEY}" "PluginsPath"
  !insertmacro ADD_REG_STR ${ROOT} "${KEY}" "PluginsRoot"
  !insertmacro ADD_REG_STR ${ROOT} "${KEY}" "ParentPath"
  !insertmacro ADD_REG_STR ${ROOT} "${KEY}" "Path"
  !insertmacro ENUM_REG_VALUES ${ROOT} "${KEY}" ${ID}
!macroend

; --------- Pages ----------
Page custom PageSelectPS PageSelectPS_Leave
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_LANGUAGE "SimpChinese"

; --------- Helper: 去引号 ---------
Function _TrimQuotes
  Exch $0
  StrCpy $1 $0 1
  StrCpy $2 $0 "" -1
  StrCmp $1 "$\"" 0 +2
    StrCpy $0 $0 "" 1
  StrCmp $2 "$\"" 0 +2
    StrCpy $0 $0 -1
  Exch $0
FunctionEnd

Function _NormalizeForwardSlashes
  Exch $0
  Push $1
  Push $2
  Push $3

  StrCpy $1 0
  StrCpy $2 ""

  normalize_loop:
    StrCpy $3 $0 1 $1
    StrCmp $3 "" normalize_done
    IntOp $1 $1 + 1
    StrCmp $3 "/" 0 +3
      StrCpy $3 "\\"
    StrCpy $2 "$2$3"
    Goto normalize_loop

  normalize_done:
    StrCpy $0 $2

  Pop $3
  Pop $2
  Pop $1
  Exch $0
FunctionEnd

; $0 = 候选路径
Function AddPSItem
  ${If} $0 == ""
    Return
  ${EndIf}
  Push $0
  Call _TrimQuotes
  Pop $0

  ${If} $0 == ""
    Return
  ${EndIf}

  Push $0
  Call _NormalizeForwardSlashes
  Pop $0
  ExpandEnvStrings $0 $0

  trim_space_loop:
    StrLen $2 $0
    IntCmp $2 0 trim_space_done
    StrCpy $1 $0 "" -1
    StrCmp $1 " " 0 trim_space_done
    IntOp $2 $2 - 1
    StrCpy $0 $0 $2
    Goto trim_space_loop
  trim_space_done:

  trim_loop:
    StrLen $2 $0
    IntCmp $2 0 trim_done
    StrCpy $1 $0 "" -1
    StrCmp $1 "\\" 0 trim_done
    IntCmp $2 3 trim_done
    IntCmp $2 2 trim_done
    IntOp $2 $2 - 1
    StrCpy $0 $0 $2
    Goto trim_loop
  trim_done:

  StrLen $2 $0
  IntCmp $2 9 skip_required skip_required check_required
check_required:
  StrCpy $1 $0 "" -9
  StrCmp $1 "Required" 0 skip_required
  StrCpy $3 $0 1 -10
  StrCmp $3 "\\" 0 skip_required
  IntOp $2 $2 - 9
  StrCpy $0 $0 $2
  Goto trim_loop
skip_required:

  StrLen $2 $0
  IntCmp $2 8 skip_plugins skip_plugins check_plugins
check_plugins:
  StrCpy $1 $0 "" -8
  ${If} "$1" == "Plug-ins"
  ${OrIf} "$1" == "Plug-Ins"
    StrCpy $4 $0 1 -9
    StrCmp $4 "\\" remove_plugins_dir skip_plugins_dir
remove_plugins_dir:
      IntOp $2 $2 - 8
      StrCpy $0 $0 $2
      Goto trim_loop
skip_plugins_dir:
  ${EndIf}
  IntCmp $2 7 skip_plugins skip_plugins check_plugins2
check_plugins2:
  StrCpy $1 $0 "" -7
  ${If} "$1" == "PlugIns"
  ${OrIf} "$1" == "Plugins"
    StrCpy $4 $0 1 -8
    StrCmp $4 "\\" remove_plugins_dir2 skip_plugins_dir2
remove_plugins_dir2:
      IntOp $2 $2 - 7
      StrCpy $0 $0 $2
      Goto trim_loop
skip_plugins_dir2:
  ${EndIf}
skip_plugins:

  StrCpy $1 $0 "" -13
  ${If} "$1" == "Photoshop.exe"
    IfFileExists "$0" 0 not_found
    StrLen $2 $0
    IntOp $2 $2 - 13
    StrCpy $0 $0 $2
  ${Else}
    IfFileExists "$0\\Photoshop.exe" 0 check_required
    Goto found
    check_required:
    IfFileExists "$0\\Required\\Photoshop.exe" 0 not_found
  ${EndIf}
found:

  trim_loop2:
    StrLen $2 $0
    IntCmp $2 0 trim_done2
    StrCpy $1 $0 "" -1
    StrCmp $1 "\\" 0 trim_done2
    IntCmp $2 3 trim_done2
    IntCmp $2 2 trim_done2
    IntOp $2 $2 - 1
    StrCpy $0 $0 $2
    Goto trim_loop2
  trim_done2:

  SendMessage $hCombo ${CB_FINDSTRINGEXACT} -1 "STR:$0" $3
  IntCmp $3 -1 add_item add_item already
  add_item:
    ${NSD_CB_AddString} $hCombo "$0"
    DetailPrint "检测到 Photoshop：$0"
    ${If} $firstItem == ""
      StrCpy $firstItem "$0"
    ${EndIf}
  already:
    Return
  not_found:
    Return
FunctionEnd

Function EnumPSFromProgramFiles
  ${If} ${RunningX64}
    StrCpy $2 "$PROGRAMFILES64\\Adobe"
    FindFirst $3 $4 "$2\\Adobe Photoshop*"
    StrCmp $4 "" done64
    loop64:
      StrCpy $0 "$2\\$4"
      Call AddPSItem
      FindNext $3 $4
      StrCmp $4 "" done64
      Goto loop64
    done64:
      StrCmp $3 "error" done64_close_skip
      FindClose $3
    done64_close_skip:

    FindFirst $3 $4 "$2\\Adobe Photoshop Beta*"
    StrCmp $4 "" done64b
    loop64b:
      StrCpy $0 "$2\\$4"
      Call AddPSItem
      FindNext $3 $4
      StrCmp $4 "" done64b
      Goto loop64b
    done64b:
      StrCmp $3 "error" done64b_close_skip
      FindClose $3
    done64b_close_skip:
  ${EndIf}

  StrCpy $2 "$PROGRAMFILES\\Adobe"
  FindFirst $3 $4 "$2\\Adobe Photoshop*"
  StrCmp $4 "" done86
  loop86:
    StrCpy $0 "$2\\$4"
    Call AddPSItem
    FindNext $3 $4
    StrCmp $4 "" done86
    Goto loop86
  done86:
    StrCmp $3 "error" done86_close_skip
    FindClose $3
  done86_close_skip:
  FindFirst $3 $4 "$2\\Adobe Photoshop Beta*"
  StrCmp $4 "" done86b
  loop86b:
    StrCpy $0 "$2\\$4"
    Call AddPSItem
    FindNext $3 $4
    StrCmp $4 "" done86b
    Goto loop86b
  done86b:
    StrCmp $3 "error" done86b_close_skip
    FindClose $3
  done86b_close_skip:
FunctionEnd

Function EnumPSFromRegistry
  ${If} ${RunningX64}
    SetRegView 64
    StrCpy $5 0
    loop_lm64:
      EnumRegKey $6 HKLM "SOFTWARE\\Adobe\\Photoshop" $5
      StrCmp $6 "" done_lm64
      !insertmacro PROCESS_PS_KEY HKLM "SOFTWARE\\Adobe\\Photoshop\\$6" LM64_PS
      IntOp $5 $5 + 1
      Goto loop_lm64
    done_lm64:
    !insertmacro PROCESS_PS_KEY HKLM "SOFTWARE\\Adobe\\Photoshop" LM64_ROOT

    StrCpy $5 0
    loop_lm64_beta:
      EnumRegKey $6 HKLM "SOFTWARE\\Adobe\\Photoshop Beta" $5
      StrCmp $6 "" done_lm64_beta
      !insertmacro PROCESS_PS_KEY HKLM "SOFTWARE\\Adobe\\Photoshop Beta\\$6" LM64_PSB
      IntOp $5 $5 + 1
      Goto loop_lm64_beta
    done_lm64_beta:
    !insertmacro PROCESS_PS_KEY HKLM "SOFTWARE\\Adobe\\Photoshop Beta" LM64_PSB_ROOT

    !insertmacro ADD_REG_STR HKLM "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths\\Photoshop.exe" ""
    !insertmacro ADD_REG_STR HKLM "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths\\PhotoshopBeta.exe" ""
    SetRegView lastused
  ${EndIf}

  SetRegView 32
  StrCpy $5 0
  loop_lm32:
    EnumRegKey $6 HKLM "SOFTWARE\\Adobe\\Photoshop" $5
    StrCmp $6 "" done_lm32
    !insertmacro PROCESS_PS_KEY HKLM "SOFTWARE\\Adobe\\Photoshop\\$6" LM32_PS
    IntOp $5 $5 + 1
    Goto loop_lm32
  done_lm32:
  !insertmacro PROCESS_PS_KEY HKLM "SOFTWARE\\Adobe\\Photoshop" LM32_ROOT

  StrCpy $5 0
  loop_lm32_beta:
    EnumRegKey $6 HKLM "SOFTWARE\\Adobe\\Photoshop Beta" $5
    StrCmp $6 "" done_lm32_beta
    !insertmacro PROCESS_PS_KEY HKLM "SOFTWARE\\Adobe\\Photoshop Beta\\$6" LM32_PSB
    IntOp $5 $5 + 1
    Goto loop_lm32_beta
  done_lm32_beta:
  !insertmacro PROCESS_PS_KEY HKLM "SOFTWARE\\Adobe\\Photoshop Beta" LM32_PSB_ROOT

  !insertmacro ADD_REG_STR HKLM "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths\\Photoshop.exe" ""
  !insertmacro ADD_REG_STR HKLM "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths\\PhotoshopBeta.exe" ""
  SetRegView lastused

  ${If} ${RunningX64}
    SetRegView 64
    StrCpy $5 0
    loop_cu64:
      EnumRegKey $6 HKCU "SOFTWARE\\Adobe\\Photoshop" $5
      StrCmp $6 "" done_cu64
      !insertmacro PROCESS_PS_KEY HKCU "SOFTWARE\\Adobe\\Photoshop\\$6" CU64_PS
      IntOp $5 $5 + 1
      Goto loop_cu64
    done_cu64:
    !insertmacro PROCESS_PS_KEY HKCU "SOFTWARE\\Adobe\\Photoshop" CU64_ROOT

    StrCpy $5 0
    loop_cu64_beta:
      EnumRegKey $6 HKCU "SOFTWARE\\Adobe\\Photoshop Beta" $5
      StrCmp $6 "" done_cu64_beta
      !insertmacro PROCESS_PS_KEY HKCU "SOFTWARE\\Adobe\\Photoshop Beta\\$6" CU64_PSB
      IntOp $5 $5 + 1
      Goto loop_cu64_beta
    done_cu64_beta:
    !insertmacro PROCESS_PS_KEY HKCU "SOFTWARE\\Adobe\\Photoshop Beta" CU64_PSB_ROOT

    !insertmacro ADD_REG_STR HKCU "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths\\Photoshop.exe" ""
    !insertmacro ADD_REG_STR HKCU "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths\\PhotoshopBeta.exe" ""
    SetRegView lastused
  ${EndIf}

  StrCpy $5 0
  loop_cu32:
    EnumRegKey $6 HKCU "SOFTWARE\\Adobe\\Photoshop" $5
    StrCmp $6 "" done_cu32
    !insertmacro PROCESS_PS_KEY HKCU "SOFTWARE\\Adobe\\Photoshop\\$6" CU32_PS
    IntOp $5 $5 + 1
    Goto loop_cu32
  done_cu32:
  !insertmacro PROCESS_PS_KEY HKCU "SOFTWARE\\Adobe\\Photoshop" CU32_ROOT

  StrCpy $5 0
  loop_cu32_beta:
    EnumRegKey $6 HKCU "SOFTWARE\\Adobe\\Photoshop Beta" $5
    StrCmp $6 "" done_cu32_beta
    !insertmacro PROCESS_PS_KEY HKCU "SOFTWARE\\Adobe\\Photoshop Beta\\$6" CU32_PSB
    IntOp $5 $5 + 1
    Goto loop_cu32_beta
  done_cu32_beta:
  !insertmacro PROCESS_PS_KEY HKCU "SOFTWARE\\Adobe\\Photoshop Beta" CU32_PSB_ROOT

  !insertmacro ADD_REG_STR HKCU "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths\\Photoshop.exe" ""
  !insertmacro ADD_REG_STR HKCU "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths\\PhotoshopBeta.exe" ""
  SetRegView lastused
FunctionEnd

Function PageSelectPS
  nsDialogs::Create 1018
  Pop $0

  ${NSD_CreateLabel} 0 0 100% 20u "检测到以下 Photoshop（默认第一项）："
  Pop $1

  ${NSD_CreateDropList} 0 20u 100% 12u ""
  Pop $hCombo

  StrCpy $firstItem ""
  Call EnumPSFromRegistry
  Call EnumPSFromProgramFiles

  ${NSD_CB_GetCount} $hCombo $3
  ${If} $3 == 0
    ${NSD_CB_AddString} $hCombo "（未检测到 Photoshop，将安装到：${UXP_FALLBACK}）"
    ${NSD_CB_SelectString} $hCombo "（未检测到 Photoshop，将安装到：${UXP_FALLBACK}）"
    DetailPrint "未在系统中发现 Photoshop，默认安装到：${UXP_FALLBACK}"
  ${Else}
    ${NSD_CB_SelectString} $hCombo $firstItem
  ${EndIf}

  nsDialogs::Show
FunctionEnd

Function PageSelectPS_Leave
  ${NSD_GetText} $hCombo $1

  StrCpy $2 "（未检测到 Photoshop"
  StrLen $3 $2
  StrCpy $4 $1 $3
  ${If} $4 == $2
    StrCpy $TARGET_DIR "${UXP_FALLBACK}"
  ${Else}
    StrCpy $TARGET_DIR "$1\\Plug-ins\\__APP_DIRNAME__"
  ${EndIf}
FunctionEnd

Section "Install"
  SetOverwrite on
  ClearErrors
  IfFileExists "$TARGET_DIR\\*.*" 0 skip_remove
    RMDir /r "$TARGET_DIR"
    IfErrors 0 +3
      MessageBox MB_ICONEXCLAMATION "无法删除已有的插件目录：$TARGET_DIR$\n请确认 Photoshop 已关闭。"
      ClearErrors
  skip_remove:
  ClearErrors
  CreateDirectory "$TARGET_DIR"
  IfErrors 0 +3
    MessageBox MB_ICONSTOP "无法创建目录：$TARGET_DIR$\n请以管理员身份运行安装程序。"
    Abort
  SetOutPath "$TARGET_DIR"
  ClearErrors
  File /r "${PAYLOAD_DIR}\\*.*"
  IfErrors 0 +3
    MessageBox MB_ICONSTOP "复制插件文件失败：$TARGET_DIR$\n请确认权限后重试。"
    Abort

  DetailPrint "安装路径：$TARGET_DIR"
SectionEnd

Section "Uninstall"
  StrCmp $TARGET_DIR "" skip_uninstall
  RMDir /r "$TARGET_DIR"
  Goto uninstall_end
  skip_uninstall:
  DetailPrint "未找到已记录的安装路径，跳过卸载。"
  uninstall_end:
SectionEnd

; ========== END ==========
