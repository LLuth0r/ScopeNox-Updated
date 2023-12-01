import sys

if sys.argv[1] == 'subtitles':
	if sys.argv[2] == 'up':
		print ("Moving Up")

		for x in range(0, 110):
			xbmc.executeJSONRPC('{"jsonrpc": "2.0", "method": "Input.ExecuteAction", "params": { "action": "subtitleshiftup" }, "id": 0}')
		
	if sys.argv[2] == 'down':
		print ("Moving Down")

		for x in range(0, 110):
			xbmc.executeJSONRPC('{"jsonrpc": "2.0", "method": "Input.ExecuteAction", "params": { "action": "subtitleshiftdown" }, "id": 0}')


if sys.argv[1] == 'zoom':
	if sys.argv[2] == 'in':
		print ("Zooming In")

		for x in range(0, 24):
			xbmc.executeJSONRPC('{"jsonrpc": "2.0", "method": "Input.ExecuteAction", "params": { "action": "zoomin" }, "id": 0}')
			
		if not xbmc.getCondVisibility('skin.hassetting(scopeformat235)'):
			xbmc.executeJSONRPC('{"jsonrpc": "2.0", "method": "Input.ExecuteAction", "params": { "action": "zoomin" }, "id": 0}')
			xbmc.executeJSONRPC('{"jsonrpc": "2.0", "method": "Input.ExecuteAction", "params": { "action": "zoomin" }, "id": 0}')
		
	if sys.argv[2] == 'out':
		print ("Zooming Out")

		for x in range(0, 24):
			xbmc.executeJSONRPC('{"jsonrpc": "2.0", "method": "Input.ExecuteAction", "params": { "action": "zoomout" }, "id": 0}')
			
		if not xbmc.getCondVisibility('skin.hassetting(scopeformat235)'):
			xbmc.executeJSONRPC('{"jsonrpc": "2.0", "method": "Input.ExecuteAction", "params": { "action": "zoomout" }, "id": 0}')
			xbmc.executeJSONRPC('{"jsonrpc": "2.0", "method": "Input.ExecuteAction", "params": { "action": "zoomout" }, "id": 0}')
