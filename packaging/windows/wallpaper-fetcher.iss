; Wallpaper Fetcher installer (Inno Setup 6). Built in CI from the repo root:
;   iscc /DAppVersion=0.6.0 packaging\windows\wallpaper-fetcher.iss
; after `flutter build windows --release` (packages/app) and
; `dart build cli -t bin/wallpaper_fetcher.dart -o ../../build/cli` (packages/cli).
; Writes build\dist\Wallpaper_Fetcher-<version>-Setup.exe.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#define AppName "Wallpaper Fetcher"
; Also the Start menu shortcut's AppUserModelID, which Windows needs before it
; shows the app's notifications (AppPaths.appId in the code).
#define AppUserModelId "dev.mcoombes.wallpaperfetcher"
#define AppExe "wallpaper_fetcher.exe"
#define CliDir "cli\bin"
#define Root "..\.."

[Setup]
; Never change: Windows matches upgrades and uninstalls by it.
AppId={{19AA3BA3-1124-4C03-B417-3EC0A080572D}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=dev.mcoombes
VersionInfoVersion={#AppVersion}
; Per user, no administrator prompt: %LOCALAPPDATA%\Programs\Wallpaper Fetcher.
PrivilegesRequired=lowest
DefaultDirName={autopf}\{#AppName}
DisableProgramGroupPage=yes
OutputDir={#Root}\build\dist
OutputBaseFilename=Wallpaper_Fetcher-{#AppVersion}-Setup
SetupIconFile={#Root}\packages\app\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Windows 10 1803: the first with the Unix sockets the command line uses.
MinVersion=10.0.17134
ChangesEnvironment=yes
CloseApplications=yes

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked
Name: "addtopath"; Description: "Add the wallpaper-fetcher command to PATH (for scripts and keyboard shortcuts)"

[Files]
Source: "{#Root}\packages\app\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion
Source: "{#Root}\build\cli\bundle\*"; DestDir: "{app}\cli"; Flags: recursesubdirs ignoreversion
Source: "{#Root}\packaging\windows\wallpaper-fetcher.cmd"; DestDir: "{app}\{#CliDir}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"; AppUserModelID: "{#AppUserModelId}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; AppUserModelID: "{#AppUserModelId}"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Environment"; ValueType: expandsz; ValueName: "Path"; ValueData: "{olddata};{app}\{#CliDir}"; Tasks: addtopath; Check: NotOnPath(ExpandConstant('{app}\{#CliDir}'))

[Run]
Filename: "{app}\{#AppExe}"; Description: "Start {#AppName}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; It keeps running in the tray; ask it to quit before its files go.
Filename: "{app}\{#CliDir}\wallpaper_fetcher.exe"; Parameters: "quit"; Flags: runhidden waituntilterminated; RunOnceId: "QuitApp"

[Code]
const
  EnvironmentKey = 'Environment';
  RunKey = 'Software\Microsoft\Windows\CurrentVersion\Run';

function NotOnPath(Dir: string): Boolean;
var
  Path: string;
begin
  if not RegQueryStringValue(HKCU, EnvironmentKey, 'Path', Path) then
    Result := True
  else
    Result := Pos(';' + Uppercase(Dir) + ';', ';' + Uppercase(Path) + ';') = 0;
end;

procedure RemoveFromPath(Dir: string);
var
  Path: string;
  P: Integer;
begin
  if not RegQueryStringValue(HKCU, EnvironmentKey, 'Path', Path) then exit;
  Path := ';' + Path + ';';
  P := Pos(';' + Uppercase(Dir) + ';', Uppercase(Path));
  if P = 0 then exit;
  Delete(Path, P, Length(Dir) + 1);
  Path := Copy(Path, 2, Length(Path) - 2);
  RegWriteExpandStringValue(HKCU, EnvironmentKey, 'Path', Path);
end;

// An upgrade replaces files the running app holds; ask it to quit first
// (closing its window would only hide it in the tray).
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  Cli: string;
  Code: Integer;
begin
  Cli := ExpandConstant('{app}\{#CliDir}\wallpaper_fetcher.exe');
  if FileExists(Cli) then
  begin
    Exec(Cli, 'quit', '', SW_HIDE, ewWaitUntilTerminated, Code);
    Sleep(1000);
  end;
  Result := '';
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
  begin
    RemoveFromPath(ExpandConstant('{app}\{#CliDir}'));
    // Start on login, if it was turned on (Autostart in the app).
    RegDeleteValue(HKCU, RunKey, '{#AppName}');
  end;
end;
