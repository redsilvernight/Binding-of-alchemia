extends RefCounted

var api

func setup(api_instance):
	api = api_instance

func create(port: int, max_players: int, ip: String = "", callback: Callable = Callable()):
	var data = {
		"port": port,
		"max_players": max_players
	}
	if ip != "":
		data["ip"] = ip
	api._make_request(HTTPClient.METHOD_POST, "/sessions", data, callback, "player")

func heartbeat(code: String, port: int = -1, status: String = "", callback: Callable = Callable()):
	var data = {}
	if port > 0:
		data["port"] = port
	if status != "":
		data["status"] = status
	api._make_request(HTTPClient.METHOD_POST, str("/sessions/", code, "/heartbeat"), data, callback, "player")

func resolve(code: String, callback: Callable):
	api._make_request(HTTPClient.METHOD_GET, str("/sessions/", code), {}, callback, "player")

func close(code: String, callback: Callable = Callable()):
	api._make_request(HTTPClient.METHOD_DELETE, str("/sessions/", code), {}, callback, "player")
