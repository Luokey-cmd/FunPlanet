# FunPlanet adb reverse watcher - uninstall autostart and stop watcher
# 1) Removes the Startup shortcut (no more autostart at Windows login).
# 2) Stops the watcher if it is running right now.
# No administrator rights needed.

$ErrorActionPreference = 'Continue'

$startupDir = [Environment]::GetFolderPath('Startup')
if ($startupDir) {
  $shortcutPath = Join-Path $startupDir 'FunPlanet AdbReverse Watch.lnk'
  if (Test-Path $shortcutPath) {
    Remove-Item $shortcutPath -Force
    Write-Host "Autostart removed: $shortcutPath"
  } else {
    Write-Host 'Autostart shortcut was not installed (nothing to remove).'
  }
}

# Stop running watcher processes (match on the script name in the
# command line; this uninstall script itself does not match).
$procs = Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" |
  Where-Object { $_.CommandLine -like '*adb-reverse-watch.ps1*' }
if ($procs) {
  foreach ($p in $procs) {
    Stop-Process -Id $p.ProcessId -Force
    Write-Host "Watcher stopped (PID $($p.ProcessId))."
  }
} else {
  Write-Host 'No running watcher found.'
}

Write-Host 'Done. You can still run scripts/adb-reverse.ps1 by hand as before.'
