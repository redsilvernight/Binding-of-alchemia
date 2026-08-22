extends RefCounted

var api

func setup(api_instance):
	api = api_instance
	
func newHighscore(player_id: int, leaderboard_id: int, highscore: int, callback: Callable):
	api._make_request(HTTPClient.METHOD_POST, "/scores/highscore", {
		"player_id": player_id,
		"leaderboard_id": leaderboard_id,
		"score": highscore
	}, callback, "player")

func newScore(player_id: int, leaderboard_id: int, score: int, callback: Callable):
	api._make_request(HTTPClient.METHOD_POST, "/scores", {
		"player_id": player_id,
		"leaderboard_id": leaderboard_id,
		"score": score
	}, callback, "player")

func delete(score_id: int, callback: Callable):
	api._make_request(HTTPClient.METHOD_DELETE, str("/scores/", score_id), {}, callback)
