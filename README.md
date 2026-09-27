# ScopeNox

This is a modified version of AeonNox by BigNoid. 

It is made to suit people with CIH (Constant Image Height) setups that have the resolution at 1920x1080 and have the projector zoomed so that scope images fill the screen.

Using the normal Kodi skins in this case causes part of the skin to spill outside the scope frame onto walls.

This version of the skin contains all the GUI within an 800/820 pixel height. 

To install simply download the zip file and then within Kodi go to AddOns and 'Install from Zip' and it should install.

Latest Release (Nexus): https://github.com/LLuth0r/ScopeNox-Updated/releases

In order to switch between 2.35 and 2.40 format go to :
System -> Appearance -> Skin -> Settings -> Scope -> Scope Format (Toggle)

There are two tools for use with this script.  One is scopenox-tools.  This creates the sub-menu buttons for scope masking/zooming.
https://github.com/LLuth0r/ScopeNox-Tools/releases


AutoZoom is built into the skin (as of 1.2.1). Turn it on at System -> Appearance -> Skin -> Settings -> Scope -> AutoZoom.
It reads the video stream's aspect ratio and zooms 16:9 (and 1.33 - 2.19) content out to fit the scope frame for the selected
2.35 / 2.40 format. Content 2.20 and wider is left alone and gets the scope mask. The separate scopenox-autozoom script is no longer needed.

Player Process Info (PPI) shows what Kodi is doing with the current video: hardware decoding, decoder and pixel format, deinterlacing,
source resolution / aspect ratio / FPS, HDR type (Dolby Vision, HDR10, HLG or SDR), output display mode, audio decoder and channels,
plus CPU and memory use. Open it with the PPI button on the playback OSD, or press 'O' on a keyboard during playback.
The PPI screen sits inside the scope frame so none of it is cropped off on a zoomed CIH screen.
