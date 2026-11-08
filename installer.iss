#define MyAppName "Maze Royale"
#define MyAppVersion "1.3.0"
#define MyAppPublisher "Maze Royale"
#define MyAppExeName "maze_royale.exe"

[Setup]
AppId={{8F9DCD69-1F43-4A3E-9146-0E8E81A32BB6}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}

OutputDir=installer
OutputBaseFilename=Maze-Royale-{#MyAppVersion}-CHEAT

; Установка для текущего пользователя без прав администратора
DefaultDirName={localappdata}\Programs\{#MyAppName}
DefaultGroupName={#MyAppName}

; Разрешаем выбрать папку установки
DisableDirPage=no

; Показываем выбор папки меню Пуск
DisableProgramGroupPage=no

; Не требуем права администратора
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=commandline

; Информация об установленном приложении
UninstallDisplayName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}

; Иконка установщика
SetupIconFile=windows\runner\resources\app_icon.ico

; Современный интерфейс
WizardStyle=modern

; Создаём деинсталлятор
Uninstallable=yes

; Не добавлять приложение в автозапуск
DisableStartupPrompt=yes

; x64 Flutter application
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; Русский интерфейс установщика
[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

; Выбор ярлыков
[Tasks]
Name: "desktopicon"; \
    Description: "Создать ярлык на рабочем столе"; \
    GroupDescription: "Дополнительные ярлыки:"; \
    Flags: unchecked

Name: "startmenuicon"; \
    Description: "Создать ярлык в меню Пуск"; \
    GroupDescription: "Дополнительные ярлыки:"; \
    Flags: checkedonce

; Файлы Flutter-приложения
[Files]
Source: "build\windows\x64\runner\Release\*"; \
    DestDir: "{app}"; \
    Flags: recursesubdirs createallsubdirs ignoreversion

; Ярлыки
[Icons]
Name: "{autodesktop}\{#MyAppName}"; \
    Filename: "{app}\{#MyAppExeName}"; \
    Tasks: desktopicon

Name: "{group}\{#MyAppName}"; \
    Filename: "{app}\{#MyAppExeName}"; \
    Tasks: startmenuicon

Name: "{group}\Удалить {#MyAppName}"; \
    Filename: "{uninstallexe}"

; Запуск после установки
[Run]
Filename: "{app}\{#MyAppExeName}"; \
    Description: "Запустить {#MyAppName}"; \
    Flags: nowait postinstall skipifsilent

Filename: "{app}\{#MyAppExeName}"; \
    Check: WizardSilent; \
    Flags: nowait
