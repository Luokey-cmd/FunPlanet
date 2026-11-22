# 每次启动 App 前执行一次（模拟器/真机无线调试都需要）
# UTF-8 BOM + 控制台编码，避免中文乱码
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
try { chcp 65001 | Out-Null } catch {}

$adb = "D:\Software\Android_Studio\SDK\platform-tools\adb.exe"
if (-not (Test-Path $adb)) {
  Write-Error "找不到 adb: $adb"
  exit 1
}

$port = 3000
if ($args.Count -ge 1 -and $args[0] -match '^\d+$') {
  $port = [int]$args[0]
}

& $adb reverse "tcp:$port" "tcp:$port"
Write-Host "端口转发已就绪: 设备 127.0.0.1:$port -> 电脑 localhost:$port"
& $adb reverse --list
