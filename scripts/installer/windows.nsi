; gwsh claude code - Windows Installer
; Professional NSIS 3.x script with dependency detection

!define PRODUCT_NAME "GWSH Claude Code"
!ifndef PRODUCT_VERSION
  !define PRODUCT_VERSION "1.0.0"
!endif
!define PRODUCT_PUBLISHER "gwsh"
!define PRODUCT_DIR_REGKEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\gwshClaude"
!define EXE_NAME "gclaude.exe"

Name "${PRODUCT_NAME} ${PRODUCT_VERSION}"
!ifndef OUTFILE
  !define OUTFILE "..\..\dist\installer\gwsh-code-setup.exe"
!endif
OutFile "${OUTFILE}"
RequestExecutionLevel user
InstallDir "$LOCALAPPDATA\Programs\gwshClaude"
SetCompressor lzma
ShowInstDetails show
ShowUninstDetails show
BrandingText "GWSH Claude Code"

!include "MUI2.nsh"
!include "WinMessages.nsh"
!include "WordFunc.nsh"
!insertmacro VersionCompare

Var HasGit
Var PathVar

; --- Icon ---
!define MUI_ICON "..\..\png\logo.ico"
!define MUI_UNICON "..\..\png\logo.ico"

; --- Custom text ---
!define MUI_WELCOMEPAGE_TITLE "Welcome to GWSH Claude Code Setup"
!define MUI_WELCOMEPAGE_TEXT "GWSH Claude Code is a free, open-source AI coding assistant CLI.$\r$\n$\r$\nIt supports five AI providers (Anthropic, OpenAI Codex, AWS Bedrock, Google Vertex, Anthropic Foundry) and includes all experimental features unlocked.$\r$\n$\r$\nThis installer will set up GWSH Claude Code on your computer. Click Next to continue."
!define MUI_FINISHPAGE_TITLE "Installation Complete"
!define MUI_FINISHPAGE_TEXT "GWSH Claude Code has been installed on your computer.$\r$\n$\r$\nTo get started, open a new terminal and type: gclaude$\r$\n$\r$\nFirst time? Run 'gclaude /login' for OAuth authentication, or set ANTHROPIC_API_KEY in your environment variables."
!define MUI_FINISHPAGE_LINK "Visit GWSH Claude Code on GitHub"
!define MUI_FINISHPAGE_LINK_LOCATION "https://github.com/paoloanzn/free-code"
!define MUI_FINISHPAGE_RUN "$INSTDIR\${EXE_NAME}"
!define MUI_FINISHPAGE_RUN_TEXT "Run gclaude now"
!define MUI_FINISHPAGE_RUN_FUNCTION LaunchGClaude
!define MUI_ABORTWARNING

; --- Pages ---
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

; --- Launch with system default terminal ---
Function LaunchGClaude
  Exec '"$INSTDIR\${EXE_NAME}"'
FunctionEnd

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

; --- PATH manipulation macros ---
!macro AddToPath dir
  ReadRegStr $0 HKCU "Environment" "Path"
  StrLen $1 $0
  ${If} $1 == 0
    WriteRegExpandStr HKCU "Environment" "Path" "${dir}"
  ${Else}
    ; Surround with semicolons to match only full path entries
    StrCpy $R0 ";$0;"
    StrCpy $R1 ";${dir};"
    Call PathContains
    ${If} $R2 == "0"
      WriteRegExpandStr HKCU "Environment" "Path" "$0;${dir}"
    ${EndIf}
  ${EndIf}
!macroend

!macro RemoveFromPath dir
  ReadRegStr $0 HKCU "Environment" "Path"
  StrLen $1 $0
  ${If} $1 != 0
    StrCpy $R0 "$0"
    StrCpy $R1 "${dir}"
    Call un.PathRemove
    WriteRegExpandStr HKCU "Environment" "Path" "$R0"
  ${EndIf}
!macroend

; --- PATH manipulation helpers (uses $R0-$R7) ---
; PathContains: $R0=haystack, $R1=needle -> $R2="1" if found, "0" otherwise
Function PathContains
  StrCpy $R2 "0"
  StrLen $2 $R1
  StrLen $3 $R0
  ${If} $3 >= $2
    IntOp $3 $3 - $2
    ${ForEach} $4 0 $3 + 1
      StrCpy $5 $R0 $2 $4
      ${If} $5 == $R1
        StrCpy $R2 "1"
        ${Break}
      ${EndIf}
    ${Next}
  ${EndIf}
FunctionEnd

