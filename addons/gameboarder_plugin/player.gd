extends RefCounted

var api

func setup(api_instance):
	api = api_instance
	
func newPlayer(player_name: String, player_password: String, game_id: int, callback: Callable):
	api._make_request(HTTPClient.METHOD_POST, "/players", {
		"name": player_name,
		"password": player_password,
		"game_id": game_id
	}, callback)

func getByName(player_name: String, game_id: int, callback: Callable):
	api._make_request(HTTPClient.METHOD_POST, "/players/by-name", {
		"name" : player_name,
		"game_id": game_id
	}, callback)

func delete(player_id: int, callback: Callable):
	api._make_request(HTTPClient.METHOD_DELETE, str("/players/", player_id), {}, callback)
