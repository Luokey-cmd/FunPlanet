# 商品图入库前缩图脚本（2026-11-24）
# 用途：新生成的商品图放进项目之前，先在本机把长边缩到 800 像素以内。
# 为什么：原图 1254×1254、单张约 2MB，App 显示时整张解码是切页卡顿的大头；
# 缩到 800 后解码像素量只剩约四成，卡片里显示看不出差别。
# 用法：把要处理的图片放进一个文件夹，右键本脚本「使用 PowerShell 运行」，
# 或在终端里执行： .\scripts\resize-product-images.ps1 -Folder "图片所在文件夹"
# 说明：只缩不放大；已经小于 800 的图原样跳过；PNG 仍存 PNG、JPG 仍存 JPG；
# 处理是直接覆盖原文件——你的原图请另存一份在本地存档里，不要拿存档跑这个脚本。

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

Get-ChildItem -Path $Folder -File | Where-Object { $_.Extension -match '^\.(png|jpg|jpeg)$' } | ForEach-Object {
    $img = [System.Drawing.Image]::FromFile($_.FullName)
    try {
        if ($img.Width -le $maxSide -and $img.Height -le $maxSide) {
            $skipped++
            return
        }
        $ratio = [Math]::Min($maxSide / $img.Width, $maxSide / $img.Height)
        $newW = [int]($img.Width * $ratio)
        $newH = [int]($img.Height * $ratio)
        $bmp = New-Object System.Drawing.Bitmap($newW, $newH)
        try {
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $g.DrawImage($img, 0, 0, $newW, $newH)
            $g.Dispose()
            $tmp = "$($_.FullName).tmp$($_.Extension)"
            if ($_.Extension -match '^\.(jpg|jpeg)$') {
                $bmp.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Jpeg)
            } else {
                $bmp.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
            }
        } finally {
            $bmp.Dispose()
        }
    } finally {
        $img.Dispose()
    }
    Move-Item -Force $tmp $_.FullName
    $done++
    Write-Host "已缩：$($_.Name) -> ${newW}x${newH}"
}

Write-Host "完成：缩小 $done 张，跳过 $skipped 张（本来就小于 $maxSide 的没动）。"
