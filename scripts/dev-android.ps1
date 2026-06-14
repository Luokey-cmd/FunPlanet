# 电脑调试专用：端口转发 + 启动 App（每次无线设备重连后执行）
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

$adb = "D:\Software\Android_Studio\SDK\platform-tools\adb.exe"
if (-not (Test-Path $adb)) {
  Write-Error "找不到 adb: $adb"
  exit 1
}

$devices = & $adb devices | Select-String "device$" | Where-Object { $_ -notmatch "List of devices" }
if (-not $devices) {
  Write-Error "未检测到已连接设备，请先在 Android Studio 连接模拟器或真机"
  exit 1
}

& $adb reverse tcp:3000 tcp:3000
Write-Host "端口转发已就绪: 设备 127.0.0.1:3000 -> 电脑 localhost:3000"
& $adb reverse --list
Write-Host ""
Write-Host "请确认另一个终端已运行: cd server && npm run dev"
Write-Host "正在启动 Flutter ..."
flutter run
