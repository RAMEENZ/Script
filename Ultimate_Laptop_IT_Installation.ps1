# Variables globales
$logFile = "$env:PUBLIC\Desktop\script_log.txt"

# Fonction pour afficher les étapes et écrire dans le log
function Log-Step {
    param ([string]$Message)
    $logMessage = "===== $Message ====="
    Write-Host $logMessage -ForegroundColor Cyan
    Add-Content -Path $logFile -Value $logMessage
}

# Fonction pour écrire les messages dans le log
function Log-Message {
    param ([string]$Message)
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    Write-Host $logMessage
    Add-Content -Path $logFile -Value $logMessage
}

# Fonction pour vérifier si le script est exécuté en tant qu'administrateur
function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Fonction pour introduire un délai entre les étapes
function Wait-BetweenSteps {
    param ([int]$Seconds)
    Start-Sleep -Seconds $Seconds
}

# Vérification si le script est exécuté en tant qu'administrateur
if (-not (Test-Admin)) {
    Log-Message "Ce script doit être exécuté en tant qu'administrateur. Relancez avec les privilèges administratifs."
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Garde-fou initial
Log-Step "Garde-fou avant exécution du script"
$confirmation = Read-Host "Êtes-vous sûr de vouloir exécuter ce script (O/N)?"
if ($confirmation -ne "O") {
    Log-Message "Script annulé."
    exit
}

Wait-BetweenSteps -Seconds 3

# Vérifier et corriger la politique d'exécution si nécessaire
Log-Step "Vérification de la politique d'exécution"
$currentPolicy = Get-ExecutionPolicy
if ($currentPolicy -ne 'Unrestricted') {
    Log-Message "La politique d'exécution actuelle est '$currentPolicy'. Tentative de modification."
    try {
        Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force
        Log-Message "Politique d'exécution modifiée avec succès pour cette session."
    } catch {
        Log-Message "Erreur lors de la modification de la politique d'exécution : $($_.Exception.Message)"
    }
} else {
    Log-Message "La politique d'exécution est déjà 'Unrestricted'."
}

Wait-BetweenSteps -Seconds 3

# Suppression des points de restauration obsolètes
Log-Step "Suppression des points de restauration obsolètes"
Try {
    vssadmin delete shadows /for=c: /oldest | Out-Null
    Log-Message "Points de restauration obsolètes supprimés avec succès."
} Catch {
    Log-Message "Erreur lors de la suppression des points de restauration obsolètes: $($_.Exception.Message)"
    Add-Content -Path $logFile -Value $_.Exception.StackTrace
}

Wait-BetweenSteps -Seconds 3

# Création d'un point de restauration système
Log-Step "Création d'un point de restauration système"
Try {
    Checkpoint-Computer -Description "Script_Restore_Point" -RestorePointType "MODIFY_SETTINGS"
    Log-Message "Point de restauration créé avec succès."
} Catch {
    Log-Message "Erreur lors de la création du point de restauration: $($_.Exception.Message)"
    Add-Content -Path $logFile -Value $_.Exception.StackTrace
}

Wait-BetweenSteps -Seconds 3

# Variables
$User = "install"
$Password = Read-Host -AsSecureString "Entrez le mot de passe pour le compte 'install'"
$Group = "Administrateurs"

# Vérifier et créer l'utilisateur "install"
Log-Step "Vérification et création de l'utilisateur 'install'"
Try {
    $UserExists = Get-LocalUser -Name $User -ErrorAction SilentlyContinue
    If (-Not $UserExists) {
        New-LocalUser -Name $User -Password $Password -PasswordNeverExpires -UserMayNotChangePassword
        Add-LocalGroupMember -Group $Group -Member $User
        Log-Message "Utilisateur 'install' créé et ajouté au groupe administrateurs."
    } Else {
        $UserInGroup = Get-LocalGroupMember -Group $Group -Member $User -ErrorAction SilentlyContinue
        If (-Not $UserInGroup) {
            Add-LocalGroupMember -Group $Group -Member $User
            Log-Message "Utilisateur 'install' ajouté au groupe administrateurs."
        } else {
            Log-Message "Utilisateur 'install' déjà existant et présent dans le groupe administrateurs."
        }
    }
} Catch {
    Log-Message "Erreur lors de la vérification/création de l'utilisateur 'install': $($_.Exception.Message)"
    Add-Content -Path $logFile -Value $_.Exception.StackTrace
}

Wait-BetweenSteps -Seconds 3

# Activation de WinGet
Log-Step "Activation de WinGet"
Try {
    Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
    Log-Message "WinGet activé avec succès."
} Catch {
    Log-Message "Erreur lors de l'activation de WinGet: $($_.Exception.Message)"
    Add-Content -Path $logFile -Value $_.Exception.StackTrace
}

Wait-BetweenSteps -Seconds 3

# Désinstallation des logiciels indésirables
Log-Step "Désinstallation des logiciels indésirables"
$appPackages = @(
    "Microsoft.XboxApp",
    "Microsoft.SolitaireCollection",
    "*ActiproSoftwareLLC*",
    "*AdobeSystemsIncorporated.AdobePhotoshopExpress*",
    "*BubbleWitch3Saga*",
    "*CandyCrush*",
    "*DevHome*",
    "*Disney*",
    "*Dolby*",
    "*Duolingo-LearnLanguagesforFree*",
    "*EclipseManager*",
    "*Facebook*",
    "*Flipboard*",
    "*gaming*",
    "*Minecraft*",
    "*Office*",
    "*PandoraMediaInc*",
    "*Royal.Revolt*",
    "*Speed.Test*",
    "*Spotify*",
    "*Sway*",
    "*Twitter*",
    "*Wunderlist*",
    "AD2F1837.HPPrinterControl",
    "AppUp.IntelGraphicsExperience",
    "C27EB4BA.DropboxOEM*",
    "Disney.37853FC22B2CE",
    "DolbyLabories.DolbyAccess",
    "DolbyLabories.DolbyAudio",
    "E0469640.SmartAppearance",
    "Microsoft.549981C3F5F10",
    "Microsoft.BingNews",
    "Microsoft.BingSearch",
    "Microsoft.BingWeather",
    "Microsoft.GetHelp",
    "Microsoft.Getstarted",
    "Microsoft.GamingApp",
    "Microsoft.Messaging",
    "Microsoft.Microsoft3DViewer",
    "Microsoft.MicrosoftJournal",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.MixedReality.Portal",
    "Microsoft.News",
    "Microsoft.Office.Lens",
    "Microsoft.Office.OneNote",
    "Microsoft.Office.Sway",
    "Microsoft.OneConnect",
    "Microsoft.OneDriveSync",
    "Microsoft.People",
    "Microsoft.PowerAutomateDesktop",
    "Microsoft.PowerAutomateDesktopCopilotPlugin",
    "Microsoft.Print3D",
    "Microsoft.RemoteDesktop",
    "Microsoft.SkypeApp",
    "Microsoft.SysinternalsSuite",
    "Microsoft.Todos",
    "Microsoft.Whiteboard",
    "Microsoft.Windows.DevHome",
    "Microsoft.WindowsAlarms",
    "Microsoft.WindowsCamera",
    "Microsoft.windowscommunicationsapps",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.WindowsMaps",
    "Microsoft.WindowsSoundRecorder",
    "Microsoft.Xbox.TCUI",
    "Microsoft.XboxApp",
    "Microsoft.XboxGameOverlay",
    "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxGamingOverlay_5.721.10202.0_neutral_~_8wekyb3d8bbwe",
    "Microsoft.XboxIdentityProvider",
    "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.YourPhone",
    "Microsoft.ZuneMusic",
    "Microsoft.ZuneVideo",
    "MicrosoftCorporationII.MicrosoftFamily",
    "MicrosoftCorporationII.QuickAssist",
    "MicrosoftWindows.Client.WebExperience",
    "MicrosoftWindows.CrossDevice",
    "MirametrixInc.GlancebyMirametrix",
    "MSTeams",
    "RealtimeboardInc.RealtimeBoard",
    "SpotifyAB.SpotifyMusic",
    "Clipchamp.Clipchamp",
    "Microsoft.MicrosoftStickyNotes",
    "Microsoft.Windows.Ai.Copilot.Provider",
    "Microsoft.Copilot",
    "Microsoft.Copilot_8wekyb3d8bbwe",
    "Microsoft.Paint",
    "Microsoft.MSPaint",
    "Microsoft.549981C3F5F10_8wekyb3d8bbwe",
    "Microsoft.BingWeather_8wekyb3d8bbwe",
    "Microsoft.GetHelp_8wekyb3d8bbwe",
    "Microsoft.Getstarted_8wekyb3d8bbwe",
    "Microsoft.Microsoft3DViewer_8wekyb3d8bbwe",
    "Microsoft.MicrosoftOfficeHub_8wekyb3d8bbwe",
    "Microsoft.MicrosoftSolitaireCollection_8wekyb3d8bbwe",
    "Microsoft.MicrosoftStickyNotes_8wekyb3d8bbwe",
    "Microsoft.MixedReality.Portal_8wekyb3d8bbwe",
    "Microsoft.MSPaint_8wekyb3d8bbwe",
    "Microsoft.Office",
    "Microsoft.Office.OneNote_8wekyb3d8bbwe",
    "Microsoft.OneDrive",
    "Microsoft.People_8wekyb3d8bbwe",
    "Microsoft.Print3D_8wekyb3d8bbwe",
    "Microsoft.ScreenSketch_8wekyb3d8bbwe",
    "Microsoft.SkypeApp_kzf8qxf38zg5c",
    "Microsoft.Wallet_8wekyb3d8bbwe",
    "Microsoft.WindowsAlarms_8wekyb3d8bbwe",
    "Microsoft.WindowsCalculator_8wekyb3d8bbwe",
    "Microsoft.WindowsCamera_8wekyb3d8bbwe",
    "microsoft.windowscommunicationsapps_8wekyb3d8bbwe",
    "Microsoft.WindowsFeedbackHub_8wekyb3d8bbwe",
    "Microsoft.WindowsMaps_8wekyb3d8bbwe",
    "Microsoft.WindowsSoundRecorder_8wekyb3d8bbwe",
    "Microsoft.Xbox.TCUI_8wekyb3d8bbwe",
    "Microsoft.XboxApp_8wekyb3d8bbwe",
    "Microsoft.XboxGameOverlay_8wekyb3d8bbwe",
    "Microsoft.XboxGamingOverlay_8wekyb3d8bbwe",
    "Microsoft.XboxIdentityProvider_8wekyb3d8bbwe",
    "Microsoft.XboxSpeechToTextOverlay_8wekyb3d8bbwe",
    "Microsoft.YourPhone_8wekyb3d8bbwe",
    "Microsoft.ZuneMusic_8wekyb3d8bbwe",
    "Microsoft.ZuneVideo_8wekyb3d8bbwe",
    "Microsoft.DevHome",
    "Microsoft.Windows.Ai.Copilot.Provider_8wekyb3d8bbwe",
    "Microsoft.Windows.DevHomeGitHubExtension_8wekyb3d8bbwe",
    "AD2F1837.HPPrinterControl_v10z8vjag6ke6",
    "AppUp.IntelGraphicsExperience_8j3eq9eme6ctt",
    "AppUp.IntelOptaneMemoryandStorageManagement_8j3eq9eme6ctt",
    "DellInc.DellDigitalDelivery_htrsf667h5kn2",
    "DellInc.DellSupportAssistforPCs_htrsf667h5kn2",
    "DellInc.PartnerPromo_htrsf667h5kn2",
    "NoMachine.NoMachine",
    "Microsoft.Teams",
    "Microsoft.Edge",
    "Microsoft.Edge.Update",
    "Microsoft.EdgeWebView2Runtime",
    "Microsoft.MicrosoftOfficeHub_8wekyb3d8bbwe",
    "Microsoft.MicrosoftEdge.Stable_8wekyb3d8bbwe",
    "Microsoft.Office.OneNote_8wekyb3d8bbwe",
    "Microsoft.OneDriveSync_8wekyb3d8bbwe",
    "Microsoft.OneDrive"
)

$appPackages | ForEach-Object {
    Log-Message "Désinstallation de $_"
    Try {
        Start-Process -NoNewWindow -Wait -FilePath winget -ArgumentList "uninstall --silent -e $_"
        Log-Message "$_ désinstallé avec succès."
    } Catch {
        Log-Message "Erreur lors de la désinstallation de ${_}: $($_.Exception.Message)"
        Add-Content -Path $logFile -Value $_.Exception.StackTrace
    }
    Wait-BetweenSteps -Seconds 1
}

Wait-BetweenSteps -Seconds 3

# Installation des logiciels nécessaires
Log-Step "Installation des logiciels nécessaires"
$apps = @(
    "Notepad++.Notepad++",
    "Adobe.Acrobat.Reader.64-bit",
    "7zip.7zip",
    "Google.Chrome",
    "Mozilla.Firefox",
    "Microsoft.Office",
    "Microsoft.OneDrive",
    "Microsoft.PowerToys",
    "VideoLAN.VLC",
    "GlennDelahoy.SnappyDriverInstallerOrigin",
    "9NF7JTB3B17P",
    "9P8LTPGCBZXD",
    "XP8BT8DW290MPQ",
    "voidtools.Everything",
    "TeamViewer.TeamViewer",
    "Microsoft.Teams",
    "XPFCXHF337W98S",
    "Oracle.JavaRuntimeEnvironment",
    "9PNVN8KMWWZF"
)

$apps | ForEach-Object {
    Log-Message "Installation de $_"
    Try {
        Start-Process -NoNewWindow -Wait -FilePath winget -ArgumentList "install --silent -e $_"
        Log-Message "$_ installé avec succès."
    } Catch {
        Log-Message "Erreur lors de l'installation de ${_}: $($_.Exception.Message)"
        Add-Content -Path $logFile -Value $_.Exception.StackTrace
    }
    Wait-BetweenSteps -Seconds 1
}

Wait-BetweenSteps -Seconds 3

# Nettoyage des fichiers temporaires
Log-Step "Nettoyage des fichiers temporaires"
Try {
    Get-ChildItem -Path $env:TEMP\* -Recurse -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path "$env:Windir\Temp\*" -Recurse -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Log-Message "Fichiers temporaires nettoyés avec succès."
} Catch {
    Log-Message "Erreur lors du nettoyage des fichiers temporaires: $($_.Exception.Message)"
    Add-Content -Path $logFile -Value $_.Exception.StackTrace
}

Wait-BetweenSteps -Seconds 3

# Désactivation de Recall
Log-Step "Désactivation de Recall"
function Disable-Recall {
    Dism /Online /Disable-Feature /Featurename:Recall /NoRestart | Out-Null
}

Wait-BetweenSteps -Seconds 3

# Optimisation du registre
Log-Step "Optimisation du registre"

function Set-LimpRegTweaksApply {
    # Create Registry Keys
    $MultilineComment = @"
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot]
"TurnOffWindowsCopilot"=dword:00000001

[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Windows Chat]
"ChatIcon"=dword:00000003

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Communications]
"ConfigureChatAutoInstall"=dword:00000000

[HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\Windows Search]
"AllowCortana"=dword:00000000

[HKEY_LOCAL_MACHINE\Software\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting]
"Value"=dword:00000000

[HKEY_LOCAL_MACHINE\Software\Microsoft\PolicyManager\default\WiFi\AllowAutoConnectToWiFiSenseHotspots]
"Value"=dword:00000000

[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\GameDVR]
"AllowGameDVR"=dword:00000000

[HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\CloudContent]
"DisableWindowsConsumerFeatures"=dword:00000000
"DisableConsumerAccountStateContent"=dword:00000001
"DisableCloudOptimizedContent"=dword:00000001

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem]
"LongPathsEnabled"=dword:00000001

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management]
"ClearPageFileAtShutdown"=dword:00000000

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\PriorityControl]
"Win32PrioritySeparation"=dword:00000026

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile]
"SystemResponsiveness"=dword:0000000a
"NetworkThrottlingIndex"=dword:0000000a

[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Appx]
"AllowAutomaticAppArchiving"=dword:00000000

[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Dsh]
"AllowNewsAndInterests"=dword:00000000

[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\NewsAndInterests\AllowNewsAndInterests]
"value"=dword:00000000

[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds]
"EnableFeeds"=dword:00000000

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers]
"HwSchMode"=dword:00000002

