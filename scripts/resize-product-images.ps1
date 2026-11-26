# 商品图入库前处理脚本（2026-11-24 建，2026-11-26 改为统一转 JPG）
# 用途：新生成的商品图放进项目之前，先在本机缩到长边 800 像素以内，并统一转成 JPG。
# 为什么转 JPG：商品图是照片，PNG 存照片体积大得离谱（单张约 700KB）；2026-11-26 全店
# 商品图已统一改 JPG（单张约 100KB），新图也必须走 JPG，数据里的 imagePath 才会对得上。
# 为什么缩到 800：原图 1254×1254、单张约 2MB，App 显示时整张解码是切页卡顿的大头；
# 缩到 800 后解码像素量只剩约四成，卡片里显示看不出差别。
# 用法：把要处理的图片放进一个文件夹，右键本脚本「使用 PowerShell 运行」，
# 或在终端里执行： .\scripts\resize-product-images.ps1 -Folder "图片所在文件夹"
# 说明：只缩不放大；JPG 且已小于 800 的原样跳过；PNG 会转成同名 JPG 并删掉原 PNG，
# 透明底会铺白底（商品图都是实景照片、没有透明需求）；处理直接改原文件——
# 你的原图请另存一份在本地存档里，不要拿存档跑这个脚本。

param(
    [string]$Folder = "$PSScriptRoot\..\本地素材\待入库"
)

Add-Type -AssemblyName System.Drawing

if (-not (Test-Path $Folder)) {
    Write-Host "找不到文件夹：$Folder"
    Write-Host "用法：把图片放进一个文件夹，再执行 .\scripts\resize-product-images.ps1 -Folder `"文件夹路径`""
    exit 1
}

$maxSide = 800
$done = 0
$skipped = 0

# JPG 编码器与质量参数（质量 90，兼顾画质和体积）
$jpgEncoder = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$encParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
$encParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]90)

Get-ChildItem -Path $Folder -File | Where-Object { $_.Extension -match '^\.(png|jpg|jpeg)$' } | ForEach-Object {
    $isJpg = $_.Extension -match '^\.(jpg|jpeg)$'
    $img = [System.Drawing.Image]::FromFile($_.FullName)
    try {
        $needResize = ($img.Width -gt $maxSide -or $img.Height -gt $maxSide)
        if ($isJpg -and -not $needResize) {
            $skipped++
            return
        }
        $ratio = [Math]::Min($maxSide / $img.Width, $maxSide / $img.Height)
        if ($ratio -gt 1) { $ratio = 1 }
        $newW = [int]($img.Width * $ratio)
        $newH = [int]($img.Height * $ratio)
        $bmp = New-Object System.Drawing.Bitmap($newW, $newH)
        try {
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            $g.Clear([System.Drawing.Color]::White)
            $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $g.DrawImage($img, 0, 0, $newW, $newH)
            $g.Dispose()
            $target = Join-Path $_.DirectoryName ($_.BaseName + '.jpg')
            $tmp = "$target.tmp.jpg"
            $bmp.Save($tmp, $jpgEncoder, $encParams)
        } finally {
            $bmp.Dispose()
        }
    } finally {
        $img.Dispose()
    }
    Move-Item -Force $tmp $target
    if ($_.FullName -ne $target) { Remove-Item $_.FullName }
    $done++
    Write-Host "已处理：$($_.Name) -> $([IO.Path]::GetFileName($target)) ${newW}x${newH}"
}

Write-Host "完成：处理 $done 张，跳过 $skipped 张（已是 JPG 且小于 $maxSide 的没动）。"
