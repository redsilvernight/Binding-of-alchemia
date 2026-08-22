extends RefCounted

var api

func setup(api_instance):
	api = api_instance

func getSaves(game_id: int, player_id: int, callback: Callable):
	api._make_request(HTTPClient.METHOD_GET, str("/saves/", game_id, "/", player_id, "/"), {}, callback, "player")

func newSave(game_id: int, player_id: int, content: Dictionary, slot: int = 1, callback: Callable = Callable()):
	api._make_request(HTTPClient.METHOD_POST, str("/saves/", game_id, "/", player_id, "/"), {
		"slot": slot,
		"content": content
	}, callback, "player")

func getSave(game_id: int, player_id: int, slot: int, callback: Callable):
	api._make_request(HTTPClient.METHOD_GET, str("/saves/", game_id, "/", player_id, "/", slot), {}, callback, "player")

func delete(save_id: int, callback: Callable):
	api._make_request(HTTPClient.METHOD_DELETE, str("/saves/", save_id), {}, callback)