[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\StorageSense]
"AllowStorageSenseGlobal"=dword:00000000

[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\WindowsStore]
"AutoDownload"=dword:00000002

[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy]
"LetAppsRunInBackground"=dword:00000002

[-HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}]
[-HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}]

[-HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}]

[HKEY_USERS\.DEFAULT\Control Panel\Mouse]
"MouseSpeed"="0"
"MouseThreshold1"="0"
"MouseThreshold2"="0"

[HKEY_CLASSES_ROOT\Applications\photoviewer.dll\shell\open]
"MuiVerb"="@photoviewer.dll,-3043"

[HKEY_CLASSES_ROOT\Applications\photoviewer.dll\shell\open\command]
@=hex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,\
  00,5c,00,53,00,79,00,73,00,74,00,65,00,6d,00,33,00,32,00,5c,00,72,00,75,00,\
  6e,00,64,00,6c,00,6c,00,33,00,32,00,2e,00,65,00,78,00,65,00,20,00,22,00,25,\
  00,50,00,72,00,6f,00,67,00,72,00,61,00,6d,00,46,00,69,00,6c,00,65,00,73,00,\
  25,00,5c,00,57,00,69,00,6e,00,64,00,6f,00,77,00,73,00,20,00,50,00,68,00,6f,\
  00,74,00,6f,00,20,00,56,00,69,00,65,00,77,00,65,00,72,00,5c,00,50,00,68,00,\
  6f,00,74,00,6f,00,56,00,69,00,65,00,77,00,65,00,72,00,2e,00,64,00,6c,00,6c,\
  00,22,00,2c,00,20,00,49,00,6d,00,61,00,67,00,65,00,56,00,69,00,65,00,77,00,\
  5f,00,46,00,75,00,6c,00,6c,00,73,00,63,00,72,00,65,00,65,00,6e,00,20,00,25,\
  00,31,00,00,00

[HKEY_CLASSES_ROOT\Applications\photoviewer.dll\shell\open\DropTarget]
"Clsid"="{FFE2A43C-56B9-4bf5-9A79-CC6D4285608A}"

[HKEY_CLASSES_ROOT\PhotoViewer.FileAssoc.Bitmap]
"ImageOptionFlags"=dword:00000001
"FriendlyTypeName"=hex(2):40,00,25,00,50,00,72,00,6f,00,67,00,72,00,61,00,6d,\
  00,46,00,69,00,6c,00,65,00,73,00,25,00,5c,00,57,00,69,00,6e,00,64,00,6f,00,\
  77,00,73,00,20,00,50,00,68,00,6f,00,74,00,6f,00,20,00,56,00,69,00,65,00,77,\
  00,65,00,72,00,5c,00,50,00,68,00,6f,00,74,00,6f,00,56,00,69,00,65,00,77,00,\
  65,00,72,00,2e,00,64,00,6c,00,6c,00,2c,00,2d,00,33,00,30,00,35,00,36,00,00,\
  00

[HKEY_CLASSES_ROOT\PhotoViewer.FileAssoc.Bitmap\DefaultIcon]
@="%SystemRoot%\\System32\\imageres.dll,-70"

