Unicode True

!define APP_NAME "MyMusic"
!define APP_VERSION "1.0.0"
!define APP_PUBLISHER "MyMusic"
!define APP_EXE "mymusic.exe"

Name "${APP_NAME}"
Caption "${APP_NAME} Setup"

OutFile "installer\MyMusic-Setup-${APP_VERSION}.exe"

InstallDir "$PROGRAMFILES64\MyMusic"

RequestExecutionLevel admin

SetCompressor /SOLID lzma

!include "MUI2.nsh"

!define MUI_ABORTWARNING
!define MUI_ICON "windows\runner\resources\app_icon.ico"
!define MUI_UNICON "windows\runner\resources\app_icon.ico"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

Section "MyMusic"

    SetOutPath "$INSTDIR"

    File /r "build\windows\x64\runner\Release\*.*"

    CreateDirectory "$SMPROGRAMS\MyMusic"

    CreateShortcut "$SMPROGRAMS\MyMusic\MyMusic.lnk" "$INSTDIR\${APP_EXE}"

    CreateShortcut "$DESKTOP\MyMusic.lnk" "$INSTDIR\${APP_EXE}"

    WriteUninstaller "$INSTDIR\Uninstall.exe"

    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\MyMusic" \
        "DisplayName" "${APP_NAME}"

    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\MyMusic" \
        "DisplayVersion" "${APP_VERSION}"

    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\MyMusic" \
        "Publisher" "${APP_PUBLISHER}"

SectionEnd

Section "Uninstall"

    Delete "$DESKTOP\MyMusic.lnk"
    Delete "$SMPROGRAMS\MyMusic\MyMusic.lnk"
    RMDir "$SMPROGRAMS\MyMusic"

    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\MyMusic"

    RMDir /r "$INSTDIR"

SectionEnd