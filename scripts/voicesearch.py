# -*- coding: utf-8 -*-
"""ScopeNox voice search.

Run by the skin with RunScript(special://skin/scripts/voicesearch.py[,<action>]):

  (none)      Long-press Menu (keymap below). Opens the keyboard and starts Android speech
              recognition straight away; when the spoken text arrives the keyboard is closed for
              you. Movies or TV shows whose title contains the text are then shown in the current
              library window, so the current view (InfoWall, ShowCase, ...) is kept. Elsewhere the
              Videos window is opened. Back returns to the unfiltered list.
  keymap_on   Skin Settings switch. Installs the long-press Menu keymap.
  keymap_off  Skin Settings switch. Removes it.

Kodi on Android only handles the remote's Search/mic key while the keyboard is open (the rest
of the time Android keeps it for Google Assistant), so another button has to open the search.
Inside the keyboard, Menu or the mic key start speech recognition again.
"""
import json
import sys
import threading
import time
from urllib.parse import quote

import xbmc
import xbmcgui
import xbmcvfs

LOG_PREFIX = '[ScopeNox VoiceSearch] '
KEYMAP_FILE = 'special://profile/keymaps/scopenox_voicesearch.xml'
KEYMAP = '''<?xml version="1.0" encoding="UTF-8"?>
<!-- Installed by the ScopeNox skin (Skin Settings > General > Voice search on long-press Menu). -->
<keymap>
	<global>
		<keyboard>
			<menu mod="longpress">RunScript(special://skin/scripts/voicesearch.py)</menu>
		</keyboard>
	</global>
</keymap>
'''
WINDOW_VIDEOS = 10025
WINDOW_KEYBOARD = 10103
CONTROL_EDIT = 312
CONTROL_DONE = 300
LIBRARY = {
    'movies': ('videodb://movies/titles/', 'VideoLibrary.GetMovies', 'movies'),
    'tvshows': ('videodb://tvshows/titles/', 'VideoLibrary.GetTVShows', 'tvshows'),
}


def log(msg):
    xbmc.log(LOG_PREFIX + msg, xbmc.LOGINFO)


def set_keymap(enabled):
    path = xbmcvfs.translatePath(KEYMAP_FILE)
    if enabled:
        try:
            with open(path, encoding='utf-8') as f:
                if f.read() == KEYMAP:
                    return
        except OSError:
            pass
        with open(path, 'w', encoding='utf-8') as f:
            f.write(KEYMAP)
    elif xbmcvfs.exists(path):
        xbmcvfs.delete(path)
    else:
        return
    xbmc.executebuiltin('Action(reloadkeymaps)')
    log('keymap %s' % ('installed' if enabled else 'removed'))


def keyboard_text():
    return xbmc.getInfoLabel('Control.GetLabel(%d).index(1)' % CONTROL_EDIT)


def listen():
    """Start speech recognition in the keyboard and confirm it when the spoken text arrives."""
    monitor = xbmc.Monitor()
    deadline = time.time() + 3
    while not xbmc.getCondVisibility('Window.IsActive(virtualkeyboard)'):
        if time.time() > deadline or monitor.waitForAbort(0.1):
            return
    xbmc.executebuiltin('Action(VoiceRecognizer)')
    previous = keyboard_text()
    while xbmc.getCondVisibility('Window.IsActive(virtualkeyboard)'):
        if monitor.waitForAbort(0.2):
            return
        text = keyboard_text()
        # speech fills in the whole text at once; typing adds one character at a time
        if not previous and len(text) > 1:
            if monitor.waitForAbort(0.8):
                return
            if xbmc.getCondVisibility('Window.IsActive(virtualkeyboard)') and keyboard_text() == text:
                xbmc.executebuiltin('SendClick(%d,%d)' % (WINDOW_KEYBOARD, CONTROL_DONE))
            return
        previous = text


def count(kind, text):
    method = LIBRARY[kind][1]
    query = {'jsonrpc': '2.0', 'id': 1, 'method': method,
             'params': {'filter': {'field': 'title', 'operator': 'contains', 'value': text},
                        'limits': {'start': 0, 'end': 1}}}
    result = json.loads(xbmc.executeJSONRPC(json.dumps(query))).get('result', {})
    return result.get('limits', {}).get('total', 0)


def search():
    content = xbmc.getInfoLabel('Container.Content')
    in_videos = xbmcgui.getCurrentWindowId() == WINDOW_VIDEOS
    preferred = 'tvshows' if in_videos and content in ('tvshows', 'seasons', 'episodes') else 'movies'

    threading.Thread(target=listen, daemon=True).start()
    keyboard = xbmc.Keyboard('', xbmc.getLocalizedString(137))  # Search
    keyboard.doModal()
    if not keyboard.isConfirmed():
        return
    text = keyboard.getText().strip().rstrip('.?!').strip()
    if not text:
        return

    order = [preferred] + [k for k in LIBRARY if k != preferred]
    kind = next((k for k in order if count(k, text)), None)
    log('"%s": %s' % (text, kind or 'no match'))
    if not kind:
        xbmcgui.Dialog().notification(xbmc.getLocalizedString(137),
                                      xbmc.getLocalizedString(31982) % text,
                                      xbmcgui.NOTIFICATION_INFO, 4000)
        return

    base, _, xsp_type = LIBRARY[kind]
    xsp = {'type': xsp_type,
           'rules': {'and': [{'field': 'title', 'operator': 'contains', 'value': [text]}]}}
    url = base + '?xsp=' + quote(json.dumps(xsp, separators=(',', ':')), safe='')
    if in_videos:
        xbmc.executebuiltin('Container.Update("%s")' % url)
    else:
        xbmc.executebuiltin('ActivateWindow(Videos,"%s",return)' % url)
    focus_first_result(base)


def focus_first_result(base):
    """Move focus off the ".." item so the view's info panel shows the first result."""
    monitor = xbmc.Monitor()
    deadline = time.time() + 5
    while not (xbmc.getInfoLabel('Container.FolderPath').startswith(base + '?xsp=')
               and not xbmc.getCondVisibility('Container.IsUpdating')):
        if time.time() > deadline or monitor.waitForAbort(0.1):
            return
    if xbmc.getCondVisibility('ListItem.IsParentFolder'):
        xbmc.executebuiltin('SetFocus(%s,1,absolute)' % xbmc.getInfoLabel('System.CurrentControlID'))


if __name__ == '__main__':
    action = sys.argv[1] if len(sys.argv) > 1 else ''
    if action == 'keymap_on':
        set_keymap(True)
    elif action == 'keymap_off':
        set_keymap(False)
    else:
        search()
