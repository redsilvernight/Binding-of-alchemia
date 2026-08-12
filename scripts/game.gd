# game.gd
extends Control
@onready var rooms: Node2D = $Rooms
@onready var room_spawner: MultiplayerSpawner = $RoomSpawner
@onready var players: Node2D = $Players
@onready var ennemis: Node2D = $Ennemis
@onready var HUD: Node2D = $HUD
@onready var projectiles: Node2D = $Projectiles
@onready var projectile_spawner: MultiplayerSpawner = $ProjectileSpawner
@onready var enemy_spawner: MultiplayerSpawner = $EnemySpawner
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var pickups: Node2D = $Pickups
@onready var pickup_spawner: MultiplayerSpawner = $PickupSpawner

# Phase 6.1 : toutes les salles ont le même gabarit (modèle grille fixe,
# cf. DungeonGenerator) — obligatoire pour que les portes de deux salles
# voisines s'alignent toujours sans avoir à les valider au cas par cas.
const ROOM_CELL_SIZE: Vector2 = Vector2(1000, 1296)
# Phase 9 (étages) : BASE_ROOM_COUNT est la taille d'origine (étage 1,
# inchangée) -- chaque étage suivant ajoute des salles jusqu'à ROOM_COUNT_CAP,
# cf. _room_count_for_floor. Le plafond évite un donjon ingérable (temps de
# génération, taille de la grille) après une longue série de victoires.
const BASE_ROOM_COUNT: int = 6
const ROOM_COUNT_PER_FLOOR: int = 1
const ROOM_COUNT_CAP: int = 12
const ROOM_TEMPLATE_PATHS: Array[String] = [
	"res://scenes/rooms/room_template_a.tscn",
	"res://scenes/rooms/room_template_b.tscn",
]
# Une seule salle spéciale par donjon, choisie au hasard entre alchimie et
# arme — jamais les deux ensemble (cf. room_alchemy.tscn / room_weapon.tscn).
const SPECIAL_ROOM_TEMPLATE_PATHS: Array[String] = [
	"res://scenes/rooms/room_alchemy.tscn",
	"res://scenes/rooms/room_weapon.tscn",
]
# Phase 7.4 : salle de boss, jamais tirée au hasard (cf. DungeonGenerator —
# toujours la cellule la plus éloignée du départ) — le boss lui-même est
# spawné à part, hors de la spawn table pondérée des ennemis normaux.
const BOSS_ROOM_TEMPLATE_PATH: String = "res://scenes/rooms/boss_room.tscn"
const BOSS_SCENE_PATH: String = "res://scenes/enemies/boss_01.tscn"
const BOSS_HEALTHBAR_SCENE_PATH: String = "res://scenes/ui/boss_healthbar.tscn"
# Phase 8.6 : panneau de résumé affiché à tous les pairs quand tout le monde
# est mort (cf. _check_all_players_dead) -- remplace l'ancien retour immédiat
# au hub, laisse le choix "Rejouer"/"Retour au menu" (scripts/ui/run_summary_panel.gd).
const RUN_SUMMARY_PANEL_SCENE_PATH: String = "res://scenes/ui/run_summary_panel.tscn"
# Phase 8.2 : battement avant le retour au hub après la mort du boss (voir
# _on_boss_defeated) — contrairement à la fin de run par mort collective (où
# plus personne n'envoie de RPC de jeu, tout le monde étant déjà spectateur),
# le boss peut mourir pendant que des joueurs jouent encore activement. Un
# changement de scène immédiat fait alors arriver leurs RPC en vol (tir,
# etc.) après que la scène soit déjà détruite chez le destinataire (erreurs
# réseau constatées en playtest : "Node not found", "on_despawn_receive"
# ERR_UNAUTHORIZED). Laisser quelques secondes donne le temps à ce trafic de
# se résorber naturellement pendant que la scène est encore pleinement vivante.
const BOSS_DEFEAT_TO_HUB_DELAY: float = 2.5

