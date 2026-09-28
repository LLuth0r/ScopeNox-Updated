# -*- coding: utf-8 -*-
"""ScopeNox AutoZoom.

Run by the skin with RunScript(special://skin/scripts/autozoom.py,<action>):

  apply    VideoFullScreen onload. Once per file: use the zoom saved for this movie,
           otherwise fit the picture to the scope frame from the stream's aspect ratio.
  zoomin   OSD zoom-in button. Set 1.00 and remember it for this movie
           (e.g. scope movies with the black bars encoded in a 16:9 frame).
  zoomout  OSD zoom-out button. Fit to the scope frame and forget any saved zoom.
  save     OSD save-zoom button. Remember the current zoom for this movie
           (e.g. 0.81 set with Kodi's zoom slider to crop thin baked-in bars).
  clear    Skin Settings. Forget all saved zooms.

Saved zooms are keyed by the movie's IMDb/TMDb/TVDB id, not the file path: with
PlexKodiConnect add-on paths the playing path is a Plex stream URL that changes.
"""
import json
import math
import os
import sys

import xbmc
import xbmcgui
import xbmcvfs

LOG_PREFIX = '[ScopeNox AutoZoom] '
STORE_DIR = 'special://profile/addon_data/skin.scope.nox.omega/'
STORE_FILE = STORE_DIR + 'autozoom.json'
APPLIED_PROP = 'ScopeNox.AutoZoom.Applied'  # playing file AutoZoom already handled
# saved zoom of the playing movie, e.g. "0.81"; empty when none. Drives the OSD "on" bars:
# save-zoom button for any saved zoom, zoom-in button when it is "1.00"
SAVED_PROP = 'ScopeNox.AutoZoom.Saved'
HOME = xbmcgui.Window(10000)

# Visible scope frame height on the 1920x1080 panel for each skin scope format
FRAME_HEIGHT_235 = 820.0
FRAME_HEIGHT_240 = 800.0
SCOPE_DAR = 2.2  # 2.20 and wider already fills the frame (and gets the scope mask)
# Letterbox height above/below the scope frame in the 1080 frame: (1080 - frame height) / 2
LETTERBOX_235 = (1080.0 - FRAME_HEIGHT_235) / 2
LETTERBOX_240 = (1080.0 - FRAME_HEIGHT_240) / 2


def log(msg, level=xbmc.LOGINFO):
    xbmc.log(LOG_PREFIX + msg, level)


# ---------------------------------------------------------------- storage