[HKEY_CLASSES_ROOT\PhotoViewer.FileAssoc.Bitmap\shell\open\command]
@=hex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,\
  00,5c,00,53,00,79,00,73,00,74,00,65,00,6d,00,33,00,32,00,5c,00,72,00,75,00,\
  6e,00,64,00,6c,00,6c,00,33,00,32,00,2e,00,65,00,78,00,65,00,20,00,22,00,25,\
  00,50,00,72,00,6f,00,67,00,72,00,61,00,6d,00,46,00,69,00,6c,00,65,00,73,00,\
  25,00,5c,00,57,00,69,00,6e,00,64,00,6f,00,77,00,73,00,20,00,50,00,68,00,6f,\
  00,74,00,6f,00,20,00,56,00,69,00,65,00,77,00,65,00,72,00,5c,00,50,00,68,00,\
  6f,00,74,00,6f,00,56,00,69,00,65,00,77,00,65,00,72,00,2e,00,64,00,6c,00,6c,\
  00,22,00,2c,00,20,00,49,00,6d,00,61,00,67,00,65,00,56,00,69,00,65,00,77,00,\
  5f,00,46,00,75,00,6c,00,6c,00,73,00,63,00,72,00,65,00,65,00,6e,00,20,00,25,\
  00,31,00,00,00

[HKEY_CLASSES_ROOT\PhotoViewer.FileAssoc.Bitmap\shell\open\DropTarget]
"Clsid"="{FFE2A43C-56B9-4bf5-9A79-CC6D4285608A}"

[HKEY_CLASSES_ROOT\PhotoViewer.FileAssoc.JFIF]
"EditFlags"=dword:00010000
"ImageOptionFlags"=dword:00000001
"FriendlyTypeName"=hex(2):40,00,25,00,50,00,72,00,6f,00,67,00,72,00,61,00,6d,\
  00,46,00,69,00,6c,00,65,00,73,00,25,00,5c,00,57,00,69,00,6e,00,64,00,6f,00,\
  77,00,73,00,20,00,50,00,68,00,6f,00,74,00,6f,00,20,00,56,00,69,00,65,00,77,\
  00,65,00,72,00,5c,00,50,00,68,00,6f,00,74,00,6f,00,56,00,69,00,65,00,77,00,\
  65,00,72,00,2e,00,64,00,6c,00,6c,00,2c,00,2d,00,33,00,30,00,35,00,35,00,00,\
  00

[HKEY_CLASSES_ROOT\PhotoViewer.FileAssoc.JFIF\DefaultIcon]
@="%SystemRoot%\\System32\\imageres.dll,-72"

[HKEY_CLASSES_ROOT\PhotoViewer.FileAssoc.JFIF\shell\open]
"MuiVerb"=hex(2):40,00,25,00,50,00,72,00,6f,00,67,00,72,00,61,00,6d,00,46,00,\
  69,00,6c,00,65,00,73,00,25,00,5c,00,57,00,69,00,6e,00,64,00,6f,00,77,00,73,\
  00,20,00,50,00,68,00,6f,00,74,00,6f,00,20,00,56,00,69,00,65,00,77,00,65,00,\
  72,00,5c,00,70,00,68,00,6f,00,74,00,6f,00,76,00,69,00,65,00,77,00,65,00,72,\
  00,2e,00,64,00,6c,00,6c,00,2c,00,2d,00,33,00,30,00,34,00,33,00,00,00

[HKEY_CLASSES_ROOT\PhotoViewer.FileAssoc.JFIF\shell\open\command]
@=hex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,\
  00,5c,00,53,00,79,00,73,00,74,00,65,00,6d,00,33,00,32,00,5c,00,72,00,75,00,\
  6e,00,64,00,6c,00,6c,00,33,00,32,00,2e,00,65,00,78,00,65,00,20,00,22,00,25,\
  00,50,00,72,00,6f,00,67,00,72,00,61,00,6d,00,46,00,69,00,6c,00,65,00,73,00,\
  25,00,5c,00,57,00,69,00,6e,00,64,00,6f,00,77,00,73,00,20,00,50,00,68,00,6f,\
  00,74,00,6f,00,20,00,56,00,69,00,65,00,77,00,65,00,72,00,5c,00,50,00,68,00,\
  6f,00,74,00,6f,00,56,00,69,00,65,00,77,00,65,00,72,00,2e,00,64,00,6c,00,6c,\
  00,22,00,2c,00,20,00,49,00,6d,00,61,00,67,00,65,00,56,00,69,00,65,00,77,00,\
  5f,00,46,00,75,00,6c,00,6c,00,73,00,63,00,72,00,65,00,65,00,6e,00,20,00,25,\
  00,31,00,00,00

[HKEY_CLASSES_ROOT\PhotoViewer.FileAssoc.JFIF\shell\open\DropTarget]
"Clsid"="{FFE2A43C-56B9-4bf5-9A79-CC6D4285608A}"

[HKEY_CLASSES_ROOT\PhotoViewer.FileAssoc.Jpeg]
"EditFlags"=dword:00010000
"ImageOptionFlags"=dword:00000001
"FriendlyTypeName"=hex(2):40,00,25,00,50,00,72,00,6f,00,67,00,72,00,61,00,6d,\
  00,46,00,69,00,6c,00,65,00,73,00,25,00,5c,00,57,00,69,00,6e,00,64,00,6f,00,\
  77,00,73,00,20,00,50,00,68,00,6f,00,74,00,6f,00,20,00,56,00,69,00,65,00,77,\
  00,65,00,72,00,5c,00,50,00,68,00,6f,00,74,00,6f,00,56,00,69,00,65,00,77,00,\
  65,00,72,00,2e,00,64,00,6c,00,6c,00,2c,00,2d,00,33,00,30,00,35,00,35,00,00,\
  00

[HKEY_CLASSES_ROOT\PhotoViewer.FileAssoc.Jpeg\DefaultIcon]
@="%SystemRoot%\\System32\\imageres.dll,-72"

[HKEY_CLASSES_ROOT\PhotoViewer.FileAssoc.Jpeg\shell\open]
"MuiVerb"=hex(2):40,00,25,00,50,00,72,00,6f,00,67,00,72,00,61,00,6d,00,46,00,\
  69,00,6c,00,65,00,73,00,25,00,5c,00,57,00,69,00,6e,00,64,00,6f,00,77,00,73,\
  00,20,00,50,00,68,00,6f,00,74,00,6f,00,20,00,56,00,69,00,65,00,77,00,65,00,\
  72,00,5c,00,70,00,68,00,6f,00,74,00,6f,00,76,00,69,00,65,00,77,00,65,00,72,\
  00,2e,00,64,00,6c,00,6c,00,2c,00,2d,00,33,00,30,00,34,00,33,00,00,00

