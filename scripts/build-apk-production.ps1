# 打包正式 Release APK（连接线上 API，不依赖电脑局域网）
param(
  [string]$ApiUrl
)

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

$productionUrl = $null
if ($ApiUrl) {
  $productionUrl = $ApiUrl.Trim().TrimEnd('/')
} else {
  $hostFile = Join-Path $PWD 'lib\config\production_api_host.dart'
  $content = Get-Content $hostFile -Raw
  if ($content -match "kProductionApiBaseUrl\s*=\s*'([^']*)'") {
    $productionUrl = $Matches[1].Trim().TrimEnd('/')
  }
}

if (-not $productionUrl) {
  throw @'
未配置线上 API 地址。请任选其一：
  1. 填写 lib/config/production_api_host.dart 中的 kProductionApiBaseUrl
  2. 运行: .\scripts\build-apk-production.ps1 -ApiUrl https://你的域名
'@
}

if ($productionUrl -notmatch '^https://') {
  throw "正式 APK 必须使用 HTTPS 地址，当前: $productionUrl"
}

Write-Host ">>> 正式 APK 将连接: $productionUrl" -ForegroundColor Cyan
flutter build apk --release --dart-define=API_BASE_URL=$productionUrl

Write-Host ''
Write-Host '>>> 完成: build/app/outputs/flutter-apk/app-release.apk' -ForegroundColor Green
Write-Host '>>> 登录/小豆/客服/订单均走线上真实后端' -ForegroundColor Yellow