def load_store():
    path = xbmcvfs.translatePath(STORE_FILE)
    if not os.path.exists(path):
        return {'version': 1, 'items': {}}
    try:
        with open(path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        data.setdefault('items', {})
        return data
    except (OSError, ValueError) as e:
        log('could not read %s: %s' % (path, e), xbmc.LOGWARNING)
        return {'version': 1, 'items': {}}


def save_store(data):
    xbmcvfs.mkdirs(STORE_DIR)
    path = xbmcvfs.translatePath(STORE_FILE)
    tmp = path + '.tmp'
    with open(tmp, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, sort_keys=True)
    os.replace(tmp, path)
    update_count(data)


def update_count(data):
    xbmc.executebuiltin('Skin.SetString(AutoZoomOverrideCount,%d)' % len(data['items']))


# ---------------------------------------------------------------- playing item

def item_key():
    """Stable key for the playing item, and a readable label for it."""
    player = xbmc.Player()
    if not player.isPlayingVideo():
        return None, None
    tag = player.getVideoInfoTag()
    title = tag.getTitle() or ''
    year = tag.getYear()
    label = '%s (%s)' % (title, year) if year else title

    if tag.getMediaType() == 'episode' and tag.getTVShowTitle():
        # one setting per show: a series is normally all one aspect ratio
        show = tag.getTVShowTitle()
        return 'tvshow:' + show.lower(), show

    for provider in ('imdb', 'tmdb', 'tvdb'):
        try:
            uid = tag.getUniqueID(provider)
        except Exception:  # older API
            uid = ''
        if uid:
            return '%s:%s' % (provider, uid), label
    imdb = tag.getIMDBNumber()
    if imdb:
        return 'imdb:' + imdb, label
    if title:
        return 'title:%s|%s' % (title.lower(), year or ''), label
    return None, label


def playing_file():
    try:
        return xbmc.Player().getPlayingFile()
    except RuntimeError:
        return ''


def stream_dar(timeout=10.0):
    """Wait for the player to report the stream's display aspect ratio."""
    monitor = xbmc.Monitor()
    waited = 0.0
    while waited < timeout:
        value = xbmc.getInfoLabel('Player.Process(VideoDAR)')
        try:
            dar = float(value)
            if dar > 0:
                # Kodi reports two decimals; snap 1.78 / 1.33 back to exact 16:9 / 4:3
                for exact in (16.0 / 9.0, 4.0 / 3.0):
                    if abs(dar - exact) < 0.006:
                        return exact
                return dar
        except ValueError:
            pass
        if monitor.waitForAbort(0.25):
            break
        waited += 0.25
    return None


def screen_size():
    """Output size in pixels. The skin's 1920x1080 layout is stretched to fill it, so on a 16:9 screen
    everything below matches the 1080 layout; on e.g. a 16:10 monitor the video gets extra bars."""
    try:
        width = float(xbmc.getInfoLabel('System.ScreenWidth'))
        height = float(xbmc.getInfoLabel('System.ScreenHeight'))
        if width > 0 and height > 0:
            return width, height
    except ValueError:
        pass
    return 1920.0, 1080.0


def picture_height(dar, zoom, screen):
    """Displayed height (screen px) of a picture with this aspect ratio: fitted to the screen, then zoomed."""
    width, height = screen
    return min(height, width / dar) * zoom


def fit_zoom(dar):
    """Zoom that fits the displayed picture inside the scope frame (None = leave alone)."""
    if dar is None or dar >= SCOPE_DAR:
        return None
    screen = screen_size()
    frame = FRAME_HEIGHT_235 if xbmc.getCondVisibility('Skin.HasSetting(scopeFormat235)') else FRAME_HEIGHT_240
    frame *= screen[1] / 1080.0  # the scope frame (skin layout) in screen px
    # zoom steps are 0.01; round down so the picture never overflows the frame by more than ~1px
    return min(1.0, math.floor(frame / picture_height(dar, 1.0, screen) * 100 + 0.1) / 100)


# ---------------------------------------------------------------- projector alignment

def align_shift_px():
    """Vertical shift (in 1080-frame pixels, negative = up) for Skin Settings -> Projector alignment.

    Top / Bottom move the picture by the letterbox height, so the scope band lands at the top / bottom
    edge of the frame, matching the GUI (Includes_ProjectorAlign.xml)."""
    align = xbmc.getInfoLabel('Skin.String(ProjectorAlign)')
    letterbox = LETTERBOX_235 if xbmc.getCondVisibility('Skin.HasSetting(scopeFormat235)') else LETTERBOX_240
    return {'top': -letterbox, 'bottom': letterbox}.get(align, 0.0)


def vertical_shift_value(dar, zoom, shift_px, screen=None):
    """Kodi verticalshift that moves the picture by shift_px of the skin's 1080 layout
    (see CBaseRenderer::CalcNormalRenderRect).

    -1..1 moves the picture within its black bars; beyond that it moves by a fraction of the picture height.
    Works in screen pixels, because the bars depend on the screen's shape (16:9 vs e.g. 16:10)."""
    if not shift_px:
        return 0.0
    screen = screen or screen_size()
    screen_height = screen[1]
    distance = abs(shift_px) * screen_height / 1080.0  # skin layout px -> screen px
    height = picture_height(dar, zoom, screen)
    bars = max((screen_height - height) / 2.0, 0.0)
    if distance <= bars:
        value = distance / bars
    else:
        shift_range = min(height, height - (height - screen_height) / 2.0)
        value = 1.0 + (distance - bars) / shift_range
    return round(math.copysign(value, shift_px), 4)


# ---------------------------------------------------------------- zoom

def jsonrpc(method, params=None):
    request = {'jsonrpc': '2.0', 'id': 1, 'method': method}
    if params is not None:
        request['params'] = params
    return json.loads(xbmc.executeJSONRPC(json.dumps(request)))


def set_zoom(zoom, dar=None):
    """Set the zoom, with the vertical shift for the projector alignment at that zoom."""
    if dar is None:
        dar = stream_dar(timeout=2.0) or 16.0 / 9.0
    shift = vertical_shift_value(dar, zoom, align_shift_px())
    result = jsonrpc('Player.SetViewMode', {'viewmode': {'zoom': zoom, 'verticalshift': shift}})
    if 'error' not in result:
        return True
    # fallback: step from the current zoom with the relative zoom actions
    log('SetViewMode failed (%s), stepping instead' % result['error'], xbmc.LOGWARNING)
    current = jsonrpc('Player.GetViewMode').get('result', {}).get('zoom')
    if current is None:
        return False
    steps = int(round((zoom - current) / 0.01))
    action = 'zoomin' if steps > 0 else 'zoomout'
    for _ in range(abs(steps)):
        jsonrpc('Input.ExecuteAction', {'action': action})
    jsonrpc('Player.SetViewMode', {'viewmode': {'verticalshift': shift}})
    return True


def current_zoom():
    zoom = jsonrpc('Player.GetViewMode').get('result', {}).get('zoom')
    return None if zoom is None else round(float(zoom), 2)


def set_indicator(zoom):
    if zoom is None:
        HOME.clearProperty(SAVED_PROP)
    else:
        HOME.setProperty(SAVED_PROP, '%.2f' % zoom)


def notify(message):
    xbmcgui.Dialog().notification('AutoZoom', message, xbmcgui.NOTIFICATION_INFO, 2500, False)


# ---------------------------------------------------------------- actions

def watch_playback(current_file):
    """Stay alive until this playback ends, then clear the once-per-file marker.

    The skin also clears it when fullscreen video closes with nothing playing, but a quick stop and
    replay of the same file can race that check, and the replay would then skip AutoZoom."""
    monitor = xbmc.Monitor()
    player = xbmc.Player()
    while not monitor.abortRequested():
        if not player.isPlayingVideo() or playing_file() != current_file:
            break
        if monitor.waitForAbort(1):
            return
    if HOME.getProperty(APPLIED_PROP) == current_file:
        HOME.clearProperty(APPLIED_PROP)
        HOME.clearProperty(SAVED_PROP)


def action_apply():
    key, label = item_key()
    saved = load_store()['items'].get(key) if key else None
    set_indicator(saved['zoom'] if saved else None)  # refreshed every time fullscreen opens, even if AutoZoom is off

    current_file = playing_file()
    if not current_file:
        log('apply: skipped, nothing playing yet', xbmc.LOGDEBUG)
        return
    if HOME.getProperty(APPLIED_PROP) == current_file:
        log('apply: skipped, already handled %s' % label, xbmc.LOGDEBUG)
        return
    HOME.setProperty(APPLIED_PROP, current_file)
    try:
        apply_view(saved, key, label)
    finally:
        watch_playback(current_file)


def apply_view(saved, key, label):
    """Set the zoom (AutoZoom) and vertical shift (projector alignment) for a newly started video."""
    autozoom = xbmc.getCondVisibility('Skin.HasSetting(enableAutoZoom)')
    shift_px = align_shift_px()
    view = jsonrpc('Player.GetViewMode').get('result', {})
    stale_shift = bool(view.get('verticalshift'))  # Kodi restores a shift saved for this file
    if not autozoom and not shift_px and not stale_shift:
        return  # centre alignment and AutoZoom off: leave the view alone

    dar = stream_dar()
    zoom, source = None, 'unchanged'
    if autozoom:
        if saved:
            zoom, source = saved['zoom'], 'saved'
        else:
            zoom, source = fit_zoom(dar), 'aspect ratio %s' % dar
    if zoom is None and (shift_px or stale_shift):
        zoom = round(float(view.get('zoom', 1.0)), 2)  # only the shift changes
    log('apply: %s key=%s zoom=%s (%s) shift=%spx' % (label, key, zoom, source, shift_px))
    if zoom is not None:
        set_zoom(zoom, dar or 16.0 / 9.0)


def remember(zoom):
    """Save zoom for the playing movie. Returns its label, or None if it can't be identified."""
    key, label = item_key()
    if not key:
        return None
    data = load_store()
    data['items'][key] = {'zoom': zoom, 'title': label}
    save_store(data)
    set_indicator(zoom)
    log('saved zoom %.2f for %s (%s)' % (zoom, label, key))
    return label


def action_zoomin():
    set_zoom(1.0)
    label = remember(1.0)
    if label:
        notify('Remembering full size for %s' % label)


def action_save():
    zoom = current_zoom()
    if zoom is None:
        log('save: could not read the current zoom', xbmc.LOGWARNING)
        return
    label = remember(zoom)
    if label:
        notify('Remembering zoom %.2f for %s' % (zoom, label))
    else:
        notify("Can't identify this video to remember its zoom")


def action_zoomout():
    zoom = fit_zoom(stream_dar(timeout=2.0) or 16.0 / 9.0)
    if zoom is not None:
        set_zoom(zoom)
    set_indicator(None)
    key, label = item_key()
    data = load_store()
    if key and data['items'].pop(key, None):
        save_store(data)
        log('removed saved zoom for %s (%s)' % (label, key))
        notify('AutoZoom back on for %s' % label)


def action_clear():
    data = load_store()
    count = len(data['items'])
    if not count:
        xbmcgui.Dialog().ok('AutoZoom', 'There are no saved zooms.')
        return
    if xbmcgui.Dialog().yesno('AutoZoom', 'Forget the saved zoom for %d title(s)?' % count):
        data['items'] = {}
        save_store(data)
        set_indicator(None)
        log('cleared %d saved zooms' % count)


ACTIONS = {
    'apply': action_apply,
    'zoomin': action_zoomin,
    'zoomout': action_zoomout,
    'save': action_save,
    'clear': action_clear,
}

if __name__ == '__main__':
    name = sys.argv[1] if len(sys.argv) > 1 else 'apply'
    handler = ACTIONS.get(name)
    if handler:
        handler()
    else:
        log('unknown action %r' % name, xbmc.LOGWARNING)
