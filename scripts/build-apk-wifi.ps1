# 局域网 WiFi 模式：自动检测电脑 IP 并打包 APK
# 用法：powershell -ExecutionPolicy Bypass -File scripts/build-apk-wifi.ps1

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

function Get-WifiLanIp {
  $candidates = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object {
      $_.IPAddress -notlike '127.*' -and
      $_.IPAddress -notlike '169.254.*' -and
      $_.InterfaceAlias -notmatch 'Virtual|VMware|Hyper-V|vEthernet|WSL'
    }

  $wifi = $candidates | Where-Object { $_.InterfaceAlias -match 'Wi-Fi|WLAN|无线' } | Select-Object -First 1
  if ($wifi) { return $wifi.IPAddress }

  $lan = $candidates | Where-Object { $_.IPAddress -like '192.168.*' } | Select-Object -First 1
  if ($lan) { return $lan.IPAddress }

  throw '未检测到 WiFi 局域网 IP，请手动填写 lib/config/local_api_host.dart'
}

$ip = Get-WifiLanIp
$apiUrl = "http://${ip}:3000"
Write-Host "检测到电脑 IP: $ip"
Write-Host "APK 将连接: $apiUrl"
Write-Host ""

# 同步写入 local_api_host.dart，避免 Release 包地址不一致
$hostFile = Join-Path $PWD 'lib\config\local_api_host.dart'
$hostContent = @"
/// 打包 APK 前填写电脑的 WiFi 局域网 IP（cmd 运行 ipconfig）。
/// 也可直接运行 scripts/build-apk-wifi.ps1 自动检测并打包。
const String kLocalApiHostOverride = '$ip';
"@
Set-Content -Path $hostFile -Value $hostContent -Encoding UTF8

Write-Host "正在打包 Release APK ..."
flutter build apk --release --dart-define=API_BASE_URL=$apiUrl

Write-Host ""
Write-Host "打包完成！"
Write-Host "APK 路径: build\app\outputs\flutter-apk\app-release.apk"
Write-Host ""
Write-Host "使用前请确认："
Write-Host "  1. 手机和电脑连接同一 WiFi"
Write-Host "  2. 电脑已运行: cd server && npm run dev"
Write-Host "  3. 若连不上，管理员运行防火墙放行:"
Write-Host "     netsh advfirewall firewall add rule name=`"FunPlanet API 3000`" dir=in action=allow protocol=TCP localport=3000"