# Phase 6.3 : QUOI/COMBIEN spawn vient de ces tables pondérées (voir
# scripts/dungeon/spawn_table.gd), le OÙ reste une position aléatoire dans
# la salle (_random_position_in_room) — pas de Marker2D dédiés tant qu'un
# seul type d'ennemi et un placement uniforme suffisent.
const ENEMY_SPAWN_TABLE_PATH: String = "res://resources/spawn_tables/enemies_normal.tres"
const INGREDIENT_SPAWN_TABLE_PATH: String = "res://resources/spawn_tables/ingredients.tres"
const WEAPON_PART_SPAWN_TABLE_PATH: String = "res://resources/spawn_tables/weapon_parts.tres"
const ROOM_SPAWN_MARGIN: float = 80.0
# Phase 9 (étages) : tirages pick_one() additionnels par salle normale, en plus
# de la densité de base (enemy_table.pick_many(), fixée par la SpawnTable elle-
# même) -- +1 tirage tous les ENEMY_EXTRA_ROLL_FLOORS étages, plafonné à
# ENEMY_EXTRA_ROLL_CAP, cf. _extra_enemy_rolls_for_floor.
const ENEMY_EXTRA_ROLL_FLOORS: int = 2
const ENEMY_EXTRA_ROLL_CAP: int = 4

# Phase 6.4 : carte du donjon pour la mini-map (scripts/ui/minimap.gd). Toutes
# les salles y sont enregistrées dès leur spawn (_spawn_room tourne sur
# chaque pair avec les mêmes données répliquées par le RoomSpawner, donc ce
# dictionnaire est identique partout sans RPC dédié). Seul "visited" change
# après coup, et seul l'hôte décide quand — répliqué via _rpc_mark_room_visited,
# même pattern que Room._rpc_set_locked.
signal dungeon_map_changed
var dungeon_map: Dictionary = {} # Vector2i (grid_position) -> {is_start, is_special, is_boss, open_sides, visited}

# Phase 7.4 : référence au boss courant, utilisée pour rattraper l'état de
# vie d'un pair qui rejoint après le début du combat (cf. _on_peer_connected)
# — sans ça sa boss_healthbar afficherait la vie max jusqu'au prochain coup
# porté, puisque _update_health est un RPC one-shot jamais rejoué.
var current_boss: Node = null

# Bugfix hors scope (8.3, trouvé en playtest à plusieurs) : contrairement au
# tout premier lancement (menu -> game, où les clients se connectent APRÈS ce
# _ready et le MultiplayerSpawner rattrape nativement l'état déjà spawné via
# le mécanisme de late-join), une run relancée depuis le hub
# (RunManager.request_start_run) recharge cette scène alors que tous les
# pairs sont déjà connectés -- ce mécanisme de rattrapage natif ne se
# redéclenche PAS pour eux (il est lié à l'évènement peer_connected, pas à
# l'apparition d'un noeud). L'hôte, sans aller-retour réseau, atteint ce
# _ready() et spawnerait le donjon quasi immédiatement, bien avant qu'un
# client (qui doit d'abord recevoir le RPC de changement de scène, détruire
# le hub, puis charger cette scène) n'ait de RoomSpawner existant pour
# recevoir ces spawns -- constaté en playtest : donjon non généré côté
# client. D'où ce handshake explicite, complémentaire à celui de
# RunManager._change_scene_with_handshake (qui, lui, s'assure que le trafic
# de l'ANCIENNE scène soit résorbé avant de la détruire -- celui-ci s'assure
# que la NOUVELLE scène soit prête côté client avant d'y spawn quoi que ce soit).
const SCENE_READY_TIMEOUT: float = 5.0
const SCENE_READY_POLL_INTERVAL: float = 0.1
var _peers_ready_for_dungeon: Dictionary = {} # hôte uniquement : peer_id -> true

