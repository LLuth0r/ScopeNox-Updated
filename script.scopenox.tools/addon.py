import json
import urllib
import urllib2
import sys

xbmc_host = 'localhost'
xbmc_port = 80

if sys.argv[1] == 'subtitles':
	if sys.argv[2] == 'up':
		print "Moving Up"
		up = { "jsonrpc": "2.0", "method": "Input.ExecuteAction", "params": { "action": "subtitleshiftup" }, "id": 1 }
		url_param_up = urllib.urlencode({'request': json.dumps(up)})

		for x in range(0, 110):
			urllib2.urlopen('http://localhost:80/jsonrpc?' + url_param_up)
		
	if sys.argv[2] == 'down':
		print "Moving Down"
		down = { "jsonrpc": "2.0", "method": "Input.ExecuteAction", "params": { "action": "subtitleshiftdown" }, "id": 1 }
		url_param_down = urllib.urlencode({'request': json.dumps(down)})

		for x in range(0, 140):
			urllib2.urlopen('http://localhost:80/jsonrpc?' + url_param_down)

if sys.argv[1] == 'zoom':
	if sys.argv[2] == 'in':
		print "Zooming In"
		zoomin = { "jsonrpc": "2.0", "method": "Input.ExecuteAction", "params": { "action": "zoomin" }, "id": 1 }
		url_param_zoomin = urllib.urlencode({'request': json.dumps(zoomin)})

		for x in range(0, 24):
			urllib2.urlopen('http://localhost:80/jsonrpc?' + url_param_zoomin)
			
		if not xbmc.getCondVisibility('skin.hassetting(scopeformat235)'):
			urllib2.urlopen('http://localhost:80/jsonrpc?' + url_param_zoomin)
			urllib2.urlopen('http://localhost:80/jsonrpc?' + url_param_zoomin)
		
	if sys.argv[2] == 'out':
		print "Zooming Out"
		zoomout = { "jsonrpc": "2.0", "method": "Input.ExecuteAction", "params": { "action": "zoomout" }, "id": 1 }
		url_param_zoomout = urllib.urlencode({'request': json.dumps(zoomout)})

		for x in range(0, 24):
			urllib2.urlopen('http://localhost:80/jsonrpc?' + url_param_zoomout)
			
		if not xbmc.getCondVisibility('skin.hassetting(scopeformat235)'):
			urllib2.urlopen('http://localhost:80/jsonrpc?' + url_param_zoomout)
			urllib2.urlopen('http://localhost:80/jsonrpc?' + url_param_zoomout)
