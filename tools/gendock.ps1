<#
.SYNOPSIS
  Generates the textures for the "Dock" home menu style (media/dock/).

.DESCRIPTION
  icons/<name>.png   128x128 white icon, one per home item type (ListItem.Property(Item));
                     tinted in the skin with colordiffuse (white / near-black / themecolor).
  dark/bar.png       the dock: dark tinted glass pill with a bright rim and a soft shadow.
  light/bar.png      the same in frosted white glass.
  dark/lens.png      the glass capsule behind the focused item.
  light/lens.png

  The pills are 9-slice textures: in the skin use border="$Border" (bar) and the lens border
  printed by the script, so they stretch to any width with round ends.

  Icons are Material Symbols Rounded (Apache License 2.0, https://fonts.google.com/icons). The
  15 MB variable font is not shipped with the skin; download it once and pass it with -Font:
  https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL,GRAD,opsz,wght%5D.ttf
  GDI+ renders the font's default instance (outlined, weight 400).

  New textures must use new names: Kodi prefers textures packed in media/Textures.xbt over
  loose files with the same name.

.EXAMPLE
  .\tools\gendock.ps1 -Font $env:TEMP\MaterialSymbolsRounded.ttf
  .\tools\gendock.ps1 -Font ... -OutDir $env:TEMP\dock -Preview $env:TEMP\dock-sheet.png
#>
param(
  [Parameter(Mandatory = $true)][string]$Font,
  [string]$SkinDir,
  [string]$OutDir,
  [string]$Preview
)
$ErrorActionPreference = 'Stop'
if (-not $SkinDir) { $SkinDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }
if (-not $OutDir) { $OutDir = Join-Path $SkinDir 'media\dock' }
$Font = (Resolve-Path $Font).Path
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class Blur {
  // three box-blur passes on the alpha channel (close to a gaussian); colour is left as drawn
  public static void Alpha(Bitmap bmp, int radius) {
    var r = new Rectangle(0, 0, bmp.Width, bmp.Height);
    var d = bmp.LockBits(r, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
    int w = bmp.Width, h = bmp.Height; var px = new byte[d.Stride * h];
    Marshal.Copy(d.Scan0, px, 0, px.Length);
    var a = new float[w * h]; for (int i = 0; i < w * h; i++) a[i] = px[(i / w) * d.Stride + (i % w) * 4 + 3];
    var t = new float[w * h];
    for (int pass = 0; pass < 3; pass++) {
      for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) { float s = 0; int n = 0;
        for (int k = -radius; k <= radius; k++) { int xx = x + k; if (xx >= 0 && xx < w) { s += a[y * w + xx]; } n++; } t[y * w + x] = s / n; }
      for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) { float s = 0; int n = 0;
        for (int k = -radius; k <= radius; k++) { int yy = y + k; if (yy >= 0 && yy < h) { s += t[yy * w + x]; } n++; } a[y * w + x] = s / n; }
    }
    for (int i = 0; i < w * h; i++) px[(i / w) * d.Stride + (i % w) * 4 + 3] = (byte)Math.Min(255, a[i]);
    Marshal.Copy(px, 0, d.Scan0, px.Length); bmp.UnlockBits(d);
  }
}
"@

# home item type -> Material Symbols code point
$icons = [ordered]@{
  movie = 0xe404; tvshow = 0xe63b; livetv = 0xe63a; music = 0xe405; musicvideo = 0xe063
  pictures = 0xe413; videos = 0xe04a; programs = 0xe5c3; games = 0xea28; favorites = 0xe87e
  weather = 0xf172; settings = 0xe8b8; shutdown = 0xf8c7; custom = 0xe9b0
}

# geometry, in skin pixels (1920x1080)
$BarHeight = 118; $Shadow = 24              # dock height and shadow margin around it
$Border = $BarHeight / 2 + $Shadow          # 9-slice border of bar.png
$LensHeight = 102; $LensPad = 8             # focused-item capsule and its shadow margin

function New-Bitmap($w, $h) {
  $b = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($b); $g.SmoothingMode = 'AntiAlias'; $g.PixelOffsetMode = 'HighQuality'
  $g.Clear([System.Drawing.Color]::Transparent); , @($b, $g)
}
function Pill([float]$x, [float]$y, [float]$w, [float]$h) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath; $d = $h
  $p.AddArc($x, $y, $d, $d, 90, 180); $p.AddArc($x + $w - $d, $y, $d, $d, 270, 180); $p.CloseFigure(); $p
}
function C($a, $r, $g, $b) { [System.Drawing.Color]::FromArgb($a, $r, $g, $b) }
function VGrad($y0, $y1, $colors, $positions) {
  $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.PointF 0, $y0), (New-Object System.Drawing.PointF 0, $y1), $colors[0], $colors[-1]
  $cb = New-Object System.Drawing.Drawing2D.ColorBlend $colors.Count
  $cb.Colors = [System.Drawing.Color[]]$colors; $cb.Positions = [single[]]$positions; $br.InterpolationColors = $cb; $br
}