# 8.6 : évite d'instancier plusieurs fois le panneau de résumé si
# _check_all_players_dead est redéclenché après coup (ex : un pair déjà mort
# se déconnecte pendant que le panneau est déjà affiché, cf. _on_peer_disconnected).
var _run_summary_shown: bool = false

func _ready() -> void:
	add_to_group("Game")
	NetworkManager.multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	NetworkManager.multiplayer.peer_connected.connect(_on_peer_connected)
	room_spawner.spawn_function = _spawn_room
	projectile_spawner.spawn_function = _spawn_bullet
	enemy_spawner.spawn_function = _spawn_enemy
	player_spawner.spawn_function = _spawn_player
	pickup_spawner.spawn_function = _spawn_pickup

	if multiplayer.is_server():
		await _wait_for_connected_peers_ready()
		_generate_dungeon()
	else:
		notify_scene_ready.rpc_id(1)


## Hôte uniquement : attend que chaque pair déjà connecté confirme avoir
## atteint cette scène avant de générer/spawn le donjon (cf. commentaire
## au-dessus de _peers_ready_for_dungeon). Timeout de sécurité pour ne pas
## bloquer indéfiniment si un pair ne répond jamais (déconnexion en plein
## transit, paquet perdu) -- dans ce cas le donjon est quand même généré,
## ce pair ratera juste ce spawn initial (même dette que le rattrapage HP
## boss ponctuel, cf. 7.4/_on_peer_connected).
func _wait_for_connected_peers_ready() -> void:
	var expected_peers: PackedInt32Array = NetworkManager.get_peers()
	if expected_peers.is_empty():
		return
	var elapsed: float = 0.0
	while elapsed < SCENE_READY_TIMEOUT:
		var all_ready: bool = true
		for peer_id in expected_peers:
			if not _peers_ready_for_dungeon.has(peer_id):
				all_ready = false
				break
		if all_ready:
			return
		await get_tree().create_timer(SCENE_READY_POLL_INTERVAL).timeout
		elapsed += SCENE_READY_POLL_INTERVAL


## Appelé par chaque client une fois ses spawn_function assignées (donc prêt
## à recevoir les spawns de l'hôte) -- même garde que les autres RPC
## "any_peer" du projet (request_unlock, etc.) : seul l'hôte agit dessus.
@rpc("any_peer", "call_local", "reliable")
func notify_scene_ready() -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = NetworkManager.get_unique_id()
	_peers_ready_for_dungeon[sender_id] = true


