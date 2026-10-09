[Setup]
AppName=DevDeck Desktop Agent
AppVersion=1.0.0
DefaultDirName={userpf}\DevDeckAgent
DefaultGroupName=DevDeck
OutputDir=build
OutputBaseFilename=DevDeckAgentSetup
Compression=lzma
SolidCompression=yes
SetupIconFile=

[Files]
Source: "build\devdeck-agent.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\keypresser.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\DevDeck Agent"; Filename: "{app}\devdeck-agent.exe"
Name: "{userstartup}\DevDeck Agent"; Filename: "{app}\devdeck-agent.exe"

[Code]
function VCVersionInstalled(): Boolean;
var
  installed: Cardinal;
begin
  // Check Visual C++ 2015-2022 Redistributable (x64)
  Result := RegQueryDWordValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Installed', installed) and (installed = 1);
end;

function InitializeSetup(): Boolean;
var
  ErrorCode: Integer;
begin
  Result := True;
  if not VCVersionInstalled() then
  begin
    if MsgBox('The Microsoft Visual C++ Redistributable (x64) is required to run DevDeck Agent. Would you like to download and install it now?', mbConfirmation, MB_YESNO) = idYes then
    begin
      ShellExec('open', 'https://aka.ms/vs/17/release/vc_redist.x64.exe', '', '', SW_SHOWNORMAL, ewNoWait, ErrorCode);
    end;
  end;
end;
