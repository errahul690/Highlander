$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$mobileRoot = Split-Path -Parent $PSScriptRoot
$source = [System.Drawing.Bitmap]::FromFile((Join-Path $mobileRoot 'assets/branding/app_icon.png'))

function Write-Icon([string]$Path, [int]$Size, [double]$ArtworkScale = 1, [bool]$Opaque = $false) {
    $format = if ($Opaque) { [System.Drawing.Imaging.PixelFormat]::Format24bppRgb } else { [System.Drawing.Imaging.PixelFormat]::Format32bppArgb }
    $bitmap = [System.Drawing.Bitmap]::new($Size, $Size, $format)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        if ($Opaque) {
            $graphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#36000A'))
        } else {
            $graphics.Clear([System.Drawing.Color]::Transparent)
        }
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $artworkSize = [int][Math]::Round($Size * $ArtworkScale)
        $offset = [int][Math]::Round(($Size - $artworkSize) / 2)
        $graphics.DrawImage($source, $offset, $offset, $artworkSize, $artworkSize)
        $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

try {
    $res = Join-Path $mobileRoot 'android/app/src/main/res'
    $densities = @{
        'mdpi' = @(48, 108)
        'hdpi' = @(72, 162)
        'xhdpi' = @(96, 216)
        'xxhdpi' = @(144, 324)
        'xxxhdpi' = @(192, 432)
    }
    foreach ($density in $densities.Keys) {
        $folder = Join-Path $res "mipmap-$density"
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        Write-Icon (Join-Path $folder 'ic_launcher.png') $densities[$density][0]
        Write-Icon (Join-Path $folder 'ic_launcher_round.png') $densities[$density][0]
        # Keep artwork inside the adaptive icon's visible area across launcher masks.
        Write-Icon (Join-Path $folder 'ic_launcher_foreground.png') $densities[$density][1] (72.0 / 108.0)
    }
    Write-Icon (Join-Path $mobileRoot 'android/app/src/main/res/ic_launcher-playstore.png') 512 1 $true

    $iosFolder = Join-Path $mobileRoot 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    $catalog = Get-Content -LiteralPath (Join-Path $iosFolder 'Contents.json') -Raw | ConvertFrom-Json
    foreach ($entry in $catalog.images) {
        if (!$entry.filename) { continue }
        $points = [double]::Parse(($entry.size -split 'x')[0], [Globalization.CultureInfo]::InvariantCulture)
        $scale = [double]::Parse($entry.scale.TrimEnd('x'), [Globalization.CultureInfo]::InvariantCulture)
        Write-Icon (Join-Path $iosFolder $entry.filename) ([int][Math]::Round($points * $scale)) 1 $true
    }
} finally {
    $source.Dispose()
}
