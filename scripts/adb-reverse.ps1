# 每次启动 App 前执行一次（模拟器/真机无线调试都需要）
$adb = "D:\Software\Android_Studio\SDK\platform-tools\adb.exe"
if (-not (Test-Path $adb)) {
  Write-Error "找不到 adb: $adb"
  exit 1
}
& $adb reverse tcp:3000 tcp:3000
Write-Host "端口转发已就绪: 设备 127.0.0.1:3000 -> 电脑 localhost:3000"
& $adb reverse --list