func _generate_dungeon() -> void:
	# Phase 9 : RunManager.current_floor est déjà répliqué et à jour à ce point
	# (advance_floor()/reset_floor() tournent avant la bascule de scène qui mène
	# ici, cf. RunManager._change_scene_with_handshake).
	var floor_level: int = RunManager.current_floor
	var room_count: int = _room_count_for_floor(floor_level)
	var dungeon_layout: Array[Dictionary] = DungeonGenerator.generate(room_count, ROOM_TEMPLATE_PATHS, SPECIAL_ROOM_TEMPLATE_PATHS, BOSS_ROOM_TEMPLATE_PATH)
	var room_nodes: Dictionary = {} # Vector2i (grid_position) -> Room
	for room_data in dungeon_layout:
		var room: Room = room_spawner.spawn(room_data)
		room_nodes[room_data["grid_position"]] = room

	player_spawner.spawn(NetworkManager.get_unique_id())
	# Phase 8.1 : contrairement au tout premier lancement (menu -> game,
	# où les clients se connectent APRÈS ce _ready), une run relancée
	# depuis le hub (RunManager.request_start_run) recharge cette scène
	# alors que tous les pairs sont déjà connectés — peer_connected ne se
	# redéclenchera pas pour eux, donc il faut les spawn explicitement ici.
	for peer_id in NetworkManager.get_peers():
		player_spawner.spawn(peer_id)

	var enemy_table: SpawnTable = load(ENEMY_SPAWN_TABLE_PATH) as SpawnTable
	var extra_enemy_rolls: int = _extra_enemy_rolls_for_floor(floor_level)
	for room_data in dungeon_layout:
		if room_data["is_special"] or room_data["is_start"] or room_data["is_boss"]:
			continue
		var room: Room = room_nodes[room_data["grid_position"]]
		var enemy_paths: Array[String] = enemy_table.pick_many()
		for i in extra_enemy_rolls:
			var extra_path: String = enemy_table.pick_one()
			if extra_path != "":
				enemy_paths.append(extra_path)
		for enemy_scene_path in enemy_paths:
			var enemy: Node = enemy_spawner.spawn({
				"scene_path": enemy_scene_path,
				"position": _random_position_in_room(room_data),
			})
			room.register_enemy(enemy)

	# Boss (7.4) : spawn direct et déterministe dans sa salle, pas via la
	# spawn table pondérée — une seule instance, toujours au même endroit.
	for room_data in dungeon_layout:
		if not room_data["is_boss"]:
			continue
		var boss_room: Room = room_nodes[room_data["grid_position"]]
		var boss: Node = enemy_spawner.spawn({
			"scene_path": BOSS_SCENE_PATH,
			"position": _room_world_rect(room_data).get_center(),
		})
		boss_room.register_enemy(boss)
		current_boss = boss
		boss.tree_exiting.connect(func(): current_boss = null)
		# Tuer le boss termine la run pour tout le groupe (victoire), même
		# destination que la fin de run par mort collective
		# (_check_all_players_dead -> RunManager.end_run()). "died"
		# (Character._update_health) n'émet qu'une seule fois (garde not
		# is_dead), pas de risque de double appel.
		boss.died.connect(_on_boss_defeated)
		break

	var ingredient_table: SpawnTable = load(INGREDIENT_SPAWN_TABLE_PATH) as SpawnTable
	for pickup_data in _generate_pickups_from_table(ingredient_table, "ingredient", dungeon_layout, false):
		pickup_spawner.spawn(pickup_data)
	var weapon_part_table: SpawnTable = load(WEAPON_PART_SPAWN_TABLE_PATH) as SpawnTable
	for pickup_data in _generate_pickups_from_table(weapon_part_table, "weapon_part", dungeon_layout, true):
		pickup_spawner.spawn(pickup_data)

	# Phase 9 (loader) : dernier appel, une fois tous les spawns émis --
	# cf. RunManager.hide_loading_screen.
	RunManager.hide_loading_screen()

func _spawn_room(data: Dictionary) -> Node:
	var room: Room = (load(data["template_path"]) as PackedScene).instantiate()
	room.position = Vector2(data["grid_position"]) * ROOM_CELL_SIZE
	# set_open_sides() lit des noeuds enfants via @onready : le noeud doit
	# être entré dans l'arbre (donc _ready() déjà passé) avant qu'on
	# l'appelle, sans quoi les références sont encore nulles (même piège
	# documenté pour launch() en Phase 3.5).
	room.set_open_sides.call_deferred(data["open_sides"])
	room.player_entered.connect(_on_room_player_entered.bind(data["grid_position"]))
	_register_room_in_map(data)
	return room

func _register_room_in_map(data: Dictionary) -> void:
	dungeon_map[data["grid_position"]] = {
		"is_start": data["is_start"],
		"is_special": data["is_special"],
		"is_boss": data["is_boss"],
		"open_sides": data["open_sides"],
		"visited": data["is_start"], # la salle de départ est toujours déjà "découverte"
	}
	dungeon_map_changed.emit()

