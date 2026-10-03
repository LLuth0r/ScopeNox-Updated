<#
.SYNOPSIS
  Generates the textures for the "Dock" home menu style (media/dock/).

.DESCRIPTION
  icons/<name>.png   128x128 white icon, one per home item type (ListItem.Property(Item));
                     tinted in the skin with colordiffuse (white / near-black / themecolor).
  dark/bar.png       the dock: smoked glass rectangle with square corners, a bright top rim and a
                     shadow cast upwards (it sits flush on the bottom edge of the frame).
  light/bar.png      the same in frosted white glass.
  dark/lens.png      the glass tile behind the focused item.
  light/lens.png
  accent.png         small white square, tinted themecolor in the skin for the focus line.

  bar.png and lens.png are 9-slice textures: in the skin use border="$BarBorder" / "$LensBorder"
  (printed by the script) so they stretch to any width.

  Icons are Material Symbols Rounded (Apache License 2.0, https://fonts.google.com/icons). The
  15 MB variable font is not shipped with the skin; download it once and pass it with -Font:
  https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL,GRAD,opsz,wght%5D.ttf
  GDI+ renders the font's default instance (outlined, weight 400).

  New textures must use new names: Kodi prefers textures packed in media/Textures.xbt over
  loose files with the same name.

.EXAMPLE
  .\tools\gendock.ps1 -Font $env:TEMP\MaterialSymbolsRounded.ttf
#>
param(
  [Parameter(Mandatory = $true)][string]$Font,
  [string]$SkinDir,
  [string]$OutDir
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

# texture geometry; the skin stretches them (9-slice), so only the margins matter
$Shadow = 20                       # shadow margin left / top / right of the bar (none below: flush)
$BarBorder = $Shadow + 4
$LensBorder = 4

function New-Bitmap($w, $h) {
  $b = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($b); $g.SmoothingMode = 'AntiAlias'; $g.PixelOffsetMode = 'HighQuality'
  $g.Clear([System.Drawing.Color]::Transparent); , @($b, $g)
}
function C($a, $r, $g, $b) { [System.Drawing.Color]::FromArgb($a, $r, $g, $b) }
function VGrad($y0, $y1, $colors, $positions) {
  $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.PointF 0, $y0), (New-Object System.Drawing.PointF 0, $y1), $colors[0], $colors[-1]
  $cb = New-Object System.Drawing.Drawing2D.ColorBlend $colors.Count
  $cb.Colors = [System.Drawing.Color[]]$colors; $cb.Positions = [single[]]$positions; $br.InterpolationColors = $cb; $br
}
function Save($bmp, $rel) {
  $path = Join-Path $OutDir $rel; New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
}

# Glass rectangle: tinted body, sheen on the top half, 1 px rim (bright top edge, faint sides),
# optional shadow on the left / top / right.
function New-Glass($rel, $w, $h, $pad, $shadowAlpha, $body, $sheen, $topRim, $sideRim) {
  $bw = $w + 2 * $pad; $bh = $h + $pad
  $o = New-Bitmap $bw $bh; $g = $o[1]
  if ($pad -gt 0) {
    $s = New-Bitmap $bw $bh
    $s[1].FillRectangle((New-Object System.Drawing.SolidBrush (C $shadowAlpha 0 0 0)), $pad, ($pad - 3), $w, ($h + 3)); $s[1].Dispose()
    [Blur]::Alpha($s[0], [int]($pad / 2)); $g.DrawImage($s[0], 0, 0); $s[0].Dispose()
  }
  $g.SmoothingMode = 'None'
  $g.CompositingMode = 'SourceCopy'                     # body replaces the shadow under it
  $g.FillRectangle((VGrad $pad ($pad + $h) $body @(0, 1)), $pad, $pad, $w, $h)
  $g.CompositingMode = 'SourceOver'
  $g.FillRectangle((VGrad ($pad + 1) ($pad + 1 + $h * 0.5) $sheen @(0, 1)), $pad, ($pad + 1), $w, [int]($h * 0.5))
  $g.FillRectangle((VGrad $pad ($pad + $h) $sideRim @(0, 1)), $pad, $pad, 1, $h)
  $g.FillRectangle((VGrad $pad ($pad + $h) $sideRim @(0, 1)), ($pad + $w - 1), $pad, 1, $h)
  $g.FillRectangle((New-Object System.Drawing.SolidBrush $topRim), $pad, $pad, $w, 1)
  $g.Dispose(); Save $o[0] $rel
}

# dark: smoked glass
New-Glass 'dark\bar.png' 120 80 $Shadow 110 `
  @((C 150 28 30 38), (C 175 10 11 15)) @((C 34 255 255 255), (C 0 255 255 255)) `
  (C 120 255 255 255) @((C 60 255 255 255), (C 8 255 255 255))
New-Glass 'dark\lens.png' 40 40 0 0 `
  @((C 46 255 255 255), (C 20 255 255 255)) @((C 40 255 255 255), (C 0 255 255 255)) `
  (C 110 255 255 255) @((C 50 255 255 255), (C 10 255 255 255))
# light: frosted white glass (opaque enough to stay readable without a real backdrop blur)
New-Glass 'light\bar.png' 120 80 $Shadow 80 `
  @((C 225 248 248 250), (C 212 236 237 242)) @((C 110 255 255 255), (C 0 255 255 255)) `
  (C 255 255 255 255) @((C 140 255 255 255), (C 60 255 255 255))
New-Glass 'light\lens.png' 40 40 0 0 `
  @((C 235 255 255 255), (C 220 250 250 252)) @((C 120 255 255 255), (C 0 255 255 255)) `
  (C 255 255 255 255) @((C 30 0 0 0), (C 30 0 0 0))
$a = New-Bitmap 8 8; $a[1].FillRectangle([System.Drawing.Brushes]::White, 0, 0, 8, 8); $a[1].Dispose(); Save $a[0] 'accent.png'

# icons
$pfc = New-Object System.Drawing.Text.PrivateFontCollection; $pfc.AddFontFile($Font)
$family = $pfc.Families[0]
foreach ($name in $icons.Keys) {
  $size = 128; $b = New-Bitmap $size $size; $g = $b[1]
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $p.AddString([string][char]$icons[$name], $family, 0, 112, (New-Object System.Drawing.PointF 0, 0), [System.Drawing.StringFormat]::GenericTypographic)
  $r = $p.GetBounds(); $scale = 104 / [Math]::Max($r.Width, $r.Height)
  $m = New-Object System.Drawing.Drawing2D.Matrix
  $m.Translate($size / 2, $size / 2); $m.Scale($scale, $scale); $m.Translate(-($r.X + $r.Width / 2), -($r.Y + $r.Height / 2))
  $p.Transform($m); $g.FillPath([System.Drawing.Brushes]::White, $p); $g.Dispose()
  Save $b[0] "icons\$name.png"
}
"textures in $OutDir (bar border=$BarBorder with $Shadow px shadow left/top/right, lens border=$LensBorder)"