# One glass pill: soft shadow, tinted body, inner sheen on the top half, bright rim.
function New-Glass($path, $w, $h, $pad, $shadowAlpha, $shadowBlur, $body, $sheen, $rim, $edge) {
  $bw = $w + 2 * $pad; $bh = $h + 2 * $pad
  $s = New-Bitmap $bw $bh
  $s[1].FillPath((New-Object System.Drawing.SolidBrush (C $shadowAlpha 0 0 0)), (Pill $pad ($pad + $shadowBlur / 3) $w $h))
  $s[1].Dispose(); if ($shadowBlur -gt 0) { [Blur]::Alpha($s[0], [int]($shadowBlur / 2)) }
  $o = New-Bitmap $bw $bh; $g = $o[1]
  $g.DrawImage($s[0], 0, 0)
  $shape = Pill $pad $pad $w $h
  $g.CompositingMode = 'SourceCopy'                     # body replaces the shadow under it
  $g.FillPath((VGrad $pad ($pad + $h) $body @(0, 1)), $shape)
  $g.CompositingMode = 'SourceOver'
  $g.SetClip($shape)
  $g.FillPath((VGrad ($pad + 2) ($pad + 2 + $h * 0.5) $sheen @(0, 1)), (Pill ($pad + $h * 0.12) ($pad + 2) ($w - $h * 0.24) ($h * 0.5)))
  $g.ResetClip()
  if ($edge) { $g.DrawPath((New-Object System.Drawing.Pen $edge, 1.5), (Pill ($pad - 0.75) ($pad - 0.75) ($w + 1.5) ($h + 1.5))) }
  $g.DrawPath((New-Object System.Drawing.Pen (VGrad $pad ($pad + $h) $rim @(0, 0.45, 1)), 2), (Pill ($pad + 1) ($pad + 1) ($w - 2) ($h - 2)))
  $g.Dispose(); $s[0].Dispose()
  New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
  $o[0].Save($path, [System.Drawing.Imaging.ImageFormat]::Png); $o[0].Dispose()
}

$barW = 300; $lensW = 220
# dark: smoked glass
New-Glass (Join-Path $OutDir 'dark\bar.png') $barW $BarHeight $Shadow 110 22 `
  @((C 112 30 32 40), (C 138 12 13 18)) @((C 46 255 255 255), (C 0 255 255 255)) `
  @((C 150 255 255 255), (C 22 255 255 255), (C 70 255 255 255)) $null
New-Glass (Join-Path $OutDir 'dark\lens.png') $lensW $LensHeight $LensPad 60 8 `
  @((C 70 255 255 255), (C 34 255 255 255)) @((C 60 255 255 255), (C 0 255 255 255)) `
  @((C 170 255 255 255), (C 30 255 255 255), (C 90 255 255 255)) $null
# light: frosted white glass, with a faint dark hairline so it holds its shape on bright art
New-Glass (Join-Path $OutDir 'light\bar.png') $barW $BarHeight $Shadow 80 22 `
  @((C 222 248 248 250), (C 208 236 237 242)) @((C 120 255 255 255), (C 0 255 255 255)) `
  @((C 255 255 255 255), (C 90 255 255 255), (C 200 255 255 255)) (C 40 0 0 0)
New-Glass (Join-Path $OutDir 'light\lens.png') $lensW $LensHeight $LensPad 45 8 `
  @((C 235 255 255 255), (C 215 248 248 250)) @((C 120 255 255 255), (C 0 255 255 255)) `
  @((C 255 255 255 255), (C 120 255 255 255), (C 220 255 255 255)) (C 25 0 0 0)

