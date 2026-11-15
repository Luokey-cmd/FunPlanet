# 在云服务器上部署 funplanet API（PostgreSQL + Node）
# 用法: .\scripts\deploy-server.ps1           # 常规更新
#       .\scripts\deploy-server.ps1 -Seed      # 首次部署或需要重置种子数据

param([switch]$Seed)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

function Test-EnvPlaceholder {
  param([string]$Name, [string]$Value, [string[]]$Forbidden)
  if (-not $Value -or $Value.Trim().Length -eq 0) {
    throw "请在 .env 中设置 $Name"
  }
  foreach ($bad in $Forbidden) {
    if ($Value -like "*$bad*") {
      throw ".env 中的 $Name 仍为占位符，请改成真实值"
    }
  }
}

if (-not (Test-Path '.env')) {
  Copy-Item '.env.production.example' '.env'
  Write-Host '已生成 .env，请编辑 JWT_SECRET、POSTGRES_PASSWORD、DEEPSEEK_API_KEY 后重新运行' -ForegroundColor Yellow
  exit 1
}

$envMap = @{}
Get-Content '.env' | ForEach-Object {
  if ($_ -match '^\s*#' -or $_ -notmatch '=') { return }
  $parts = $_ -split '=', 2
  if ($parts.Count -eq 2) {
    $envMap[$parts[0].Trim()] = $parts[1].Trim().Trim('"')
  }
}

Test-EnvPlaceholder -Name 'JWT_SECRET' -Value $envMap['JWT_SECRET'] -Forbidden @('请改成', 'change-me', 'change-this')
Test-EnvPlaceholder -Name 'POSTGRES_PASSWORD' -Value $envMap['POSTGRES_PASSWORD'] -Forbidden @('请改成', 'funplanet123')
Test-EnvPlaceholder -Name 'DEEPSEEK_API_KEY' -Value $envMap['DEEPSEEK_API_KEY'] -Forbidden @('sk-your-key', 'your-key')

Write-Host '>>> 构建并启动 API + PostgreSQL ...' -ForegroundColor Cyan
docker compose up -d --build

Write-Host '>>> 等待 API 就绪 ...' -ForegroundColor Cyan
$ready = $false
for ($i = 0; $i -lt 30; $i++) {
  Start-Sleep -Seconds 2
  try {
    $resp = Invoke-RestMethod -Uri 'http://127.0.0.1:3000/api/health' -TimeoutSec 5
    if ($resp.ok -eq $true) {
      $ready = $true
      break
    }
  } catch {}
}
if (-not $ready) {
  Write-Host 'API 健康检查未通过，请执行: docker compose logs api' -ForegroundColor Red
  exit 1
}

if ($Seed) {
  Write-Host '>>> 初始化数据库种子...' -ForegroundColor Cyan
  docker compose exec -T api npm run db:seed
} else {
  Write-Host '>>> 跳过 seed（首次部署请加 -Seed 参数）' -ForegroundColor Yellow
}

Write-Host ''
Write-Host '>>> 部署完成，API 健康检查通过' -ForegroundColor Green
Write-Host '>>> 下一步：配置 Nginx + HTTPS，admin 执行 npm run build 后部署 dist' -ForegroundColor Yellow
Write-Host '>>> 填写 lib/config/production_api_host.dart 后运行 scripts/build-apk-production.ps1' -ForegroundColor Yellow