[HKEY_CLASSES_ROOT\PhotoViewer.FileAssoc.Jpeg\shell\open\command]
@=hex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,\
  00,5c,00,53,00,79,00,73,00,74,00,65,00,6d,00,33,00,32,00,5c,00,72,00,75,00,\
  6e,00,64,00,6c,00,6c,00,33,00,32,00,2e,00,65,00,78,00,65,00,20,00,22,00,25,\
  00,50,00,72,00,6f,00,67,00,72,00,61,00,6d,00,46,00,69,00,6c,00,65,00,73,00,\
  25,00,5c,00,57,00,69,00,6e,00,64,00,6f,00,77,00,73,00,20,00,50,00,68,00,6f,\
  00,74,00,6f,00,20,00,56,00,69,00,65,00,77,00,65,00,72,00,5c,00,50,00,68,00,\
  6f,00,74,00,6f,00,56,00,69,00,65,00,77,00,65,00,72,00,2e,00,64,00,6c,00,6c,\
  00,22,00,2c,00,20,00,49,00,6d,00,61,00,67,00,65,00,56,00,69,00,65,00,77,00,\
  5f,00,46,00,75,00,6c,00,6c,00,73,00,63,00,72,00,65,00,65,00,6e,00,20,00,25,\
  00,31,00,00,00

[HKEY_CLASSES_ROOT\PhotoViewer.FileAssoc.Jpeg\shell\open\DropTarget]
"Clsid"="{FFE2A43C-56B9-4bf5-9A79-CC6D4285608A}"

[HKEY_CLASSES_ROOT\PhotoViewer.FileAssoc.Gif]
"ImageOptionFlags"=dword:00000001
"FriendlyTypeName"=hex(2):40,00,25,00,50,00,72,00,6f,00,67,00,72,00,61,00,6d,\
  00,46,00,69,00,6c,00,65,00,73,00,25,00,5c,00,57,00,69,00,6e,00,64,00,6f,00,\
  77,00,73,00,20,00,50,00,68,00,6f,00,74,00,6f,00,20,00,56,00,69,00,65,00,77,\
  00,65,00,72,00,5c,00,50,00,68,00,6f,00,74,00,6f,00,56,00,69,00,65,00,77,00,\
  65,00,72,00,2e,00,64,00,6c,00,6c,00,2c,00,2d,00,33,00,30,00,35,00,37,00,00,\
  00

[HKEY_CLASSES_ROOT\PhotoViewer.FileAssoc.Gif\DefaultIcon]
@="%SystemRoot%\\System32\\imageres.dll,-83"

[HKEY_CLASSES_ROOT\PhotoViewer.FileAssoc.Gif\shell\open\command]
@=hex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,\
  00,5c,00,53,00,79,00,73,00,74,00,65,00,6d,00,33,00,32,00,5c,00,72,00,75,00,\
  6e,00,64,00,6c,00,6c,00,33,00,32,00,2e,00,65,00,78,00,65,00,20,00,22,00,25,\
  00,50,00,72,00,6f,00,67,00,72,00,61,00,6d,00,46,00,69,00,6c,00,65,00,73,00,\
  25,00,5c,00,57,00,69,00,6e,00,64,00,6f,00,77,00,73,00,20,00,50,00,68,00,6f,\
  00,74,00,6f,00,20,00,56,00,69,00,65,00,77,00,65,00,72,00,5c,00,50,00,68,00,\
  6f,00,74,00,6f,00,56,00,69,00,65,00,77,00,65,00,72,00,2e,00,64,00,6c,00,6c,\
  00,22,00,2c,00,20,00,49,00,6d,00,61,00,67,00,65,00,56,00,69,00,65,00,77,00,\
  5f,00,46,00,75,00,6c,00,6c,00,73,00,63,00,72,00,65,00,65,00,6e,00,20,00,25,\
  00,31,00,00,00

[HKEY_CLASSES_ROOT\PhotoViewer.FileAssoc.Gif\shell\open\DropTarget]
"Clsid"="{FFE2A43C-56B9-4bf5-9A79-CC6D4285608A}"

[HKEY_CLASSES_ROOT\PhotoViewer.FileAssoc.Png]
"ImageOptionFlags"=dword:00000001
"FriendlyTypeName"=hex(2):40,00,25,00,50,00,72,00,6f,00,67,00,72,00,61,00,6d,\
  00,46,00,69,00,6c,00,65,00,73,00,25,00,5c,00,57,00,69,00,6e,00,64,00,6f,00,\
  77,00,73,00,20,00,50,00,68,00,6f,00,74,00,6f,00,20,00,56,00,69,00,65,00,77,\
  00,65,00,72,00,5c,00,50,00,68,00,6f,00,74,00,6f,00,56,00,69,00,65,00,77,00,\
  65,00,72,00,2e,00,64,00,6c,00,6c,00,2c,00,2d,00,33,00,30,00,35,00,37,00,00,\
  00

[HKEY_CLASSES_ROOT\PhotoViewer.FileAssoc.Png\DefaultIcon]
@="%SystemRoot%\\System32\\imageres.dll,-71"

[HKEY_CLASSES_ROOT\PhotoViewer.FileAssoc.Png\shell\open\command]
@=hex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,\
  00,5c,00,53,00,79,00,73,00,74,00,65,00,6d,00,33,00,32,00,5c,00,72,00,75,00,\
  6e,00,64,00,6c,00,6c,00,33,00,32,00,2e,00,65,00,78,00,65,00,20,00,22,00,25,\
  00,50,00,72,00,6f,00,67,00,72,00,61,00,6d,00,46,00,69,00,6c,00,65,00,73,00,\
  25,00,5c,00,57,00,69,00,6e,00,64,00,6f,00,77,00,73,00,20,00,50,00,68,00,6f,\
  00,74,00,6f,00,20,00,56,00,69,00,65,00,77,00,65,00,72,00,5c,00,50,00,68,00,\
  6f,00,74,00,6f,00,56,00,69,00,65,00,77,00,65,00,72,00,2e,00,64,00,6c,00,6c,\
  00,22,00,2c,00,20,00,49,00,6d,00,61,00,67,00,65,00,56,00,69,00,65,00,77,00,\
  5f,00,46,00,75,00,6c,00,6c,00,73,00,63,00,72,00,65,00,65,00,6e,00,20,00,25,\
  00,31,00,00,00

[HKEY_CLASSES_ROOT\PhotoViewer.FileAssoc.Png\shell\open\DropTarget]
"Clsid"="{FFE2A43C-56B9-4bf5-9A79-CC6D4285608A}"

