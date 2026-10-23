; Inno Setup 6 script for the Windows installer.
;
; Build the app first, then compile this from the repository root:
;   flutter build windows --release
;   iscc /DAppVersion=1.2.0 windows\installer\study_reminder.iss
; The installer lands in build\installer\StudyReminder-Setup-<version>.exe.
;
; It installs for the current user only, without admin rights, into
; %LOCALAPPDATA%\Programs\Study Reminder.

#ifndef AppVersion
  #define AppVersion "0.0.0-dev"
#endif

; Windows wants plain numbers in the file version: 1.2.0 out of 1.2.0-ci.7.
#if Pos("-", AppVersion) > 0
  #define FileVersion Copy(AppVersion, 1, Pos("-", AppVersion) - 1)
#else
  #define FileVersion AppVersion
#endif

#define AppName "Study Reminder"
#define AppExe "study_reminder.exe"
#define BuildDir "..\..\build\windows\x64\runner\Release"

; The app's single-instance lock, from windows/runner/main.cpp.
#define AppMutex "Local\UttkarshStudyReminder"

; Where the app files its notifications, from
; lib/features/alerts/data/local_notifications.dart.
#define NotificationsId "Uttkarsh.StudyReminder"

[Setup]
; Never change the AppId: Windows knows the installed app by it, so a new
; version installs over the old one.
AppId={{BE6F090F-EFCE-4C18-898D-511AD79523F0}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=Uttkarsh Thakur
VersionInfoVersion={#FileVersion}
PrivilegesRequired=lowest
DefaultDirName={localappdata}\Programs\{#AppName}
DisableDirPage=yes
DisableProgramGroupPage=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
; Setup and Uninstall ask the user to quit the app first. It lives in the
; tray, so the messages below say where to find Quit.
AppMutex={#AppMutex}
CloseApplications=yes
RestartApplications=no
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
OutputDir=..\..\build\installer
OutputBaseFilename=StudyReminder-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Messages]
SetupAppRunningError=Setup has detected that %1 is running.%n%nRight-click its icon in the tray, next to the clock, and choose Quit. Then click OK to continue, or Cancel to exit.
UninstallAppRunningError=Uninstall has detected that %1 is running.%n%nRight-click its icon in the tray, next to the clock, and choose Quit. Then click OK to continue, or Cancel to exit.

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[InstallDelete]
; The Flutter assets of the version before, so none it dropped stay behind.
Type: filesandordirs; Name: "{app}\data"

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[Code]
const
  RunKey = 'Software\Microsoft\Windows\CurrentVersion\Run';
  StartupApprovedKey = 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run';
  { The value lib/desktop/start_with_windows.dart writes under both keys. }
  RunValue = '{#AppName}';

{ Quit from the tray is the only way out of the app, and closing its window
  only hides it, so it is ended here. Runs after the user confirmed the
  uninstall and before Uninstall checks the app's lock. }
procedure StopRunningApp();
var
  ResultCode, Tries: Integer;
begin
  if not CheckForMutexes('{#AppMutex}') then
    Exit;
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/f /im {#AppExe}', '',
    SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Tries := 0;
  while CheckForMutexes('{#AppMutex}') and (Tries < 50) do
  begin
    Sleep(100);
    Tries := Tries + 1;
  end;
end;

{ The program a Run command starts: the quoted path at its front. }
function RunTarget(const Command: String): String;
var
  Rest: String;
  Quote: Integer;
begin
  Result := '';
  if (Length(Command) > 1) and (Command[1] = '"') then
  begin
    Rest := Copy(Command, 2, Length(Command) - 1);
    Quote := Pos('"', Rest);
    if Quote > 0 then
      Result := Copy(Rest, 1, Quote - 1);
  end;
end;

{ Removes "Start with Windows" when it starts this copy, or a copy that is
  gone. A copy unzipped elsewhere keeps its own. }
procedure RemoveStartWithWindows();
var
  Command, Target: String;
begin
  if not RegQueryStringValue(HKCU, RunKey, RunValue, Command) then
    Command := '';
  Target := RunTarget(Command);
  if (Target <> '') and FileExists(Target) and
     (CompareText(Target, ExpandConstant('{app}\{#AppExe}')) <> 0) then
    Exit;
  RegDeleteValue(HKCU, RunKey, RunValue);
  RegDeleteValue(HKCU, StartupApprovedKey, RunValue);
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  case CurUninstallStep of
    usAppMutexCheck:
      StopRunningApp();
    usPostUninstall:
      begin
        RemoveStartWithWindows();
        { The app registers this at every start, for its notifications. }
        RegDeleteKeyIncludingSubkeys(HKCU,
          'Software\Classes\AppUserModelId\{#NotificationsId}');
      end;
  end;
end;
