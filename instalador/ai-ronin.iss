; Instalador de AI RONIN para Windows (Inno Setup 6).
; No lo compiles a mano: usa instalador\construir.ps1, que exporta el .exe con Godot, prepara
; build\staging (el juego, la Forja y LECTURAS.md) y llama a ISCC con este script.
;
; Se instala para tu usuario, sin permisos de administrador, en
; %LOCALAPPDATA%\Programs\AI RONIN. Así el juego puede escribir en forja\ y en musica\.
; Tus partidas están aparte (%APPDATA%\Godot\app_userdata\AI RONIN) y desinstalar no las borra.

#define AppVersion "0.1.0"

[Setup]
AppId={{6F3C2A4E-8B1D-4E7A-9C55-2D7E1B0A9F31}
AppName=AI RONIN
AppVersion={#AppVersion}
AppVerName=AI RONIN {#AppVersion}
AppPublisher=AI RONIN
DefaultDirName={localappdata}\Programs\AI RONIN
DefaultGroupName=AI RONIN
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\build
OutputBaseFilename=AI-RONIN-Setup-{#AppVersion}
Compression=lzma2/max
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
UninstallDisplayIcon={app}\AI-RONIN.exe
UninstallDisplayName=AI RONIN

[Languages]
Name: "es"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "escritorio"; Description: "Crear un acceso directo en el escritorio"; GroupDescription: "Accesos directos:"; Flags: unchecked

[Dirs]
Name: "{app}\musica"

[Files]
Source: "..\build\staging\AI-RONIN.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\staging\LECTURAS.md"; DestDir: "{app}"; Flags: ignoreversion
; La Forja: tus ejercicios son tuyos. Al reinstalar no se pisa ningún fichero que ya exista
; (solo se añaden los nuevos) y al desinstalar no se borra nada de forja\.
Source: "..\build\staging\forja\*"; DestDir: "{app}\forja"; Flags: recursesubdirs createallsubdirs onlyifdoesntexist uninsneveruninstall

[Icons]
Name: "{autoprograms}\AI RONIN"; Filename: "{app}\AI-RONIN.exe"; WorkingDir: "{app}"
Name: "{autoprograms}\Carpeta de la Forja (AI RONIN)"; Filename: "{app}\forja"
Name: "{autodesktop}\AI RONIN"; Filename: "{app}\AI-RONIN.exe"; WorkingDir: "{app}"; Tasks: escritorio

[Run]
Filename: "{app}\AI-RONIN.exe"; Description: "Abrir AI RONIN"; Flags: nowait postinstall skipifsilent