[HKEY_CLASSES_ROOT\PhotoViewer.FileAssoc.Wdp]
"EditFlags"=dword:00010000
"ImageOptionFlags"=dword:00000001

[HKEY_CLASSES_ROOT\PhotoViewer.FileAssoc.Wdp\DefaultIcon]
@="%SystemRoot%\\System32\\wmphoto.dll,-400"

[HKEY_CLASSES_ROOT\PhotoViewer.FileAssoc.Wdp\shell\open]
"MuiVerb"=hex(2):40,00,25,00,50,00,72,00,6f,00,67,00,72,00,61,00,6d,00,46,00,\
  69,00,6c,00,65,00,73,00,25,00,5c,00,57,00,69,00,6e,00,64,00,6f,00,77,00,73,\
  00,20,00,50,00,68,00,6f,00,74,00,6f,00,20,00,56,00,69,00,65,00,77,00,65,00,\
  72,00,5c,00,70,00,68,00,6f,00,74,00,6f,00,76,00,69,00,65,00,77,00,65,00,72,\
  00,2e,00,64,00,6c,00,6c,00,2c,00,2d,00,33,00,30,00,34,00,33,00,00,00

[HKEY_CLASSES_ROOT\PhotoViewer.FileAssoc.Wdp\shell\open\command]
@=hex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,\
  00,5c,00,53,00,79,00,73,00,74,00,65,00,6d,00,33,00,32,00,5c,00,72,00,75,00,\
  6e,00,64,00,6c,00,6c,00,33,00,32,00,2e,00,65,00,78,00,65,00,20,00,22,00,25,\
  00,50,00,72,00,6f,00,67,00,72,00,61,00,6d,00,46,00,69,00,6c,00,65,00,73,00,\
  25,00,5c,00,57,00,69,00,6e,00,64,00,6f,00,77,00,73,00,20,00,50,00,68,00,6f,\
  00,74,00,6f,00,20,00,56,00,69,00,65,00,77,00,65,00,72,00,5c,00,50,00,68,00,\
  6f,00,74,00,6f,00,56,00,69,00,65,00,77,00,65,00,72,00,2e,00,64,00,6c,00,6c,\
  00,22,00,2c,00,20,00,49,00,6d,00,61,00,67,00,65,00,56,00,69,00,65,00,77,00,\
  5f,00,46,00,75,00,6c,00,6c,00,73,00,63,00,72,00,65,00,65,00,6e,00,20,00,25,\
  00,31,00,00,00

[HKEY_CLASSES_ROOT\PhotoViewer.FileAssoc.Wdp\shell\open\DropTarget]
"Clsid"="{FFE2A43C-56B9-4bf5-9A79-CC6D4285608A}"

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities]
"ApplicationDescription"="@%ProgramFiles%\\Windows Photo Viewer\\photoviewer.dll,-3069"
"ApplicationName"="@%ProgramFiles%\\Windows Photo Viewer\\photoviewer.dll,-3009"

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities\FileAssociations]
".jpg"="PhotoViewer.FileAssoc.Jpeg"
".wdp"="PhotoViewer.FileAssoc.Wdp"
".jfif"="PhotoViewer.FileAssoc.JFIF"
".dib"="PhotoViewer.FileAssoc.Bitmap"
".png"="PhotoViewer.FileAssoc.Png"
".jxr"="PhotoViewer.FileAssoc.Wdp"
".bmp"="PhotoViewer.FileAssoc.Bitmap"
".jpe"="PhotoViewer.FileAssoc.Jpeg"
".jpeg"="PhotoViewer.FileAssoc.Jpeg"
".gif"="PhotoViewer.FileAssoc.Gif"
".tif"="PhotoViewer.FileAssoc.Tiff"
".tiff"="PhotoViewer.FileAssoc.Tiff"

[HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\System]
"VerboseStatus"=dword:00000001

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Installer]
"DisableCoInstallers"=dword:00000001

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control]
"SvcHostSplitThresholdInKB"=dword:ffffffff

"@
    Set-Content -Path "$env:TEMP\Optimize_LocalMachine_Registry_Limp.reg" -Value $MultilineComment -Force
    # edit reg file
    $path = "$env:TEMP\Optimize_LocalMachine_Registry_Limp.reg"
    (Get-Content $path) -replace "\?", "$" | Out-File $path
    # import reg file
    Regedit.exe /S "$env:TEMP\Optimize_LocalMachine_Registry_Limp.reg"
    Show-Header
    Write-Host "Registry Tweaks Applied." -ForegroundColor Green
    Wait-IfNotSpecialize
}
Set-LimpRegTweaksApply

# Start of Visual Tweaks
function Set-LimpUserRegApply {
    # Create Registry Keys
    $MultilineComment = @"
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\Microsoft\Narrator\NoRoam]
"DuckAudio"=dword:00000000
"WinEnterLaunchEnabled"=dword:00000000
"ScriptingEnabled"=dword:00000000
"OnlineServicesEnabled"=dword:00000000
"EchoToggleKeys"=dword:00000000

[HKEY_CURRENT_USER\Software\Microsoft\Narrator]
"NarratorCursorHighlight"=dword:00000000
"CoupleNarratorCursorKeyboard"=dword:00000000
"IntonationPause"=dword:00000000
"ReadHints"=dword:00000000
"ErrorNotificationType"=dword:00000000
"EchoChars"=dword:00000000
"EchoWords"=dword:00000000

[HKEY_CURRENT_USER\SOFTWARE\Microsoft\Narrator\NarratorHome]
"MinimizeType"=dword:00000000
"AutoStart"=dword:00000000

[HKEY_CURRENT_USER\Software\Microsoft\Ease of Access]
"selfvoice"=dword:00000000
"selfscan"=dword:00000000

[HKEY_CURRENT_USER\Control Panel\Accessibility]
"Sound on Activation"=dword:00000000
"Warning Sounds"=dword:00000000

[HKEY_CURRENT_USER\Control Panel\Accessibility\HighContrast]
"Flags"="4194"

[HKEY_CURRENT_USER\Control Panel\Accessibility\Keyboard Response]
"Flags"="2"
"AutoRepeatRate"="0"
"AutoRepeatDelay"="0"

[HKEY_CURRENT_USER\Control Panel\Accessibility\MouseKeys]
"Flags"="130"
"MaximumSpeed"="39"
"TimeToMaximumSpeed"="3000"

[HKEY_CURRENT_USER\Control Panel\Accessibility\StickyKeys]
"Flags"="2"

[HKEY_CURRENT_USER\Control Panel\Accessibility\ToggleKeys]
"Flags"="34"

