<#
.SYNOPSIS
  Generates the ScopeNox "thin ring" OSD button textures (media/osd/modern/).

.DESCRIPTION
  For every entry in $set below it writes two 100x100 PNGs:
    <name>nf.png  grey ring + light icon (used as-is)
    <name>fo.png  white ring + white icon (tinted in the skin with colordiffuse="themecolor",
                  so focus follows the blue / orange / red theme)
  Entries with on = $true get a bar under the icon (active toggle state).

  Icons come from fonts/MaterialIcons-Regular.ttf (g = code point) and text from
  fonts/BebasNeue.ttf (t = text, "|" separates lines). Each icon is centred on the ring by its
  visible pixel bounds, not the font's string box.

  To add a button: add an entry to $set, run the script, and reference
  osd/modern/<name>nf.png / <name>fo.png in the skin XML. New textures must use new names:
  Kodi prefers textures packed in media/Textures.xbt over loose files with the same name.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\genosd.ps1
  Regenerates all textures into media\osd\modern.

.EXAMPLE
  .\tools\genosd.ps1 -OutDir $env:TEMP\osd -Preview $env:TEMP\osd-sheet.png
  Writes to a scratch folder with a preview sheet (focused row tinted with the default theme blue),
  to check changes before replacing the skin's textures.
#>
param(
  [string]$SkinDir = (Split-Path -Parent $PSScriptRoot),
  [string]$OutDir,
  [string]$Preview
)
# .NET resolves relative paths against the process directory, not PowerShell's location
function FullPath([string]$p) { [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($p)) { $p } else { Join-Path (Get-Location).Path $p })) }
$SkinDir = FullPath $SkinDir
if (-not $OutDir) { $OutDir = Join-Path $SkinDir 'media\osd\modern' }
$OutDir = FullPath $OutDir
if ($Preview) { $Preview = FullPath $Preview }

Add-Type -AssemblyName System.Drawing
$pfc = New-Object Drawing.Text.PrivateFontCollection
$pfc.AddFontFile((Join-Path $SkinDir 'fonts\MaterialIcons-Regular.ttf'))
$pfc.AddFontFile((Join-Path $SkinDir 'fonts\BebasNeue.ttf'))
$mat = $pfc.Families | Where-Object { $_.Name -like 'Material*' }
$bebas = $pfc.Families | Where-Object { $_.Name -like 'Bebas*' }
$S = 4
function RectAt([float]$y) { New-Object Drawing.RectangleF(0, $y, (100 * $S), (100 * $S)) }
function G([int]$cp) { [char]::ConvertFromUtf32($cp) }

# name -> content. g = Material glyph, t = text (lines split by |), sub = subtitle shift, on = active toggle bar
$set = [ordered]@{
  osdaudio        = @{ g = 0xE050 }; osdvideo      = @{ g = 0xE8F4 }
  osdprevtrack    = @{ g = 0xE045 }; osdrewind     = @{ g = 0xE020 }
  osdplay         = @{ g = 0xE037 }; osdpause      = @{ g = 0xE034 }
  osdstop         = @{ g = 0xE047 }; osdforward    = @{ g = 0xE01F }
  osdnexttrack    = @{ g = 0xE044 }; osdsubtitles  = @{ g = 0xE048 }
  osddvd          = @{ g = 0xE5D2 }; osdstereoscopic = @{ t = '3D' }
  osdinfo         = @{ g = 0xE88F }; ppi           = @{ t = 'PPI' }
  scopeoff        = @{ t = 'SCOPE|MASK' }; scopeon = @{ t = 'SCOPE|MASK'; on = $true }
  '219off'        = @{ t = '21:9|OSD' }; '219on'  = @{ t = '21:9|OSD'; on = $true }
  '169off'        = @{ t = '16:9|OSD' }; '169on'  = @{ t = '16:9|OSD'; on = $true }
  zoomout         = @{ g = 0xF1CF }; zoomin        = @{ g = 0xF1CE }
  zoominon        = @{ g = 0xF1CE; on = $true }
  savezoom        = @{ g = 0xE161 }; savezoomon    = @{ g = 0xE161; on = $true }
  subsup          = @{ sub = 'up' }; subsdown      = @{ sub = 'down' }
  osdbookmarks    = @{ g = 0xE866 }; osdchannelup  = @{ g = 0xE5CE }
  osdchanneldown  = @{ g = 0xE5CF }; osdchannellist = @{ g = 0xE333 }
  osdchannelguide = @{ g = 0xE241 }; osdguide      = @{ g = 0xE3EC }
  osdteletext     = @{ t = 'TXT' };  osdrecordoff  = @{ g = 0xE061 }
  osdrecordon     = @{ g = 0xE061; on = $true }
  osdplaylist     = @{ g = 0xE05F }; osdlyrics     = @{ g = 0xE029 }
  osdviz          = @{ g = 0xE01D }; osdsettings   = @{ g = 0xE8B8 }
  osdskin         = @{ g = 0xE40A }
  osdrandomoff    = @{ g = 0xE043 }; osdrandomon   = @{ g = 0xE043; on = $true }
  osdrepeat       = @{ g = 0xE040 }; osdrepeatall  = @{ g = 0xE040; on = $true }
  osdrepeatone    = @{ g = 0xE041; on = $true }
}