## Ne s'exécute jamais côté client : Room.player_entered n'est émis que
## lorsque la salle hôte détecte l'entrée (cf. room.gd, garde is_server()
## avant l'émission) — pas besoin de re-vérifier ici.
func _on_room_player_entered(player: Node2D, grid_position: Vector2i) -> void:
	_rpc_mark_room_visited.rpc(grid_position)
	_teleport_party_to_room(player, grid_position)

## Façon Binding of Isaac (8.1) : dès qu'un joueur franchit une salle, tout
## le groupe (vivants ET spectateurs) y est téléporté avec lui. Corrige un
## vrai blocage constaté en playtest : un joueur mort/spectateur (cf.
## player.gd.kill()) ne peut plus nettoyer les ennemis de sa salle, donc sa
## porte reste verrouillée pour toujours (cf. Room._rpc_set_locked) — sans
## ça, un coéquipier resté ailleurs se retrouvait bloqué dehors. Avec ce
## comportement le groupe ne peut plus se séparer entre salles, donc ce cas
## ne peut simplement plus se produire.
func _teleport_party_to_room(entering_player: Node2D, grid_position: Vector2i) -> void:
	var room_rect: Rect2 = _room_world_rect({"grid_position": grid_position})
	# Position de l'entrant lui-même (déjà dans la salle à cet instant, cf.
	# RoomTrigger) plutôt que le centre de la salle : il vient de passer la
	# porte, donc apparaître à côté de lui place le reste du groupe près de
	# cette porte plutôt qu'en plein milieu de la salle.
	var target_position: Vector2 = entering_player.position
	for player in players.get_children():
		if player == entering_player:
			continue
		if room_rect.has_point(player.position):
			continue # déjà dans cette salle : rien à faire
		# Le joueur hôte a déjà l'autorité sur son propre noeud : affectation
		# directe. Pour un noeud possédé par un client, seul lui peut modifier
		# sa position (cf. player.tscn, MultiplayerSynchronizer répliquant
		# ".:position" depuis l'autorité) — d'où le RPC ciblé vers son pair.
		if player.is_multiplayer_authority():
			player.position = target_position
		else:
			player.teleport.rpc_id(int(player.name), target_position)

@rpc("authority", "call_local", "reliable")
func _rpc_mark_room_visited(grid_position: Vector2i) -> void:
	if not dungeon_map.has(grid_position) or dungeon_map[grid_position]["visited"]:
		return
	dungeon_map[grid_position]["visited"] = true
	dungeon_map_changed.emit()

func _room_world_rect(room_data: Dictionary) -> Rect2:
	return Rect2(Vector2(room_data["grid_position"]) * ROOM_CELL_SIZE, ROOM_CELL_SIZE)

func _random_explorable_room(dungeon_layout: Array[Dictionary]) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for room_data in dungeon_layout:
		if room_data["is_special"] or room_data["is_boss"]:
			continue
		candidates.append(room_data)
	if candidates.is_empty():
		candidates = dungeon_layout
	return candidates[randi() % candidates.size()]

func _random_position_in_room(room_data: Dictionary) -> Vector2:
	var rect: Rect2 = _room_world_rect(room_data)
	return Vector2(
		rect.position.x + randf_range(ROOM_SPAWN_MARGIN, rect.size.x - ROOM_SPAWN_MARGIN),
		rect.position.y + randf_range(ROOM_SPAWN_MARGIN, rect.size.y - ROOM_SPAWN_MARGIN)
	)

## unique = true : chaque entrée de la table apparaît exactement une fois
## (garantit la couverture complète d'un pool, ex : une pièce d'arme de
## chaque catégorie). unique = false : tirage pondéré avec remise sur
## min_count..max_count de la table (rareté relative, doublons possibles).
func _generate_pickups_from_table(table: SpawnTable, item_type: String, dungeon_layout: Array[Dictionary], unique: bool) -> Array[Dictionary]:
	var paths: Array[String] = table.pick_all_shuffled() if unique else table.pick_many()
	var pickups: Array[Dictionary] = []
	for path in paths:
		var room_data: Dictionary = _random_explorable_room(dungeon_layout)
		pickups.append({"item_type": item_type, "item_resource_path": path, "position": _random_position_in_room(room_data)})
	return pickups

