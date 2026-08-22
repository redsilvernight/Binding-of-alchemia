extends RefCounted

var api

func setup(api_instance):
	api = api_instance
	
func newLeaderboard(leaderboard_name: String, leaderboard_is_unique: bool, game_id: int, callback: Callable):
	api._make_request(HTTPClient.METHOD_POST, "/leaderboards", {
		"name": leaderboard_name,
		"is_unique": leaderboard_is_unique,
		"game_id": game_id
	}, callback)

func delete(leaderboard_id: int, callback: Callable):
	api._make_request(HTTPClient.METHOD_DELETE, str("/leaderboards/", leaderboard_id), {}, callback)

func getLeaderboard(leaderboard_id: int, callback: Callable):
	api._make_request(HTTPClient.METHOD_GET, str("/leaderboards/", leaderboard_id), {}, callback)

func getScoredLeaderboard(leaderboard_id: int, callback: Callable):
	api._make_request(HTTPClient.METHOD_GET, str("/leaderboards/", leaderboard_id), {}, func(_code, response):
		callback.call(_code, response.scores)	
	)