[HKEY_CURRENT_USER\Control Panel\Accessibility\SoundSentry]
"Flags"="0"
"FSTextEffect"="0"
"TextEffect"="0"
"WindowsEffect"="0"

[HKEY_CURRENT_USER\Control Panel\Accessibility\SlateLaunch]
"ATapp"=""
"LaunchAT"=dword:00000000

[HKEY_CURRENT_USER\Control Panel\TimeDate]
"DstNotification"=dword:00000000

[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced]
"LaunchTo"=dword:00000001
"HideFileExt"=dword:00000000
"FolderContentsInfoTip"=dword:00000001
"ShowInfoTip"=dword:00000001
"ShowPreviewHandlers"=dword:00000000
"ShowStatusBar"=dword:00000000
"ShowSyncProviderNotifications"=dword:00000000
"SharingWizardOn"=dword:00000000
"TaskbarAnimations"=dword:00000000
"IconsOnly"=dword:00000000
"ListviewAlphaSelect"=dword:00000000
"ListviewShadow"=dword:00000000
"Start_Layout"=dword:00000001
"Start_AccountNotifications"=dword:00000001
"TaskbarAl"=dword:00000000
"TaskbarMn"=dword:00000000
"ShowTaskViewButton"=dword:00000000
"ShowCopilotButton"=dword:00000000
"Start_IrisRecommendations"=dword:00000000
"TaskbarSn"=dword:00000000
"SnapAssist"=dword:00000000
"DITest"=dword:00000000
"EnableSnapBar"=dword:00000000
"EnableTaskGroups"=dword:00000000
"EnableSnapAssistFlyout"=dword:00000000
"SnapFill"=dword:00000000
"JointResize"=dword:00000000
"MultiTaskingAltTabFilter"=dword:00000003

[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer]
"ShowFrequent"=dword:00000000
"ShowCloudFilesInQuickAccess"=dword:00000000
"EnableAutoTray"=dword:00000000

[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState]
"FullPath"=dword:00000001

[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects]
"VisualFXSetting"=dword:00000003

[HKEY_CURRENT_USER\Control Panel\Desktop]
"UserPreferencesMask"=hex(2):90,12,03,80,10,00,00,00
"FontSmoothing"="2"
"LogPixels"=dword:00000060
"Win8DpiScaling"=dword:00000001
"EnablePerProcessSystemDPI"=dword:00000000
"MenuShowDelay"="0"

[HKEY_CURRENT_USER\Software\Microsoft\Multimedia\Audio]
"UserDuckingPreference"=dword:00000003

[HKEY_CURRENT_USER\Control Panel\Mouse]
"MouseSpeed"="0"
"MouseThreshold1"="0"
"MouseThreshold2"="0"
"MouseSensitivity"="10"
"SmoothMouseXCurve"=hex:\
	00,00,00,00,00,00,00,00,\
	C0,CC,0C,00,00,00,00,00,\
	80,99,19,00,00,00,00,00,\
	40,66,26,00,00,00,00,00,\
	00,33,33,00,00,00,00,00
"SmoothMouseYCurve"=hex:\
	00,00,00,00,00,00,00,00,\
	00,00,38,00,00,00,00,00,\
	00,00,70,00,00,00,00,00,\
	00,00,A8,00,00,00,00,00,\
	00,00,E0,00,00,00,00,00

[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications]
"EnableAccountNotifications"=dword:00000000

[HKEY_CURRENT_USER\Software\Microsoft\Speech_OneCore\Settings\VoiceActivation\UserPreferenceForAllApps]
"AgentActivationEnabled"=dword:00000000
"AgentActivationLastUsed"=dword:00000000

[HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\bluetoothSync]
"Value"="Deny"

[HKEY_CURRENT_USER\Software\Microsoft\InputPersonalization]
"RestrictImplicitInkCollection"=dword:00000001
"RestrictImplicitTextCollection"=dword:00000001

[HKEY_CURRENT_USER\Software\Microsoft\InputPersonalization\TrainedDataStore]
"HarvestContacts"=dword:00000000

[HKEY_CURRENT_USER\Software\Microsoft\Personalization\Settings]
"AcceptedPrivacyPolicy"=dword:00000000

[HKEY_CURRENT_USER\SOFTWARE\Microsoft\Siuf\Rules]
"NumberOfSIUFInPeriod"=dword:00000000
"PeriodInNanoSeconds"=-

[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\SearchSettings]
"IsDynamicSearchBoxEnabled"=dword:00000000
"IsDeviceSearchHistoryEnabled"=dword:00000000
"SafeSearchMode"=dword:00000000
"IsAADCloudSearchEnabled"=dword:00000000
"IsMSACloudSearchEnabled"=dword:00000000

[HKEY_CURRENT_USER\Software\Microsoft\ScreenMagnifier]
"FollowCaret"=dword:00000000
"FollowNarrator"=dword:00000000
"FollowMouse"=dword:00000000
"FollowFocus"=dword:00000000

[HKEY_CURRENT_USER\System\GameConfigStore]
"GameDVR_Enabled"=dword:00000000

[HKEY_CURRENT_USER\Software\Microsoft\GameBar]
"UseNexusForGameBarEnabled"=dword:00000000
"AutoGameModeEnabled"=dword:00000001

[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\GameDVR]
"AppCaptureEnabled"=dword:00000000
"AudioEncodingBitrate"=dword:0001f400
"AudioCaptureEnabled"=dword:00000000
"CustomVideoEncodingBitrate"=dword:003d0900
"CustomVideoEncodingHeight"=dword:000002d0
"CustomVideoEncodingWidth"=dword:00000500
"HistoricalBufferLength"=dword:0000001e
"HistoricalBufferLengthUnit"=dword:00000001
"HistoricalCaptureEnabled"=dword:00000000
"HistoricalCaptureOnBatteryAllowed"=dword:00000001
"HistoricalCaptureOnWirelessDisplayAllowed"=dword:00000001
"MaximumRecordLength"=hex(b):00,D0,88,C3,10,00,00,00
"VideoEncodingBitrateMode"=dword:00000002
"VideoEncodingResolutionMode"=dword:00000002
"VideoEncodingFrameRateMode"=dword:00000000
"EchoCancellationEnabled"=dword:00000001
"CursorCaptureEnabled"=dword:00000000
"VKToggleGameBar"=dword:00000000
"VKMToggleGameBar"=dword:00000000
"VKSaveHistoricalVideo"=dword:00000000
"VKMSaveHistoricalVideo"=dword:00000000
"VKToggleRecording"=dword:00000000
"VKMToggleRecording"=dword:00000000
"VKTakeScreenshot"=dword:00000000
"VKMTakeScreenshot"=dword:00000000
"VKToggleRecordingIndicator"=dword:00000000
"VKMToggleRecordingIndicator"=dword:00000000
"VKToggleMicrophoneCapture"=dword:00000000
"VKMToggleMicrophoneCapture"=dword:00000000
"VKToggleCameraCapture"=dword:00000000
"VKMToggleCameraCapture"=dword:00000000
"VKToggleBroadcast"=dword:00000000
"VKMToggleBroadcast"=dword:00000000
"MicrophoneCaptureEnabled"=dword:00000000
"SystemAudioGain"=hex(b):10,27,00,00,00,00,00,00
"MicrophoneGain"=hex(b):10,27,00,00,00,00,00,00