; PathRemove: $R0=path, $R1=dir -> $R0=cleaned path (no nested function calls)
Function PathRemove
  Push $2
  Push $3
  Push $4
  Push $5
  Push $6
  Push $7
  Push $8
  Push $9

  ; Append trailing semicolon to simplify boundary handling
  StrCpy $2 "$R0;"
  StrCpy $3 "$R1;"  ; needle = "dir;"
  StrCpy $7 ""       ; result accumulator
  StrLen $4 $3       ; needle length

  ${Do}
    ; --- inlined index-of: find $3 in $2 -> position in $5 (-1 if not found) ---
    StrCpy $5 "-1"
    StrLen $6 $2
    StrLen $8 $3
    ${If} $6 >= $8
      IntOp $6 $6 - $8
      ${ForEach} $9 0 $6 + 1
        StrCpy $R8 $2 $8 $9
        ${If} $R8 == $3
          StrCpy $5 $9
          ${Break}
        ${EndIf}
      ${Next}
    ${EndIf}
    ; --- end inlined index-of ---

    ${If} $5 == "-1"
      StrCpy $7 "$7$2"     ; append remaining
      ${ExitDo}
    ${EndIf}
    StrCpy $6 $2 $5        ; part before match
    StrCpy $7 "$7$6"       ; append before part
    IntOp $5 $5 + $4       ; skip past needle
    StrCpy $2 $2 "" $5     ; remainder
  ${Loop}

  ; Remove leading "$R1" if present (when dir was at start without ;)
  StrLen $4 $R1
  StrCpy $5 $7 $4
  ${If} $5 == $R1
    StrCpy $7 $7 "" $4
    StrCpy $5 $7 1
    ${If} $5 == ";"
      StrCpy $7 $7 "" 1
    ${EndIf}
  ${EndIf}

  ; Clean trailing semicolon
  StrLen $4 $7
  ${If} $4 > 0
    IntOp $4 $4 - 1
    StrCpy $5 $7 1 $4
    ${If} $5 == ";"
      StrCpy $7 $7 -1
    ${EndIf}
  ${EndIf}

  ; Clean leading semicolon
  StrCpy $5 $7 1
  ${If} $5 == ";"
    StrCpy $7 $7 "" 1
  ${EndIf}

  ; Clean double semicolons (loop until none)
  ${Do}
    StrLen $4 $7
    StrCpy $5 "-1"
    ${If} $4 >= 2
      IntOp $4 $4 - 2
      ${ForEach} $6 0 $4 + 1
        StrCpy $8 $7 2 $6
        ${If} $8 == ";;"
          StrCpy $5 $6
          ${Break}
        ${EndIf}
      ${Next}
    ${EndIf}
    ${If} $5 == "-1"
      ${ExitDo}
    ${EndIf}
    StrCpy $8 $7 $5           ; part before ;;
    IntOp $5 $5 + 2            ; skip ;;
    StrCpy $9 $7 "" $5         ; part after ;;
    StrCpy $7 "$8;$9"
  ${Loop}

  StrCpy $R0 $7

  Pop $9
  Pop $8
  Pop $7
  Pop $6
  Pop $5
  Pop $4
  Pop $3
  Pop $2
FunctionEnd

; un.PathRemove: $R0=path, $R1=dir -> $R0=cleaned path (for uninstall section)
Function un.PathRemove
  Push $2
  Push $3
  Push $4
  Push $5
  Push $6
  Push $7
  Push $8
  Push $9

  StrCpy $2 "$R0;"
  StrCpy $3 "$R1;"
  StrCpy $7 ""
  StrLen $4 $3

  ${Do}
    StrCpy $5 "-1"
    StrLen $6 $2
    StrLen $8 $3
    ${If} $6 >= $8
      IntOp $6 $6 - $8
      ${ForEach} $9 0 $6 + 1
        StrCpy $R8 $2 $8 $9
        ${If} $R8 == $3
          StrCpy $5 $9
          ${Break}
        ${EndIf}
      ${Next}
    ${EndIf}

    ${If} $5 == "-1"
      StrCpy $7 "$7$2"
      ${ExitDo}
    ${EndIf}
    StrCpy $6 $2 $5
    StrCpy $7 "$7$6"
    IntOp $5 $5 + $4
    StrCpy $2 $2 "" $5
  ${Loop}

  StrLen $4 $R1
  StrCpy $5 $7 $4
  ${If} $5 == $R1
    StrCpy $7 $7 "" $4
    StrCpy $5 $7 1
    ${If} $5 == ";"
      StrCpy $7 $7 "" 1
    ${EndIf}
  ${EndIf}

  StrLen $4 $7
  ${If} $4 > 0
    IntOp $4 $4 - 1
    StrCpy $5 $7 1 $4
    ${If} $5 == ";"
      StrCpy $7 $7 -1
    ${EndIf}
  ${EndIf}

  StrCpy $5 $7 1
  ${If} $5 == ";"
    StrCpy $7 $7 "" 1
  ${EndIf}

  ${Do}
    StrLen $4 $7
    StrCpy $5 "-1"
    ${If} $4 >= 2
      IntOp $4 $4 - 2
      ${ForEach} $6 0 $4 + 1
        StrCpy $8 $7 2 $6
        ${If} $8 == ";;"
          StrCpy $5 $6
          ${Break}
        ${EndIf}
      ${Next}
    ${EndIf}
    ${If} $5 == "-1"
      ${ExitDo}
    ${EndIf}
    StrCpy $8 $7 $5
    IntOp $5 $5 + 2
    StrCpy $9 $7 "" $5
    StrCpy $7 "$8;$9"
  ${Loop}

  StrCpy $R0 $7

  Pop $9
  Pop $8
  Pop $7
  Pop $6
  Pop $5
  Pop $4
  Pop $3
  Pop $2