func _spawn_pickup(data: Dictionary) -> Node:
	var scene_path := "res://scenes/debug/ingredient_pickup.tscn" if data["item_type"] == "ingredient" else "res://scenes/debug/weapon_part_pickup.tscn"
	var pickup: Pickup = load(scene_path).instantiate() if false else (load(scene_path) as PackedScene).instantiate()
	pickup.position = data["position"]
	pickup.item_type = data["item_type"]
	pickup.item_resource = load(data["item_resource_path"])
	return pickup
	
func _spawn_player(id: int) -> Node:
	var player = PlayerManager.spawnPlayer(id)
	# La salle de départ est toujours à la cellule de grille (0,0), donc
	# son centre monde est constant : pas besoin de connaître la layout ici.
	player.position = ROOM_CELL_SIZE / 2
	player.instance_hud.connect(_hud_instance)
	player.instance_projectile.connect(_on_projectile_requested)
	if multiplayer.is_server():
		player.died.connect(_check_all_players_dead)
	return player

## scene_path optionnel (Phase 7.3) : les projectiles ennemis (voir
## enemy_ranged.gd) passent leur propre scène (layer/mask pour toucher les
## joueurs, pas les ennemis) ; sans cette clé, comportement identique à avant
## (balle du joueur).
func _spawn_bullet(data: Dictionary) -> Node:
	var scene_path: String = data.get("scene_path", "res://scenes/projectiles/bullet.tscn")
	var bullet: Bullet = (load(scene_path) as PackedScene).instantiate()
	bullet.setup(data["damage"], data["speed"], data["lifetime"], data["trajectory"])
	if data.has("impact_effect_data"):
		var effect: ImpactEffect = ImpactEffect.from_dict(data["impact_effect_data"])
		bullet.set_impact_effect(effect)
	bullet.launch.call_deferred(data["from_position"], data["direction"])
	return bullet

func _spawn_enemy(data: Dictionary) -> Node:
	var enemy: Node = (load(data["scene_path"]) as PackedScene).instantiate()
	enemy.position = data["position"]
	# Tourne identiquement sur chaque pair, y compris pour un pair qui rejoint
	# après coup (le MultiplayerSpawner rejoue les spawns déjà existants) :
	# la barre de vie du boss apparaît donc pour tout le monde sans code
	# spécifique côté connexion, cf. _on_peer_connected pour le rattrapage HP.
	if data["scene_path"] == BOSS_SCENE_PATH:
		var healthbar: Node = (load(BOSS_HEALTHBAR_SCENE_PATH) as PackedScene).instantiate()
		# bind_boss() lit $Bar (@onready) : le noeud doit être entré dans
		# l'arbre (add_child avant bind) sinon _bar est encore Nil — même
		# piège documenté pour set_open_sides()/launch() ailleurs dans le projet.
		HUD.add_child(healthbar)
		healthbar.bind_boss(enemy)
	return enemy

func _on_peer_disconnected(peer_id) -> void:
	if players.has_node(str(peer_id)):
		players.get_node(str(peer_id)).queue_free()
	# call_deferred : queue_free() ne retire le noeud de "players" qu'à la fin
	# de la frame, un check immédiat verrait encore l'ancien peer déconnecté
	# comme "vivant" (dernier joueur vivant qui quitte plutôt que de mourir).
	_check_all_players_dead.call_deferred()

