# FunPlanet adb reverse watcher
# Keeps "adb reverse tcp:3000 tcp:3000" alive for every connected device.
# When a device reconnects or the tunnel drops, this script re-creates it
# within a few seconds. Run it once; it stays in the background and loops.
# Stop it: close its window, or run uninstall-watch-autostart.ps1, or
# end the powershell process that runs this script in Task Manager.

param(
  [int]$Port = 3000,
  [int]$IntervalSeconds = 5
)

$ErrorActionPreference = 'Continue'

# --- Single instance guard: a second copy exits right away ---
$mutex = New-Object System.Threading.Mutex($false, 'Local\FunPlanetAdbReverseWatch')
$acquired = $false
try {
  $acquired = $mutex.WaitOne(0, $false)
} catch [System.Threading.AbandonedMutexException] {
  # Previous watcher was killed without cleanup; we own it now.
  $acquired = $true
}
if (-not $acquired) {
  Write-Host 'Watcher is already running. This copy will exit.'
  exit 0
}

# --- Find adb.exe (same path as adb-reverse.ps1, with fallbacks) ---
$adb = $null
$candidates = @('D:\Software\Android_Studio\SDK\platform-tools\adb.exe')
if ($env:LOCALAPPDATA) {
  $candidates += (Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe')
}
foreach ($c in $candidates) {
  if (Test-Path $c) { $adb = $c; break }
}
if (-not $adb) {
  $cmd = Get-Command adb -ErrorAction SilentlyContinue
  if ($cmd) { $adb = $cmd.Source }
}
if (-not $adb) {
  Write-Host 'ERROR: adb.exe not found. Check the SDK path in this script.' -ForegroundColor Red
  exit 1
}

# --- Log file (kept outside the project so git status stays clean) ---
$logDir = Join-Path $env:LOCALAPPDATA 'FunPlanet'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$logFile = Join-Path $logDir 'adb-reverse-watch.log'

function Write-Log([string]$Message) {
  $line = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
  Write-Host $line
  try { Add-Content -Path $logFile -Value $line -Encoding UTF8 } catch {}
}

Write-Log "Watcher started. adb = $adb ; port = $Port ; check every $IntervalSeconds s"
Write-Log "Log file: $logFile"
Write-Log 'Leave this window open (or install autostart). Press Ctrl+C to stop.'

$knownGood = @{}   # serial -> $true when tunnel confirmed for current connection

try {
  while ($true) {
    # Get connected devices in state "device" (skip offline / unauthorized)
    $deviceLines = & $adb devices 2>$null
    $serials = @()
    foreach ($line in $deviceLines) {
      if ($line -match '^(\S+)\s+device\s*$') { $serials += $Matches[1] }
    }

    # Forget devices that disappeared, so a reconnect gets a fresh check
    foreach ($old in @($knownGood.Keys)) {
      if ($serials -notcontains $old) {
        $knownGood.Remove($old)
        Write-Log "Device disconnected: $old"
      }
    }

    foreach ($serial in $serials) {
      # Check whether the tunnel already exists for this device
      $list = & $adb -s $serial reverse --list 2>$null
      $hasTunnel = $false
      foreach ($l in $list) {
        if ($l -match ("tcp:{0}\s+tcp:{0}" -f $Port)) { $hasTunnel = $true }
      }

      if (-not $hasTunnel) {
        $result = & $adb -s $serial reverse "tcp:$Port" "tcp:$Port" 2>&1
        if ($LASTEXITCODE -eq 0) {
          Write-Log "Tunnel restored for ${serial}: phone 127.0.0.1:$Port -> PC localhost:$Port"
          $knownGood[$serial] = $true
        } else {
          Write-Log "Tunnel FAILED for ${serial}: $result"
        }
      } elseif (-not $knownGood.ContainsKey($serial)) {
        Write-Log "Tunnel already OK for ${serial}."
        $knownGood[$serial] = $true
      }
    }

    Start-Sleep -Seconds $IntervalSeconds
  }
}
finally {
  Write-Log 'Watcher stopped.'
  try { $mutex.ReleaseMutex() } catch {}
  $mutex.Dispose()
}