[HKEY_CURRENT_USER\Software\Microsoft\input\Settings]
"IsVoiceTypingKeyEnabled"=dword:00000000
"InsightsEnabled"=dword:00000000

[HKEY_CURRENT_USER\Software\Microsoft\TabletTip\1.7]
"EnableAutoShiftEngage"=dword:00000000
"EnableKeyAudioFeedback"=dword:00000000
"EnableDoubleTapSpace"=dword:00000000
"IsKeyBackgroundEnabled"=dword:00000000

[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer]
"DisableSearchBoxSuggestions"=dword:00000001

[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Search]
"SearchboxTaskbarMode"=dword:00000000

[HKEY_CURRENT_USER\Software\Microsoft\Lighting]
"AmbientLightingEnabled"=dword:00000000
"ControlledByForegroundApp"=dword:00000000
"UseSystemAccentColor"=dword:00000000

[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer]
"NoStartMenuMFUprogramsList"=-
"NoInstrumentation"=-
"HideSCAMeetNow"=dword:00000001

[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\Windows\WindowsCopilot]
"TurnOffWindowsCopilot"=dword:00000001

[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager]
"ContentDeliveryAllowed"=dword:00000000
"FeatureManagementEnabled"=dword:00000000
"OemPreInstalledAppsEnabled"=dword:00000000
"PreInstalledAppsEnabled"=dword:00000000
"PreInstalledAppsEverEnabled"=dword:00000000
"RotatingLockScreenEnabled"=dword:00000000
"RotatingLockScreenOverlayEnabled"=dword:00000000
"SilentInstalledAppsEnabled"=dword:00000000
"SlideshowEnabled"=dword:00000000
"SoftLandingEnabled"=dword:00000000
"SubscribedContent-310093Enabled"=dword:00000000
"SubscribedContent-314563Enabled"=dword:00000000
"SubscribedContent-338388Enabled"=dword:00000000
"SubscribedContent-338389Enabled"=dword:00000000
"SubscribedContent-338393Enabled"=dword:00000000
"SubscribedContent-353694Enabled"=dword:00000000
"SubscribedContent-353696Enabled"=dword:00000000
"SubscribedContent-353698Enabled"=dword:00000000
"SubscribedContentEnabled"=dword:00000000
"SystemPaneSuggestionsEnabled"=dword:00000000

[HKEY_CURRENT_USER\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}]
"System.IsPinnedToNameSpaceTree"=dword:00000000

[HKEY_CURRENT_USER\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32]
@=""

[HKEY_CURRENT_USER\Software\Microsoft\Office\16.0\Outlook\Options\General]
"HideNewOutlookToggle"=dword:00000001

"@

    Set-Content -Path "$env:TEMP\Visual_Tweaks_Limp.reg" -Value $MultilineComment -Force
    # edit reg file
    $path = "$env:TEMP\Visual_Tweaks_Limp.reg"
    (Get-Content $path) -replace "\?", "$" | Out-File $path
    # import reg file
    Regedit.exe /S "$env:TEMP\Visual_Tweaks_Limp.reg"
    Show-Header
    Write-Host "Limpidit Visual Tweaks Applied." -ForegroundColor Green
    Wait-IfNotSpecialize
}
Set-LimpUserRegApply

Wait-BetweenSteps -Seconds 3

# Vérification de l'intégrité des fichiers système
Log-Step "Vérification de l'intégrité des fichiers système"
Try {
    Start-Process -NoNewWindow -Wait -FilePath "sfc.exe" -ArgumentList "/scannow"
    Log-Message "Vérification de l'intégrité des fichiers système terminée avec succès."
} Catch {
    Log-Message "Erreur lors de la vérification de l'intégrité des fichiers système: $($_.Exception.Message)"
    Add-Content -Path $logFile -Value $_.Exception.StackTrace
}

Wait-BetweenSteps -Seconds 3

# Nettoyage de l'image Windows
Log-Step "Nettoyage de l'image Windows"
Try {
    Start-Process -NoNewWindow -Wait -FilePath "Dism.exe" -ArgumentList "/Online /Cleanup-Image /RestoreHealth"
    Log-Message "Nettoyage de l'image Windows terminé avec succès."
} Catch {
    Log-Message "Erreur lors du nettoyage de l'image Windows: $($_.Exception.Message)"
    Add-Content -Path $logFile -Value $_.Exception.StackTrace
}

Wait-BetweenSteps -Seconds 3

# Mise à jour des mises à jour de sécurité
Log-Step "Recherche et installation des mises à jour de sécurité disponibles"
Try {
    Install-Module PSWindowsUpdate -Force -ErrorAction SilentlyContinue
    Import-Module PSWindowsUpdate
    Install-WindowsUpdate -AcceptAll -IgnoreReboot
    Log-Message "Mises à jour de sécurité installées avec succès."
} Catch {
    Log-Message "Erreur lors de la mise à jour des mises à jour de sécurité : $($_.Exception.Message)"
    Add-Content -Path $logFile -Value $_.Exception.StackTrace
}

Wait-BetweenSteps -Seconds 3

# Redémarrage à la fin du script
Log-Step "Script terminé. Voulez-vous redémarrer le système maintenant ? (O/N)"
$rebootConfirmation = Read-Host "Voulez-vous redémarrer le système maintenant (O/N)?"
if ($rebootConfirmation -eq "O") {
    Log-Message "Redémarrage du système."
    Start-Sleep -Seconds 5 # Délai pour permettre la lecture des logs
    Restart-Computer
} else {
    Log-Message "Redémarrage annulé. Il est recommandé de redémarrer le système pour appliquer toutes les modifications."
    Write-Host "Le script est terminé. Appuyez sur une touche pour fermer la fenêtre." -ForegroundColor Yellow
    Read-Host -Prompt "Appuyez sur [Entrée] pour fermer la fenêtre"
}