# Bounding box of the visible (alpha > 40) pixels of a 32bpp ARGB bitmap: @(minX, minY, maxX, maxY)
function VisibleBounds([Drawing.Bitmap]$bmp) {
  $rect = New-Object Drawing.Rectangle(0, 0, $bmp.Width, $bmp.Height)
  $data = $bmp.LockBits($rect, [Drawing.Imaging.ImageLockMode]::ReadOnly, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $bytes = New-Object byte[] ($data.Stride * $bmp.Height)
  [Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
  $bmp.UnlockBits($data)
  $minX = $bmp.Width; $minY = $bmp.Height; $maxX = -1; $maxY = -1
  for ($y = 0; $y -lt $bmp.Height; $y++) {
    $row = $y * $data.Stride
    for ($x = 0; $x -lt $bmp.Width; $x++) {
      if ($bytes[$row + $x * 4 + 3] -gt 40) {
        if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }
        if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y }
      }
    }
  }
  return @($minX, $minY, $maxX, $maxY)
}

function Render($spec, [bool]$focus) {
  $big = New-Object Drawing.Bitmap((100 * $S), (100 * $S), [Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $gb = [Drawing.Graphics]::FromImage($big); $gb.SmoothingMode = 'AntiAlias'
  $gb.Clear([Drawing.Color]::Transparent)
  $c = 12 * $S; $d = 76 * $S
  if ($focus) { $pen = New-Object Drawing.Pen([Drawing.Color]::White, (3 * $S)); $fg = [Drawing.Color]::White }
  else { $pen = New-Object Drawing.Pen([Drawing.Color]::FromArgb(110, 110, 114), (2 * $S)); $fg = [Drawing.Color]::FromArgb(200, 200, 200) }
  $gb.DrawEllipse($pen, ($c + $S), ($c + $S), ($d - 2 * $S), ($d - 2 * $S))

  # Draw the icon/text on its own canvas, then centre its visible bounds in the ring. Font metrics
  # (ascent/descent, side bearings) differ per glyph, so centring by the string box looks uneven.
  $content = New-Object Drawing.Bitmap((100 * $S), (100 * $S), [Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [Drawing.Graphics]::FromImage($content); $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAlias'
  $g.Clear([Drawing.Color]::Transparent)
  $brush = New-Object Drawing.SolidBrush($fg)
  $sf = New-Object Drawing.StringFormat; $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
  $dy = 0   # relative placement only; the whole content block is re-centred below
  if ($spec.g) {
    $f = New-Object Drawing.Font($mat, (42 * $S), [Drawing.GraphicsUnit]::Pixel)
    $g.DrawString((G $spec.g), $f, $brush, (RectAt $dy), $sf)
  } elseif ($spec.t) {
    $lines = $spec.t -split '\|'
    if ($lines.Count -eq 1) {
      $f = New-Object Drawing.Font($bebas, (31 * $S), [Drawing.GraphicsUnit]::Pixel)
      $g.DrawString($lines[0], $f, $brush, (RectAt (2 * $S + $dy)), $sf)
    } elseif ($lines[1] -eq 'OSD') {
      # ratio big, "OSD" small underneath
      $f1 = New-Object Drawing.Font($bebas, (27 * $S), [Drawing.GraphicsUnit]::Pixel)
      $f2 = New-Object Drawing.Font($bebas, (14 * $S), [Drawing.GraphicsUnit]::Pixel)
      $g.DrawString($lines[0], $f1, $brush, (RectAt (-6 * $S + $dy)), $sf)
      $g.DrawString($lines[1], $f2, $brush, (RectAt (15 * $S + $dy)), $sf)
    } else {
      # "SCOPE" at the original size, "MASK" smaller underneath (same idea as the OSD buttons)
      $f1 = New-Object Drawing.Font($bebas, (19 * $S), [Drawing.GraphicsUnit]::Pixel)
      $f2 = New-Object Drawing.Font($bebas, (12 * $S), [Drawing.GraphicsUnit]::Pixel)
      $g.DrawString($lines[0], $f1, $brush, (RectAt (-4 * $S + $dy)), $sf)
      $g.DrawString($lines[1], $f2, $brush, (RectAt (11 * $S + $dy)), $sf)
    }
  } elseif ($spec.sub) {
    $f = New-Object Drawing.Font($mat, (36 * $S), [Drawing.GraphicsUnit]::Pixel)
    $fa = New-Object Drawing.Font($mat, (28 * $S), [Drawing.GraphicsUnit]::Pixel)
    if ($spec.sub -eq 'up') {
      $g.DrawString((G 0xE048), $f, $brush, (RectAt (8 * $S)), $sf)
      $g.DrawString((G 0xE5CE), $fa, $brush, (RectAt (-15 * $S)), $sf)
    } else {
      $g.DrawString((G 0xE048), $f, $brush, (RectAt (-8 * $S)), $sf)
      $g.DrawString((G 0xE5CF), $fa, $brush, (RectAt (15 * $S)), $sf)
    }
  }
  $g.Dispose()
  $b = VisibleBounds $content
  $targetY = if ($spec.on) { 46 * $S } else { 50 * $S }   # lift a little to make room for the "on" bar
  $offX = [Math]::Round(50 * $S - ($b[0] + $b[2] + 1) / 2)
  $offY = [Math]::Round($targetY - ($b[1] + $b[3] + 1) / 2)
  $gb.DrawImageUnscaled($content, [int]$offX, [int]$offY)
  $content.Dispose()
  if ($spec.on) { $gb.FillRectangle((New-Object Drawing.SolidBrush([Drawing.Color]::White)), (40 * $S), (72 * $S), (20 * $S), (3 * $S)) }
  $gb.Dispose()
  $small = New-Object Drawing.Bitmap(100, 100, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g2 = [Drawing.Graphics]::FromImage($small); $g2.InterpolationMode = 'HighQualityBicubic'; $g2.PixelOffsetMode = 'HighQuality'
  $g2.DrawImage($big, 0, 0, 100, 100); $g2.Dispose(); $big.Dispose()
  return ,$small
}

New-Item -ItemType Directory -Force $OutDir | Out-Null
$accent = [Drawing.Color]::FromArgb(0x6d, 0xb9, 0xe5)
$cols = 12; $rows = [Math]::Ceiling($set.Count / $cols)
$sheet = New-Object Drawing.Bitmap(($cols * 100), ($rows * 222))
$sg = [Drawing.Graphics]::FromImage($sheet); $sg.Clear([Drawing.Color]::FromArgb(16, 16, 18)); $sg.TextRenderingHint = 'AntiAlias'
$lf = New-Object Drawing.Font('Segoe UI', 7.5)
# preview the focused image tinted like colordiffuse="themecolor" would
$cm = New-Object Drawing.Imaging.ColorMatrix; $cm.Matrix00 = $accent.R / 255; $cm.Matrix11 = $accent.G / 255; $cm.Matrix22 = $accent.B / 255; $cm.Matrix33 = 1; $cm.Matrix44 = 1
$ia = New-Object Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm)
$i = 0
foreach ($k in $set.Keys) {
  $nf = Render $set[$k] $false; $fo = Render $set[$k] $true
  $nf.Save((Join-Path $OutDir "${k}nf.png"), [Drawing.Imaging.ImageFormat]::Png)
  $fo.Save((Join-Path $OutDir "${k}fo.png"), [Drawing.Imaging.ImageFormat]::Png)
  $x = ($i % $cols) * 100; $y = [Math]::Floor($i / $cols) * 222
  $sg.DrawImage($nf, $x, $y)
  $sg.DrawImage($fo, (New-Object Drawing.Rectangle($x, ($y + 100), 100, 100)), 0, 0, 100, 100, [Drawing.GraphicsUnit]::Pixel, $ia)
  $sg.DrawString(($k -replace '^osd', ''), $lf, [Drawing.Brushes]::Gray, ($x + 4), ($y + 203))
  $nf.Dispose(); $fo.Dispose(); $i++
}
if ($Preview) { $sheet.Save($Preview); "preview: $Preview" }
$sg.Dispose(); $sheet.Dispose()
"generated $($set.Count * 2) images in $OutDir"
