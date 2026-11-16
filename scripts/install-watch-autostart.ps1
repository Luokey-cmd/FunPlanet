# FunPlanet adb reverse watcher - install autostart
# 1) Creates a shortcut in the Windows Startup folder, so the watcher
#    starts automatically every time you log in to Windows.
# 2) Starts the watcher right now as well, so you do not need to reboot.
# No administrator rights needed. To remove: uninstall-watch-autostart.ps1

$ErrorActionPreference = 'Stop'

$watcher = Join-Path $PSScriptRoot 'adb-reverse-watch.ps1'
if (-not (Test-Path $watcher)) {
  Write-Host "ERROR: adb-reverse-watch.ps1 not found next to this script: $watcher" -ForegroundColor Red
  exit 1
}

$startupDir = [Environment]::GetFolderPath('Startup')
$shortcutPath = Join-Path $startupDir 'FunPlanet AdbReverse Watch.lnk'

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = 'powershell.exe'
$shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$watcher`""
$shortcut.WorkingDirectory = $PSScriptRoot
$shortcut.Description = 'FunPlanet: keep adb reverse tcp:3000 alive'
$shortcut.Save()

Write-Host "Autostart installed: $shortcutPath"
Write-Host 'The watcher will now start automatically at every Windows login.'

# Start it right now, hidden. If it is already running, the second copy
# notices and exits by itself, so this is safe to run again.
Start-Process powershell.exe -WindowStyle Hidden -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$watcher`""
Write-Host 'Watcher started in the background.'
Write-Host ''
Write-Host 'Check it is working: open the app on your phone and try to log in.'
Write-Host 'Log file: %LOCALAPPDATA%\FunPlanet\adb-reverse-watch.log'
