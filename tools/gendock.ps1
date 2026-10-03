<#
.SYNOPSIS
  Generates the textures for the "Dock" home menu style (media/dock/).

.DESCRIPTION
  icons/<name>.png   128x128 white icon: defaults for the home item types (ListItem.Property(Item))
                     and a set to pick from in the Home Menu Customizer (icons/icons.json);
                     tinted in the skin with colordiffuse (white / near-black / themecolor).
  accent.png         small white square, tinted themecolor in the skin for the focus line.
  scrim.png          vertical white gradient (transparent at the top), tinted black (white text) or white (dark
                     text) along the bottom of the frame so the floating icons and text stay readable on any artwork.

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
# name = Material Symbols code point, label shown in the Dock icon picker (scripts/dockicon.py reads
# icons/icons.json). The first 14 are the defaults for the home item types (Includes_HomeDock.xml).
$icons = [ordered]@{
  movie = 0xe404, 'Movies'; tvshow = 0xe63b, 'TV'; livetv = 0xe63a, 'Live TV'; music = 0xe405, 'Music'
  musicvideo = 0xe063, 'Music videos'; pictures = 0xe413, 'Pictures'; videos = 0xe04a, 'Videos'
  programs = 0xe5c3, 'Apps'; games = 0xea28, 'Games'; favorites = 0xe87e, 'Favourites'; weather = 0xf172, 'Weather'
  settings = 0xe8b8, 'Settings'; shutdown = 0xf8c7, 'Power'; custom = 0xe9b0, 'Grid'
  '4k' = 0xe072, '4K'; hd = 0xe052, 'HD'; theaters = 0xe8da, 'Cinema'; movie_filter = 0xe43a, 'Collection'
  smart_display = 0xf06a, 'Video channel'; subscriptions = 0xe064, 'Subscriptions'; play_circle = 0xe1c4, 'Play'
  playlist_play = 0xe05f, 'Playlist'; new_releases = 0xef76, 'New'; history = 0xe8b3, 'Recent'
  animation = 0xe71c, 'Animation'; kid_star = 0xf526, 'Kids'; family_restroom = 0xf1a2, 'Family'
  theater_comedy = 0xea66, 'Comedy'; swords = 0xf889, 'Action'; rocket_launch = 0xeb9b, 'Sci-fi'
  castle = 0xeab1, 'Fantasy'; nature_people = 0xe407, 'Nature'; pets = 0xe91d, 'Animals'
  sports = 0xea30, 'Sports'; sports_soccer = 0xea2f, 'Soccer'; sports_football = 0xea29, 'Football'
  fitness_center = 0xeb43, 'Fitness'; school = 0xe80c, 'Learning'; public = 0xe80b, 'World'
  newspaper = 0xeb81, 'News'; podcasts = 0xf048, 'Podcasts'; radio = 0xe03e, 'Radio'
  headphones = 0xf01f, 'Audio'; library_music = 0xe030, 'Music library'; star = 0xf09a, 'Star'
  bookmark = 0xe8e7, 'Bookmark'; download = 0xf090, 'Downloads'; cloud = 0xf15c, 'Cloud'
  folder = 0xe2c7, 'Folder'; explore = 0xe87a, 'Explore'; search = 0xef7a, 'Search'
}

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

$a = New-Bitmap 8 8; $a[1].FillRectangle([System.Drawing.Brushes]::White, 0, 0, 8, 8); $a[1].Dispose(); Save $a[0] 'accent.png'
# scrim: eased so it has no visible top edge
$sc = New-Bitmap 8 256; $sc[1].FillRectangle((VGrad 0 256 @((C 0 255 255 255), (C 40 255 255 255), (C 120 255 255 255), (C 170 255 255 255)) @(0, 0.35, 0.75, 1)), 0, 0, 8, 256); $sc[1].Dispose(); Save $sc[0] 'scrim.png'

# icons# icons
$pfc = New-Object System.Drawing.Text.PrivateFontCollection; $pfc.AddFontFile($Font)
$family = $pfc.Families[0]
foreach ($name in $icons.Keys) {
  $size = 128; $b = New-Bitmap $size $size; $g = $b[1]
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $p.AddString([string][char]$icons[$name][0], $family, 0, 112, (New-Object System.Drawing.PointF 0, 0), [System.Drawing.StringFormat]::GenericTypographic)
  $r = $p.GetBounds(); $scale = 104 / [Math]::Max($r.Width, $r.Height)
  $m = New-Object System.Drawing.Drawing2D.Matrix
  $m.Translate($size / 2, $size / 2); $m.Scale($scale, $scale); $m.Translate(-($r.X + $r.Width / 2), -($r.Y + $r.Height / 2))
  $p.Transform($m); $g.FillPath([System.Drawing.Brushes]::White, $p); $g.Dispose()
  Save $b[0] "icons\$name.png"
}
$catalog = foreach ($name in $icons.Keys) { [ordered]@{ name = $name; label = $icons[$name][1] } }
[IO.File]::WriteAllText((Join-Path $OutDir 'icons\icons.json'), (ConvertTo-Json @($catalog) -Compress), (New-Object System.Text.UTF8Encoding $false))
"textures in $OutDir"
