# ScopeNox

This is a modified version of AeonNox by BigNoid.

It is made to suit people with CIH (Constant Image Height) setups that have the resolution at 1920x1080 and have the projector zoomed so that scope images fill the screen.

Using the normal Kodi skins in this case causes part of the skin to spill outside the scope frame onto walls.

This version of the skin contains all the GUI within an 800/820 pixel height.

## Install

Download the zip file, then in Kodi go to Add-ons -> Install from zip file.

Latest release (Kodi 21 Omega): https://github.com/LLuth0r/ScopeNox-Updated/releases

No extra add-ons are needed for the scope features. The skin does its own zooming, scope masking and subtitle positioning.

## Scope format

To switch between the 2.35 and 2.40 formats go to:
System -> Appearance -> Skin -> Settings -> Scope -> Scope Format (Toggle)

## AutoZoom

AutoZoom is built into the skin (as of 1.2.1). Turn it on at System -> Appearance -> Skin -> Settings -> Scope -> AutoZoom.
It reads the video stream's aspect ratio and zooms 16:9 (and 1.33 - 2.19) content out to fit the scope frame for the selected
2.35 / 2.40 format. Content 2.20 and wider is left alone and gets the scope mask. The separate scopenox-autozoom script is no longer needed.

Kodi takes the aspect ratio from the encoded frame. Scope movies stored as a 16:9 frame with the black bars as part of the picture
(most Blu-ray and UHD rips) report 1.78, so AutoZoom zooms them out too. Press the zoom-in button on the playback menu once for such
a movie: it goes back to 1.00 and AutoZoom remembers that for the movie, so it plays at full size from then on.

Remembered movies are stored by IMDb/TMDb id rather than file path, so they survive library rescans, file moves and
PlexKodiConnect's changing stream URLs. TV episodes are remembered per show. Pressing zoom out forgets a movie again, and
System -> Appearance -> Skin -> Settings -> Scope -> Clear saved AutoZoom settings forgets them all. AutoZoom runs from
scripts/autozoom.py inside the skin; there is nothing extra to install.

## Zoom and subtitle buttons

Turn on System -> Appearance -> Skin -> Settings -> Scope -> Show Zoom/Subtitle Buttons for Non-Scope to add four buttons to the playback menu:

- Zoom out: fits the picture inside the scope frame (0.74 for 16:9 at 2.40, 0.76 at 2.35) and forgets any remembered zoom for the movie
- Zoom in: back to full size (1.00), remembered for the movie
- Save zoom: remembers whatever zoom is set right now for the movie. Use it when a movie needs something in between,
  e.g. a 1.90 IMAX release stored in a 16:9 frame: set about 0.81 with Kodi's own zoom (Video settings -> Zoom amount)
  to crop the thin bars, then press Save zoom. The button shows a bar while the movie has a remembered zoom.
- Subtitles up / down: moves subtitles into or out of the scope frame

These used to need the ScopeNox-Tools add-on; they are now built into the skin.

## Player Process Info (PPI)

Player Process Info (PPI) shows what Kodi is doing with the current video: hardware decoding, decoder and pixel format, deinterlacing,
source resolution / aspect ratio / FPS, HDR type (Dolby Vision, HDR10, HLG or SDR), output display mode, audio decoder and channels,
plus CPU and memory use. Open it with the PPI button on the playback OSD, or press 'O' on a keyboard during playback.
The PPI screen sits inside the scope frame so none of it is cropped off on a zoomed CIH screen.
