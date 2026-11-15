# 管理员 PowerShell 运行一次即可：放行本机 3000 端口（真机 WiFi 连电脑需要）
# 用法：右键「以管理员身份运行」或在管理员终端执行：
#   powershell -ExecutionPolicy Bypass -File scripts/allow-api-firewall.ps1

$ErrorActionPreference = 'Stop'
$ruleName = 'FunPlanet API 3000'

$existing = netsh advfirewall firewall show rule name="$ruleName" 2>$null
if ($LASTEXITCODE -eq 0) {
  Write-Host "防火墙规则已存在: $ruleName"
  exit 0
}

netsh advfirewall firewall add rule name="$ruleName" dir=in action=allow protocol=TCP localport=3000 profile=any
Write-Host "已添加防火墙入站规则: TCP 3000"
