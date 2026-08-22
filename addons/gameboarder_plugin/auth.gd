extends RefCounted

var api

func setup(api_instance):
	api = api_instance
	
func register(email: String, name: String, password: String, callback: Callable):
	var data = {
		"name": name,
		"email": email,
		"password": password
	}
	
	api._make_request(HTTPClient.METHOD_POST, "/register", data, func(code, response):
		if code == 200 and response.has("access_token"):
			api.set_dev_token(response.access_token)
		callback.call(code, response)
	, "none")

func login(email: String, password: String, callback: Callable):
	var data = {
		"email": email,
		"password": password
	}
	
	api._make_request(HTTPClient.METHOD_POST, "/login", data, func(code, response):
		if code == 200 and response.has("access_token"):
			api.set_dev_token(response.access_token)
		callback.call(code, response)
	, "none")

func guestLogin(game_id: int, callback: Callable):
	var device_id = api.get_or_create_device_id()
	var data = {
		"game_id": game_id,
		"device_id": device_id
	}

	api._make_request(HTTPClient.METHOD_POST, "/players/guest", data, func(code, response):
		if code == 200 and response.has("access_token"):
			api.set_player_token(response.access_token)
		callback.call(code, response)
	, "none")

func authenticatePlayer(player_name: String, player_password: String, game_id: int, callback: Callable):
	var data = {
		"player_name": player_name,
		"player_password": player_password,
		"game_id": game_id
	}

	api._make_request(HTTPClient.METHOD_POST, "/players/authenticate", data, func(code, response):
		if code == 200 and response.has("access_token"):
			api.set_player_token(response.access_token)
		callback.call(code, response)
	, "none")

func claimAccount(player_name: String, player_password: String, callback: Callable):
	var data = {
		"name": player_name,
		"password": player_password
	}

	api._make_request(HTTPClient.METHOD_POST, "/players/claim", data, func(code, response):
		if code == 200 and response.has("access_token"):
			api.set_player_token(response.access_token)
			api.mark_account_claimed(player_name)
		callback.call(code, response)
	, "player")

func me(callback):
	api._make_request(HTTPClient.METHOD_GET, "/me", {}, callback)
	
func logout(callback):
	api._make_request(HTTPClient.METHOD_POST, "/logout", {}, func(code, response):
		api.clear_dev_token()
		callback.call(code, response)
	)

func deleteAccount(user_id, callback):
	api._make_request(HTTPClient.METHOD_DELETE, str("/users/", user_id), {}, func(code, response):
		api.clear_dev_token()
		callback.call(code, response)
	)
