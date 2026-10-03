# -*- coding: utf-8 -*-
"""ScopeNox Dock icon picker.

Run by the Home Menu Customizer with RunScript(special://skin/scripts/dockicon.py,<Item>), where <Item>
is the home item's type (Movie, Custom1, ...). Shows the dock icons (media/dock/icons/icons.json, made by
tools/gendock.ps1) and stores the choice in Skin.String(<Item>HomeItem.DockIcon) and its name in
<Item>HomeItem.DockIconLabel; the item's DockIcon property then overrides the dock's default icon.
"Default" clears both.
"""
import json
import sys

import xbmc
import xbmcgui
import xbmcvfs

ICON_DIR = 'dock/icons/'
CATALOG = 'special://skin/media/dock/icons/icons.json'


def main(item):
    if not item:
        return
    prefix = item + 'HomeItem.'
    with xbmcvfs.File(CATALOG) as f:
        catalog = json.loads(f.read())

    current = xbmc.getInfoLabel('Skin.String(%sDockIcon)' % prefix)
    default = xbmcgui.ListItem(xbmc.getLocalizedString(571))  # Default
    entries = [default]
    preselect = 0
    for i, icon in enumerate(catalog, 1):
        path = ICON_DIR + icon['name'] + '.png'
        entry = xbmcgui.ListItem(icon['label'])
        entry.setArt({'icon': 'special://skin/media/' + path, 'thumb': 'special://skin/media/' + path})
        entries.append(entry)
        if path == current:
            preselect = i

    choice = xbmcgui.Dialog().select(xbmc.getLocalizedString(31987), entries,  # Dock icon
                                     preselect=preselect, useDetails=True)
    if choice < 0:
        return
    if choice == 0:
        xbmc.executebuiltin('Skin.Reset(%sDockIcon)' % prefix)
        xbmc.executebuiltin('Skin.Reset(%sDockIconLabel)' % prefix)
    else:
        icon = catalog[choice - 1]
        xbmc.executebuiltin('Skin.SetString(%sDockIcon,%s%s.png)' % (prefix, ICON_DIR, icon['name']))
        xbmc.executebuiltin('Skin.SetString(%sDockIconLabel,%s)' % (prefix, icon['label']))


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else '')
