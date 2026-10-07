# Code-native GRUB icons and nine-slice boxes. Does not edit the supplied photo.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$taskRoot = Split-Path -Parent $PSScriptRoot
$assetRoot = Join-Path $taskRoot 'theme'
New-Item -ItemType Directory -Force -Path (Join-Path $assetRoot 'icons') | Out-Null
function Write-Png($Path, $Width, $Height, [scriptblock]$Draw) {
    $bitmap = [System.Drawing.Bitmap]::new($Width, $Height)
    $canvas = [System.Drawing.Graphics]::FromImage($bitmap)
    $canvas.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $canvas.Clear([System.Drawing.Color]::Transparent)
    & $Draw $canvas $Width $Height
    $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $canvas.Dispose(); $bitmap.Dispose()
}
function Color($Hex) { [System.Drawing.ColorTranslator]::FromHtml($Hex) }
foreach ($style in @('selected', 'row', 'terminal', 'scrollbar', 'thumb')) {
    switch ($style) {
        'selected' { $border = '#ff0022'; $fill = '#57040c'; $edge = 3 }
        'row' { $border = '#707779'; $fill = '#080c0d'; $edge = 2 }
        'terminal' { $border = '#aeb8bc'; $fill = '#050809'; $edge = 2 }
        'scrollbar' { $border = '#40474b'; $fill = '#13191d'; $edge = 1 }
        'thumb' { $border = '#ff0022'; $fill = '#ba001a'; $edge = 1 }
    }
    foreach ($slice in @('c','n','s','e','w','nw','ne','sw','se')) {
        Write-Png (Join-Path $assetRoot "${style}_${slice}.png") 12 12 {
            param($g, $w, $h)
            $brush = [System.Drawing.SolidBrush]::new((Color $fill))
            $g.FillRectangle($brush, 0, 0, $w, $h)
            $brush.Dispose()
            if ($style -eq 'selected' -and $slice -eq 'c') {
                $gradient = [System.Drawing.Drawing2D.LinearGradientBrush]::new([System.Drawing.Point]::new(0,0), [System.Drawing.Point]::new(12,0), (Color '#8b0011'), (Color '#300208'))
                $g.FillRectangle($gradient,0,0,$w,$h); $gradient.Dispose()
            }
            $brush = [System.Drawing.SolidBrush]::new((Color $border))
            if ($slice.Contains('n')) { $g.FillRectangle($brush,0,0,$w,$edge) }
            if ($slice.Contains('s')) { $g.FillRectangle($brush,0,($h-$edge),$w,$edge) }
            if ($slice.Contains('w')) { $g.FillRectangle($brush,0,0,$edge,$h) }
            if ($slice.Contains('e')) { $g.FillRectangle($brush,($w-$edge),0,$edge,$h) }
            if ($style -eq 'selected' -and $slice -eq 'w') { $g.FillRectangle($brush,0,0,8,$h) }
            $brush.Dispose()
        }
    }
}
$white = [System.Drawing.Brushes]::White
Write-Png (Join-Path $assetRoot 'icons/windows.png') 128 128 {
    param($g)
    foreach ($box in @(@(18,26,59,20,59,59,18,59), @(67,19,110,12,110,59,67,59), @(18,67,59,67,59,106,18,100), @(67,67,110,67,110,114,67,107))) {
        $points = [System.Drawing.PointF[]]@([System.Drawing.PointF]::new($box[0],$box[1]),[System.Drawing.PointF]::new($box[2],$box[3]),[System.Drawing.PointF]::new($box[4],$box[5]),[System.Drawing.PointF]::new($box[6],$box[7]))
        $g.FillPolygon($white,$points)
    }
}
Write-Png (Join-Path $assetRoot 'icons/ubuntu.png') 128 128 {
    param($g)
    $pen = [System.Drawing.Pen]::new([System.Drawing.Color]::White,13)
    foreach ($angle in @(18,138,258)) { $g.DrawArc($pen,28,28,72,72,$angle,83) }
    foreach ($angle in @(0,120,240)) {
        $radians = $angle * [Math]::PI / 180
        $cx = 64 + 47 * [Math]::Cos($radians); $cy = 64 + 47 * [Math]::Sin($radians)
        $g.FillEllipse([System.Drawing.Brushes]::Black,[single]($cx-14),[single]($cy-14),28,28)
        $g.FillEllipse($white,[single]($cx-10),[single]($cy-10),20,20)
    }
    $pen.Dispose()
}
Write-Png (Join-Path $assetRoot 'icons/submenu.png') 128 128 {
    param($g)
    $points = [System.Collections.Generic.List[System.Drawing.PointF]]::new()
    for ($i=0; $i -lt 48; $i++) {
        $a = $i * [Math]::PI / 24; $r = if (($i % 4) -in @(1,2)) { 50 } else { 39 }
        $points.Add([System.Drawing.PointF]::new([single](64+$r*[Math]::Cos($a)),[single](64+$r*[Math]::Sin($a))))
    }
    $g.FillPolygon($white,$points.ToArray())
    $g.FillEllipse([System.Drawing.Brushes]::Black,42,42,44,44)
}
Write-Png (Join-Path $assetRoot 'icons/uefi.png') 128 128 {
    param($g)
    $pen = [System.Drawing.Pen]::new([System.Drawing.Color]::White,6)
    $g.DrawRectangle($pen,30,30,68,68); $g.DrawRectangle($pen,44,44,40,40)
    foreach ($offset in @(39,55,71,87)) {
        $g.DrawLine($pen,$offset,17,$offset,30); $g.DrawLine($pen,$offset,98,$offset,111)
        $g.DrawLine($pen,17,$offset,30,$offset); $g.DrawLine($pen,98,$offset,111,$offset)
    }
    $pen.Dispose()
}
foreach ($name in @('gnu-linux','linux','recovery')) { Copy-Item -LiteralPath (Join-Path $assetRoot 'icons/ubuntu.png') -Destination (Join-Path $assetRoot "icons/$name.png") }
foreach ($name in @('advanced','settings')) { Copy-Item -LiteralPath (Join-Path $assetRoot 'icons/submenu.png') -Destination (Join-Path $assetRoot "icons/$name.png") }
Copy-Item -LiteralPath (Join-Path $assetRoot 'icons/uefi.png') -Destination (Join-Path $assetRoot 'icons/efi.png')
Write-Output '已生成图标与 GRUB 九宫格素材。'