# icons
$pfc = New-Object System.Drawing.Text.PrivateFontCollection; $pfc.AddFontFile($Font)
$family = $pfc.Families[0]
New-Item -ItemType Directory -Force (Join-Path $OutDir 'icons') | Out-Null
foreach ($name in $icons.Keys) {
  $size = 128; $b = New-Bitmap $size $size; $g = $b[1]
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $p.AddString([string][char]$icons[$name], $family, 0, 112, (New-Object System.Drawing.PointF 0, 0), [System.Drawing.StringFormat]::GenericTypographic)
  $r = $p.GetBounds(); $scale = 104 / [Math]::Max($r.Width, $r.Height)
  $m = New-Object System.Drawing.Drawing2D.Matrix
  $m.Translate($size / 2, $size / 2); $m.Scale($scale, $scale); $m.Translate(-($r.X + $r.Width / 2), -($r.Y + $r.Height / 2))
  $p.Transform($m); $g.FillPath([System.Drawing.Brushes]::White, $p); $g.Dispose()
  $b[0].Save((Join-Path $OutDir "icons\$name.png"), [System.Drawing.Imaging.ImageFormat]::Png); $b[0].Dispose()
}
"textures in $OutDir (bar border=$Border, lens border=$($LensHeight / 2 + $LensPad))"

if ($Preview) {
  # the dock in both styles over a busy and a bright background
  $sheet = New-Object System.Drawing.Bitmap 1500, 560; $g = [System.Drawing.Graphics]::FromImage($sheet)
  $g.SmoothingMode = 'AntiAlias'
  $bg = VGrad 0 280 @((C 255 40 60 110), (C 255 200 120 80)) @(0, 1); $g.FillRectangle($bg, 0, 0, 1500, 280)
  $g.FillRectangle((VGrad 280 560 @((C 255 235 236 240), (C 255 180 200 220)) @(0, 1)), 0, 280, 1500, 280)
  foreach ($row in 0, 1) {
    $style = @('dark', 'light')[$row]; $tint = @((C 255 255 255 255), (C 230 28 28 30))[$row]
    $y = 80 + $row * 280
    $bar = [System.Drawing.Image]::FromFile((Join-Path $OutDir "$style\bar.png"))
    $lens = [System.Drawing.Image]::FromFile((Join-Path $OutDir "$style\lens.png"))
    $n = 6; $w = 150 * $n + 36; $x0 = (1500 - $w) / 2
    # 9-slice by hand: caps + stretched middle
    $bw = $bar.Width; $bh = $bar.Height; $bd = $Border
    $g.DrawImage($bar, (New-Object System.Drawing.Rectangle ($x0 - $Shadow), ($y - $Shadow), $bd, $bh), 0, 0, $bd, $bh, 'Pixel')
    $g.DrawImage($bar, (New-Object System.Drawing.Rectangle ($x0 - $Shadow + $bd), ($y - $Shadow), ($w + 2 * $Shadow - 2 * $bd), $bh), $bd, 0, ($bw - 2 * $bd), $bh, 'Pixel')
    $g.DrawImage($bar, (New-Object System.Drawing.Rectangle ($x0 + $w + $Shadow - $bd), ($y - $Shadow), $bd, $bh), ($bw - $bd), 0, $bd, $bh, 'Pixel')
    $g.DrawImage($lens, ($x0 + 18 + 150 + 6 - $LensPad), ($y + 8 - $LensPad), (138 + 2 * $LensPad), ($LensHeight + 2 * $LensPad))
    $i = 0
    foreach ($name in 'tvshow', 'movie', 'music', 'programs', 'settings', 'shutdown') {
      $ico = [System.Drawing.Bitmap]::FromFile((Join-Path $OutDir "icons\$name.png"))
      $c = if ($i -eq 1) { C 255 0x6d 0xb9 0xe5 } else { $tint }
      $ia = New-Object System.Drawing.Imaging.ImageAttributes
      $cm = New-Object System.Drawing.Imaging.ColorMatrix; $cm.Matrix00 = $c.R / 255; $cm.Matrix11 = $c.G / 255; $cm.Matrix22 = $c.B / 255; $cm.Matrix33 = $c.A / 255; $cm.Matrix44 = 1
      $ia.SetColorMatrix($cm)
      $g.DrawImage($ico, (New-Object System.Drawing.Rectangle ($x0 + 18 + $i * 150 + 49), ($y + 16), 52, 52), 0, 0, 128, 128, 'Pixel', $ia)
      $g.DrawString(@('TV Shows', 'Movies', 'Music', 'Apps', 'System', 'Power')[$i], (New-Object System.Drawing.Font 'Segoe UI', 13), (New-Object System.Drawing.SolidBrush $c), (New-Object System.Drawing.RectangleF ($x0 + 18 + $i * 150), ($y + 74), 150, 30), (New-Object System.Drawing.StringFormat -Property @{ Alignment = 'Center' }))
      $ico.Dispose(); $i++
    }
    $bar.Dispose(); $lens.Dispose()
  }
  $sheet.Save($Preview, [System.Drawing.Imaging.ImageFormat]::Png); "preview $Preview"
}
