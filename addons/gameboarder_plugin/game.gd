extends RefCounted

var api

func setup(api_instance):
	api = api_instance
	
func getGames(user_id: int, callback: Callable):
	api._make_request(HTTPClient.METHOD_GET, str("/users/", user_id), {}, func(_code, response):
		callback.call(_code, response.games)	
	)

func getGameDetails(game_id: int, callback: Callable):
	api._make_request(HTTPClient.METHOD_GET, str("/games/", game_id), {}, callback)

func getSaves(game_id: int, callback: Callable):
	api._make_request(HTTPClient.METHOD_GET, str("/saves/", game_id), {}, func(_code, response):
		callback.call(_code, response)	
	)
	
func newGame(game_name: String,save_mode: String, max_save_slots, callback: Callable):
	api._make_request(HTTPClient.METHOD_POST, "/games", {
		"name": game_name,
		"save_mode": save_mode,
		"max_save_slots": max_save_slots
	}, callback)

func delete(game_id: int, callback: Callable):
	api._make_request(HTTPClient.METHOD_DELETE, str("/games/", game_id), {}, callback)
