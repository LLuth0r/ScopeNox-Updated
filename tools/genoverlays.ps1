# Generates the watched-status poster ribbons in media/overlays/status/.
#   unwatched.png   empty ring           (never played)
#   inprogress.png  half-filled ring     (resume point / some episodes watched)
#   watched.png     filled ring + check  (played)
# Loose files can't override textures packed in Textures.xbt, so these live in a
# new folder instead of replacing overlays/showcase/*.
# Usage: powershell -File tools/genoverlays.ps1
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root 'media\overlays\status'
New-Item -ItemType Directory -Force $out | Out-Null

$size = 166
# ribbon: same footprint as the old overlays/showcase ribbons
$rl = 21; $rr = 143; $rt = 1; $rb = 143; $notch = 118
$cx = 82; $cy = 60; $ring = 34; $stroke = 11
$glyph = [System.Drawing.Color]::FromArgb(255, 214, 214, 214)

function New-RibbonPath([float]$dx, [float]$dy) {
	$p = New-Object System.Drawing.Drawing2D.GraphicsPath
	$pts = [System.Drawing.PointF[]]@(
		(New-Object System.Drawing.PointF ($rl + $dx), ($rt + $dy)),
		(New-Object System.Drawing.PointF ($rr + $dx), ($rt + $dy)),
		(New-Object System.Drawing.PointF ($rr + $dx), ($rb + $dy)),
		(New-Object System.Drawing.PointF ($cx + 0.5 + $dx), ($notch + $dy)),
		(New-Object System.Drawing.PointF ($rl + $dx), ($rb + $dy)))
	$p.AddPolygon($pts)
	$p
}

function New-RibbonBrush {
	$br = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Point 0, $rt), (New-Object System.Drawing.Point 0, ($rb + 1)), ([System.Drawing.Color]::Black), ([System.Drawing.Color]::Black)
	$blend = New-Object System.Drawing.Drawing2D.ColorBlend 3
	$blend.Colors = [System.Drawing.Color[]]@(
		[System.Drawing.Color]::FromArgb(191, 162, 162, 162),
		[System.Drawing.Color]::FromArgb(191, 54, 54, 54),
		[System.Drawing.Color]::FromArgb(191, 146, 146, 146))
	$blend.Positions = [single[]]@(0, 0.5, 1)
	$br.InterpolationColors = $blend
	$br
}

function New-Ribbon([string]$name, [scriptblock]$drawGlyph) {
	$bmp = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
	$g = [System.Drawing.Graphics]::FromImage($bmp)
	$g.SmoothingMode = 'AntiAlias'
	$g.Clear([System.Drawing.Color]::Transparent)
	# soft drop shadow
	for ($i = 8; $i -ge 1; $i--) {
		$sp = New-RibbonPath 2 3
		$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(10, 0, 0, 0)), ($i * 2)
		$pen.LineJoin = 'Round'
		$g.DrawPath($pen, $sp); $g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(10, 0, 0, 0))), $sp)
		$pen.Dispose(); $sp.Dispose()
	}
	# ribbon (cleared first so the shadow doesn't darken it)
	$rp = New-RibbonPath 0 0
	$g.CompositingMode = 'SourceCopy'
	$ribbon = New-RibbonBrush
	$g.FillPath($ribbon, $rp)
	$g.CompositingMode = 'SourceOver'
	& $drawGlyph $g $ribbon
	$g.Dispose()
	$path = Join-Path $out $name
	$bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
	$bmp.Dispose()
	"wrote $path"
}

function Draw-Ring($g) {
	$pen = New-Object System.Drawing.Pen $glyph, $stroke
	$g.DrawEllipse($pen, ($cx - $ring), ($cy - $ring), ($ring * 2), ($ring * 2))
	$pen.Dispose()
}

New-Ribbon 'unwatched.png' { param($g, $ribbon) Draw-Ring $g }

New-Ribbon 'inprogress.png' {
	param($g, $ribbon)
	Draw-Ring $g
	$r = $ring - $stroke / 2 - 5
	$g.FillPie((New-Object System.Drawing.SolidBrush $glyph), ($cx - $r), ($cy - $r), ($r * 2), ($r * 2), -90, 180)
}

New-Ribbon 'watched.png' {
	param($g, $ribbon)
	$r = $ring + $stroke / 2
	$g.FillEllipse((New-Object System.Drawing.SolidBrush $glyph), ($cx - $r), ($cy - $r), ($r * 2), ($r * 2))
	# check mark knocked out of the disc in the ribbon gradient
	$pen = New-Object System.Drawing.Pen $ribbon, 10
	$pen.StartCap = 'Round'; $pen.EndCap = 'Round'; $pen.LineJoin = 'Round'
	$pts = [System.Drawing.PointF[]]@(
		(New-Object System.Drawing.PointF ($cx - 18), ($cy + 1)),
		(New-Object System.Drawing.PointF ($cx - 5), ($cy + 14)),
		(New-Object System.Drawing.PointF ($cx + 19), ($cy - 12)))
	$g.CompositingMode = 'SourceCopy'
	$g.DrawLines($pen, $pts)
	$pen.Dispose()
}
