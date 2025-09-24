; ======== NSIS TEMPLATE (Windows installer) ========
!include "MUI2.nsh"
!include "nsDialogs.nsh"
!include "FileFunc.nsh"
!include "x64.nsh"

Unicode true
RequestExecutionLevel admin

; --------- Defines (filled by main.js via string replace) ----------
!define APP_NAME_FILE __APP_NAME_FILE__
!define APP_VERSION   __APP_VERSION__
!define PAYLOAD_DIR   "__PAYLOAD_DIR__"

; 显示用名称（main.js 已做转义，这里直接放进引号）
Name "__APP_NAME__"

; 生成的安装器文件名（仅 ASCII）
OutFile "dist\\Setup-__APP_NAME_FILE__-__APP_VERSION__.exe"

; --------- Variables ----------
Var TARGET_DIR
Var hCombo
Var firstItem

!define UXP_FALLBACK "$LOCALAPPDATA\\Adobe\\UXP\\Plugins\\External\\__APP_NAME_FILE__"

; --------- Pages ----------
Page custom PageSelectPS PageSelectPS_Leave
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_LANGUAGE "SimpChinese"

; --------- Helper: 去引号 ---------
Function _TrimQuotes
  Exch $0
  StrCpy $1 $0 1
  StrCpy $2 $0 "" -1
  StrCmp $1 "\"" 0 +2
    StrCpy $0 $0 "" 1
  StrCmp $2 "\"" 0 +2
    StrCpy $0 $0 -1
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

  ; 若以 \Photoshop.exe 结尾，去掉文件名
  StrCpy $1 $0 "" -13
  ${If} "$1" == "Photoshop.exe"
    StrLen $2 $0
    IntOp $2 $2 - 13
    StrCpy $0 $0 $2
  ${EndIf}

  ${NSD_CB_SelectString} $hCombo "$0"
  StrCmp $0 "CB_ERR" 0 +3
    ${NSD_CB_AddString} $hCombo "$0"
    ${If} $firstItem == ""
      StrCpy $firstItem "$0"
    ${EndIf}
FunctionEnd

Function EnumPSFromProgramFiles
  ${If} ${RunningX64}
    StrCpy $2 "$PROGRAMFILES64\\Adobe"
    FindFirst $3 $4 "$2\\Adobe Photoshop*"
    loop64:
      StrCmp $3 "" done64
      StrCpy $0 "$2\\$4"
      Call AddPSItem
      FindNext $3 $4
      Goto loop64
    done64:
      FindClose $3
  ${EndIf}

  StrCpy $2 "$PROGRAMFILES\\Adobe"
  FindFirst $3 $4 "$2\\Adobe Photoshop*"
  loop86:
    StrCmp $3 "" done86
    StrCpy $0 "$2\\$4"
    Call AddPSItem
    FindNext $3 $4
    Goto loop86
  done86:
    FindClose $3
FunctionEnd

Function EnumPSFromRegistry
  StrCpy $5 0
  loop_reg1:
    EnumRegKey $6 HKLM "SOFTWARE\\Adobe\\Photoshop" $5
    StrCmp $6 "" done_reg1
    ReadRegStr $7 HKLM "SOFTWARE\\Adobe\\Photoshop\\$6" "ApplicationPath"
    ${If} $7 != ""
      StrCpy $0 $7
      Call AddPSItem
    ${EndIf}
    IntOp $5 $5 + 1
    Goto loop_reg1
  done_reg1:

  StrCpy $5 0
  loop_reg2:
    EnumRegKey $6 HKLM "SOFTWARE\\WOW6432Node\\Adobe\\Photoshop" $5
    StrCmp $6 "" done_reg2
    ReadRegStr $7 HKLM "SOFTWARE\\WOW6432Node\\Adobe\\Photoshop\\$6" "ApplicationPath"
    ${If} $7 != ""
      StrCpy $0 $7
      Call AddPSItem
    ${EndIf}
    IntOp $5 $5 + 1
    Goto loop_reg2
  done_reg2:
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
    StrCpy $TARGET_DIR "$1\\Plug-ins\\__APP_NAME_FILE__"
  ${EndIf}
FunctionEnd

Section "Install"
  SetOverwrite on
  CreateDirectory "$TARGET_DIR"
  SetOutPath "$TARGET_DIR"
  File /r "${PAYLOAD_DIR}\\*.*"

  DetailPrint "安装路径：$TARGET_DIR"
SectionEnd

Section "Uninstall"
  RMDir /r "$TARGET_DIR"
SectionEnd

; ========== END ==========