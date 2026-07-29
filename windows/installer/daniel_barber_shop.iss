; Instalador de Windows para Daniel's Barber Shop, generado con Inno Setup 6.
;
; A diferencia de los .iss de los otros 3 sistemas hermanos (Super Color,
; Variedades Lopsi, Auto Frenos de Oriente), este SÍ queda versionado en el
; repo desde el principio: el original se había perdido (vivía suelto en
; Descargas\, ver memoria del proyecto) y el AppId tuvo que recuperarse del
; registro de Windows en la v7. Mantenerlo acá evita que se vuelva a perder.
;
; Uso: compilar con
;   flutter build windows --release
;   iscc windows\installer\daniel_barber_shop.iss
; El .exe resultante queda en windows\installer\Output\BarberShop<version>.exe
; -subirlo a mano al release de GitHub junto con el .apk, ver
; ActualizacionService y version_app.dart-.

#define MyAppName "Daniel's Barber Shop"
#define MyAppVersion "9"
#define MyAppExeName "sistema_ventas.exe"
#define MyReleaseDir "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{9F47B1A3-709C-4563-8706-0C57BC920860}
AppName={#MyAppName}
AppVerName={#MyAppName} version {#MyAppVersion}
AppVersion={#MyAppVersion}
AppPublisher=My Company, Inc.
AppPublisherURL=https://www.example.com/
AppSupportURL=https://www.example.com/
AppUpdatesURL=https://www.example.com/
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=admin
OutputDir=Output
OutputBaseFilename=BarberShop{#MyAppVersion}
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear un acceso directo en el Escritorio"; GroupDescription: "Accesos directos:"

[Files]
Source: "{#MyReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion; Excludes: "data\*"
Source: "{#MyReleaseDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Abrir {#MyAppName}"; Flags: nowait postinstall skipifsilent
