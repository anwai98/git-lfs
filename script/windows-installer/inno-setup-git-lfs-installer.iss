#define MyAppName "Git LFS"

#define PathToX86Binary "..\..\git-lfs-x86.exe"
#ifnexist PathToX86Binary
  #pragma error PathToX86Binary + " does not exist, please build it first."
#endif

#define PathToX64Binary "..\..\git-lfs-x64.exe"
#ifnexist PathToX64Binary
  #pragma error PathToX64Binary + " does not exist, please build it first."
#endif

#define PathToARM64Binary "..\..\git-lfs-arm64.exe"
#ifnexist PathToARM64Binary
  #pragma error PathToARM64Binary + " does not exist, please build it first."
#endif

; Arbitrarily choose the x86 executable here as both have the version embedded.
#define MyVersionInfoVersion GetFileVersion(PathToX86Binary)

; Misuse RemoveFileExt to strip the 4th patch-level version number.
#define MyAppVersion RemoveFileExt(MyVersionInfoVersion)

#define MyAppPublisher "GitHub, Inc."
#define MyAppURL "https://git-lfs.github.com/"
#define MyAppFilePrefix "git-lfs-windows"

[Setup]
; NOTE: The value of AppId uniquely identifies this application.
; Do not use the same AppId value in installers for other applications.
; (To generate a new GUID, click Tools | Generate GUID inside the IDE.)
AppCopyright=GitHub, Inc. and Git LFS contributors
AppId={{286391DE-F778-44EA-9375-1B21AAA04FF0}
AppName={#MyAppName}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
AppVersion={#MyAppVersion}
ArchitecturesInstallIn64BitMode=x64 arm64
ChangesEnvironment=yes
Compression=lzma
DefaultDirName={code:GetDefaultDirName}
DirExistsWarning=no
DisableReadyPage=True
LicenseFile=..\..\LICENSE.md
OutputBaseFilename={#MyAppFilePrefix}-{#MyAppVersion}
OutputDir=..\..\
PrivilegesRequired=none
SetupIconFile=git-lfs-logo.ico
SolidCompression=yes
UninstallDisplayIcon={app}\git-lfs.exe
UsePreviousAppDir=no
VersionInfoVersion={#MyVersionInfoVersion}
WizardImageFile=git-lfs-wizard-image.bmp
WizardSmallImageFile=git-lfs-logo.bmp

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: {#PathToX86Binary}; DestDir: "{app}"; Flags: ignoreversion; DestName: "git-lfs.exe"; AfterInstall: InstallGitLFS; Check: IsX86
Source: {#PathToX64Binary}; DestDir: "{app}"; Flags: ignoreversion; DestName: "git-lfs.exe"; AfterInstall: InstallGitLFS; Check: IsX64
Source: {#PathToARM64Binary}; DestDir: "{app}"; Flags: ignoreversion; DestName: "git-lfs.exe"; AfterInstall: InstallGitLFS; Check: IsARM64

[Registry]
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; ValueType: expandsz; ValueName: "Path"; ValueData: "{olddata};{app}"; Check: IsAdminLoggedOn and NeedsAddPath('{app}')
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; ValueType: string; ValueName: "GIT_LFS_PATH"; ValueData: "{app}"; Check: IsAdminLoggedOn
Root: HKCU; Subkey: "Environment"; ValueType: expandsz; ValueName: "Path"; ValueData: "{olddata};{app}"; Check: (not IsAdminLoggedOn) and NeedsAddPath('{app}')
Root: HKCU; Subkey: "Environment"; ValueType: string; ValueName: "GIT_LFS_PATH"; ValueData: "{app}"; Check: not IsAdminLoggedOn

[Code]
function GetDefaultDirName(Dummy: string): string;
begin
  if IsAdminLoggedOn then begin
    Result:=ExpandConstant('{pf}\{#MyAppName}');
  end else begin
    Result:=ExpandConstant('{userpf}\{#MyAppName}');
  end;
end;

// Checks to see if we need to add the dir to the env PATH variable.
function NeedsAddPath(Param: string): boolean;
var
  OrigPath: string;
  ParamExpanded: string;
begin
  //expand the setup constants like {app} from Param
  ParamExpanded := ExpandConstant(Param);
  if not RegQueryStringValue(HKEY_LOCAL_MACHINE,
    'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
    'Path', OrigPath)
  then begin
    Result := True;
    exit;
  end;
  // look for the path with leading and trailing semicolon and with or without \ ending
  // Pos() returns 0 if not found
  Result := Pos(';' + UpperCase(ParamExpanded) + ';', ';' + UpperCase(OrigPath) + ';') = 0;
  if Result = True then
    Result := Pos(';' + UpperCase(ParamExpanded) + '\;', ';' + UpperCase(OrigPath) + ';') = 0;
end;

// Verify that a Git executable is found in the PATH, and if it does not
// reside in either 'C:\Program Files' or 'C:\Program Files (x86)', warn
// the user in case it is not the Git installation they expected.
function GitFoundInPath(): boolean;
var
  PFiles32,PFiles64: string;
  PathEnv,Path: string;
  PathExt,Ext: string;
  i,j: integer;
  RegisterOrDeregister: string;
begin
  if IsUninstaller then
    RegisterOrDeregister := 'deregister'
  else
    RegisterOrDeregister := 'register';

  PFiles32 := ExpandConstant('{commonpf32}\')
  PFiles64 := ExpandConstant('{commonpf64}\')

  PathEnv := GetEnv('PATH') + ';';
  repeat
    i := Pos(';', PathEnv);
    Path := Copy(PathEnv, 1, i-1) + '\git';
    PathEnv := Copy(PathEnv, i+1, Length(PathEnv)-i);

    PathExt := GetEnv('PATHEXT') + ';';
    repeat
      j := Pos(';', PathExt);
      Ext := Copy(PathExt, 1, j-1);
      PathExt := Copy(PathExt, j+1, Length(PathExt)-j);

      if FileExists(Path + Ext) then begin
        if (Pos(PFiles32, Path) = 1) or (Pos(PFiles64, Path) = 1) then begin
          Result := True;
          Exit;
        end;
        Log('Warning: Found Git in unexpected location: "' + Path + Ext + '"');
        Result := (SuppressibleMsgBox(
          'An executable Git program was found in an unexpected location outside of Program Files:' + #13+#10 +
          '  "' + Path + Ext + '"' + #13+#10 +
          'If this looks dubious, Git LFS should not be ' + RegisterOrDeregister + 'ed using it.' + #13+#10 + #13+#10 +
          'Do you want to ' + RegisterOrDeregister + ' Git LFS using this Git program?',
          mbConfirmation, MB_YESNO, IDNO) = IDYES);
        if Result then
          Log('Using Git found at: "' + Path + Ext + '"')
        else
          Log('Refusing to use Git found at: "' + Path + Ext + '"');
        Exit;
      end;
    until Result or (PathExt = '');
  until Result or (PathEnv = '');
  SuppressibleMsgBox(
    'Could not find Git; can not ' + RegisterOrDeregister + ' Git LFS.', mbError, MB_OK, IDOK);
end;

// Runs the lfs initialization.
procedure InstallGitLFS();
var
  ResultCode: integer;
begin
  Exec(
    ExpandConstant('{cmd}'),
    ExpandConstant('/C ""{app}\git-lfs.exe" install"'),
    '', SW_HIDE, ewWaitUntilTerminated, ResultCode
  );
  if not ResultCode = 1 then
    MsgBox(
    'Git LFS was not able to automatically initialize itself. ' +
    'Please run "git lfs install" from the commandline.', mbInformation, MB_OK);
end;

// Event function automatically called when installing:
function InitializeSetup(): Boolean;
begin
  Result := GitFoundInPath();
end;

// Event function automatically called when uninstalling:
function InitializeUninstall(): Boolean;
var
  ResultCode: integer;
begin
  Result := False;

  if GitFoundInPath() then begin
    Exec(
      ExpandConstant('{cmd}'),
      ExpandConstant('/C ""{app}\git-lfs.exe" uninstall"'),
      '', SW_HIDE, ewWaitUntilTerminated, ResultCode
    );
    Result := True;
  end;
end;