## Phase 8.1 : mort individuelle (spectateur, cf. player.gd.kill()) mais fin
## de run globale seulement quand tous les joueurs sont morts — hôte
## uniquement, appelé à chaque mort et à chaque déconnexion.
func _check_all_players_dead() -> void:
	if not multiplayer.is_server():
		return
	if players.get_child_count() == 0:
		return
	if _run_summary_shown:
		return
	for player in players.get_children():
		if not player.is_dead:
			return
	# 8.6 : n'appelle plus RunManager.end_run() directement -- affiche d'abord
	# le panneau de résumé sur chaque pair, c'est lui qui déclenche le retour
	# au hub ("Rejouer") ou au menu principal. Un simple RPC ne détruit ni ne
	# crée de noeud de scène, pas besoin du call_deferred qu'exigeait
	# end_run() (cf. commentaire de RunManager._rpc_change_scene).
	_run_summary_shown = true
	_show_run_summary.rpc()

## Cf. RUN_SUMMARY_PANEL_SCENE_PATH : instancié sur chaque pair (call_local),
## chacun affiche ses propres données locales déjà répliquées (pièces d'arme
## et composition de mixture de CHAQUE joueur, cf. weapon.gd
## set_mixture_ingredients_networked -- seule sa propre monnaie de run,
## MetaProgression étant par-pair par conception).
@rpc("authority", "call_local", "reliable")
func _show_run_summary() -> void:
	var panel: Node = (load(RUN_SUMMARY_PANEL_SCENE_PATH) as PackedScene).instantiate()
	HUD.add_child(panel)
	panel.show_summary(players.get_children())

## Cf. BOSS_DEFEAT_TO_HUB_DELAY : ne rappelle pas RunManager.end_run()
## immédiatement pour laisser le trafic réseau en vol au moment du coup de
## grâce se résorber pendant que la scène est encore chargée partout.
## Phase 9 : l'étage avance dès la victoire (pas après le délai) pour que
## RunManager.current_floor soit déjà à jour si un autre système le lit entre-
## temps (ex : affichage du panneau de résumé, non concerné aujourd'hui).
func _on_boss_defeated() -> void:
	RunManager.advance_floor()
	get_tree().create_timer(BOSS_DEFEAT_TO_HUB_DELAY).timeout.connect(RunManager.end_run)


## Phase 9 : +1 salle par étage au-delà de la taille de base (étage 1 = donjon
## d'origine, inchangé), plafonné à ROOM_COUNT_CAP.
func _room_count_for_floor(floor_level: int) -> int:
	return mini(BASE_ROOM_COUNT + (floor_level - 1) * ROOM_COUNT_PER_FLOOR, ROOM_COUNT_CAP)


## Phase 9 : tirages pick_one() additionnels par salle normale, en plus de la
## densité de base -- même logique de crescendo que _room_count_for_floor,
## plafonnée à ENEMY_EXTRA_ROLL_CAP.
func _extra_enemy_rolls_for_floor(floor_level: int) -> int:
	return mini((floor_level - 1) / ENEMY_EXTRA_ROLL_FLOORS, ENEMY_EXTRA_ROLL_CAP)

func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		player_spawner.spawn(peer_id)
		# Rattrape la vie actuelle du boss pour ce pair (7.4) : le
		# MultiplayerSpawner rejoue le spawn du boss aux pairs qui rejoignent
		# en cours de partie, mais _update_health est un RPC one-shot déjà
		# passé — sans ce rattrapage sa boss_healthbar afficherait la vie max.
		if is_instance_valid(current_boss):
			current_boss._update_health.rpc_id(peer_id, current_boss.max_lifepoint, current_boss.lifepoint)

func _hud_instance(hud: Node) -> void:
	HUD.add_child(hud)

func _on_projectile_requested(data: Dictionary) -> void:
	if multiplayer.is_server():
		projectile_spawner.spawn(data)

## Même pipeline que _on_projectile_requested, mais appelé directement par un
## script d'ennemi (EnemyStateRangedAttack via enemy_ranged.gd.fire_at) plutôt
## que déclenché par un signal joueur.
func request_enemy_projectile(data: Dictionary) -> void:
	if multiplayer.is_server():
		projectile_spawner.spawn(data)