FunctionEnd

; --- Detect Git ---
Function CheckDependencies
  StrCpy $HasGit "0"
  nsExec::ExecToStack 'cmd /c where git 2>nul'
  Pop $0
  ${If} $0 == 0
    StrCpy $HasGit "1"
  ${EndIf}
  ${If} $HasGit == "0"
    MessageBox MB_YESNO|MB_ICONQUESTION \
      "Git was not found on your system.$\r$\n$\r$\nGit is recommended for full functionality (code diffs, version control).$\r$\n$\r$\nWould you like to download Git now?" \
      IDYES downloadGit IDNO skipGit
    downloadGit:
      ExecShell "open" "https://git-scm.com/download/win"
      MessageBox MB_OK "After Git installation completes, click OK to continue."
    skipGit:
  ${EndIf}
FunctionEnd

; --- Auto-uninstall previous version ---
Function UninstallPrevious
  ; Check registry for old install location
  ReadRegStr $0 HKCU "${PRODUCT_DIR_REGKEY}" "UninstallString"
  ${If} $0 != ""
    ; Run old uninstaller silently
    DetailPrint "Removing previous installation..."
    ExecWait '$0 /S _?=$INSTDIR'
  ${Else}
    ; No registry entry, check default install dir
    IfFileExists "$INSTDIR\uninstall.exe" 0 skipLegacy
    DetailPrint "Removing previous installation..."
    ExecWait '"$INSTDIR\uninstall.exe" /S _?=$INSTDIR'
    skipLegacy:
  ${EndIf}
FunctionEnd

Section "Install"
  Call UninstallPrevious
  Call CheckDependencies

  SetOutPath "$INSTDIR"
  SetCompress off
  File "..\..\dist\gclaude.exe"
  SetCompress auto
  File "..\..\png\logo.ico"

  WriteUninstaller "$INSTDIR\uninstall.exe"

  ; Start Menu shortcut with icon
  CreateShortCut "$SMPROGRAMS\GWSH Claude Code.lnk" "$INSTDIR\${EXE_NAME}" "" "$INSTDIR\logo.ico"

  ; Add/Remove Programs entry
  WriteRegStr HKCU "${PRODUCT_DIR_REGKEY}" "DisplayName" "${PRODUCT_NAME}"
  WriteRegStr HKCU "${PRODUCT_DIR_REGKEY}" "DisplayVersion" "${PRODUCT_VERSION}"
  WriteRegStr HKCU "${PRODUCT_DIR_REGKEY}" "Publisher" "${PRODUCT_PUBLISHER}"
  WriteRegStr HKCU "${PRODUCT_DIR_REGKEY}" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegStr HKCU "${PRODUCT_DIR_REGKEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${PRODUCT_DIR_REGKEY}" "DisplayIcon" "$INSTDIR\logo.ico"
  WriteRegStr HKCU "${PRODUCT_DIR_REGKEY}" "HelpLink" "https://github.com/paoloanzn/free-code"
  WriteRegStr HKCU "${PRODUCT_DIR_REGKEY}" "URLInfoAbout" "https://github.com/paoloanzn/free-code"
  WriteRegDWORD HKCU "${PRODUCT_DIR_REGKEY}" "NoModify" 1
  WriteRegDWORD HKCU "${PRODUCT_DIR_REGKEY}" "NoRepair" 1
  WriteRegDWORD HKCU "${PRODUCT_DIR_REGKEY}" "EstimatedSize" 200000

  ; Add to PATH (pure NSIS registry operations - no PowerShell)
  !insertmacro AddToPath $INSTDIR
  SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=1000
SectionEnd

Section "Uninstall"
  ; Remove from PATH (pure NSIS registry operations - no PowerShell)
  !insertmacro RemoveFromPath $INSTDIR

  ; Remove shortcut
  Delete "$SMPROGRAMS\GWSH Claude Code.lnk"

  SetOutPath "$TEMP"
  Delete /REBOOTOK "$INSTDIR\gclaude.exe"
  Delete /REBOOTOK "$INSTDIR\logo.ico"
  Delete /REBOOTOK "$INSTDIR\uninstall.exe"
  RMDir /REBOOTOK "$INSTDIR"

  DeleteRegKey HKCU "${PRODUCT_DIR_REGKEY}"

  SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=1000
SectionEnd
