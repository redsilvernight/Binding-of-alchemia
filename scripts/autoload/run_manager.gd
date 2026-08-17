extends Node
## Phase 8.1 : bascule de scène synchronisée hôte -> tous les pairs, entre le
## donjon et le hub. Autoload donc persiste à travers change_scene_to_file
## (contrairement à "Game"/"Hub", qui sont détruits à chaque bascule) : seul
## endroit fiable pour porter cette transition à travers les deux scènes.

const DUNGEON_SCENE_PATH: String = "res://scenes/game.tscn"
const HUB_SCENE_PATH: String = "res://scenes/world/hub.tscn"

# Phase 9 (étages) : compteur d'étage courant, partagé par toute la partie
# (comme le donjon lui-même) -- vit ici plutôt que dans MetaProgression (qui
# est PAR JOUEUR par conception) ou game.gd (détruit à chaque bascule de
# scène), cf. game.gd._generate_dungeon qui le lit pour dimensionner le
# prochain donjon et _on_boss_defeated qui l'incrémente.
signal floor_changed(new_floor: int)
var current_floor: int = 1

# Persistance des objets de run entre étages (hors scope roadmap, retour
# utilisateur) : Inventory/Weapon sont des enfants de Player, recréés à
# chaque changement de scène (cf. PlayerManager.spawnPlayer) -- sans ce
# cache, une victoire de boss (donjon -> hub -> donjon suivant) perdait
# ingrédients et mixture chargée exactement comme une mort, ce qui n'est
# pas voulu : seule une mort doit faire perdre les objets de la run.
# peer_id -> Dictionary (cf. game.gd._capture_run_state), pris juste avant
# le retour au hub après un boss vaincu (_on_boss_defeated), consommé une
# fois au spawn du joueur sur le donjon suivant (_spawn_player) pour ne
# jamais réappliquer un instantané périmé à une run ultérieure.
var _saved_run_state: Dictionary = {}

# Phase 9 (loader) : écran de chargement plein écran affiché pendant toute
# transition de scène gérée ici (hub <-> donjon) -- instancié une seule fois
# et gardé en enfant permanent de cet Autoload (donc jamais détruit par
# change_scene_to_file, cf. loading_screen.gd) plutôt que recréé à chaque
# transition.
const LOADING_SCREEN_SCENE_PATH: String = "res://scenes/ui/loading_screen.tscn"
var _loading_screen: CanvasLayer = null


func _ready() -> void:
	_loading_screen = (load(LOADING_SCREEN_SCENE_PATH) as PackedScene).instantiate()
	add_child(_loading_screen)

# Bugfix hors scope (8.3, trouvé en playtest à plusieurs) : un changement de
# scène immédiat (change_scene_to_file détruit toute l'ancienne scène d'un
# coup) court-circuite le trafic MultiplayerSynchronizer encore en vol (sync
# de position continue, non fiable/UDP par nature) -- il arrive après que la
# scène soit détruite chez le destinataire (constaté en playtest :
# on_despawn_receive ERR_UNAUTHORIZED, "Node not found", cache id introuvable).
# Handshake en deux phases plutôt qu'un délai fixe deviné : l'hôte diffuse
# "préparez-vous" et attend l'accusé de réception de chaque pair avant de
# vraiment changer de scène, ce qui réduit la fenêtre de course à ~1
# aller-retour réseau au lieu de plusieurs secondes. Ça ne l'élimine pas à
# 100% (aucune garantie d'ordre entre un canal fiable et le canal non fiable
# de sync position -- limite de Godot, pas de ce code), mais la rend rare.
const SCENE_CHANGE_ACK_TIMEOUT: float = 3.0
const SCENE_CHANGE_ACK_POLL_INTERVAL: float = 0.05
var _peers_acked_scene_change: Dictionary = {} # hôte uniquement : peer_id -> true, réinitialisé à chaque transition


## Appelé côté hôte quand le boss est vaincu (cf. game.gd._on_boss_defeated,
## qui applique son propre délai de mise en scène avant d'appeler ceci --
## indépendant du handshake réseau ci-dessous), ou via request_return_to_hub
## quand un joueur clique "Rejouer" sur le panneau de résumé de run affiché
## après une mort collective (8.6, cf. game.gd._check_all_players_dead).
func end_run() -> void:
	if not multiplayer.is_server():
		return
	_change_scene_with_handshake(HUB_SCENE_PATH)


## Requêtable par n'importe quel pair depuis le panneau de résumé de run
## (8.6, bouton "Rejouer") : même garde que request_start_run, seul l'hôte
## décide réellement. Seul chemin qui mène ici -- une victoire de boss retourne
## au hub directement via end_run() (cf. game.gd._on_boss_defeated), jamais par
## ce panneau -- donc atteindre ce point signifie toujours une défaite : remet
## l'étage à 1 (Phase 9) avant de rendre la main au hub.
@rpc("any_peer", "call_local", "reliable")
func request_return_to_hub() -> void:
	if not multiplayer.is_server():
		return
	reset_floor()
	end_run()


## Requêtable par n'importe quel pair depuis le hub (RunStartStation) :
## seul l'hôte décide réellement, même garde que request_fire/request_craft_mixture.
@rpc("any_peer", "call_local", "reliable")
func request_start_run() -> void:
	if not multiplayer.is_server():
		return
	MetaProgression.reset_run_currency()
	_change_scene_with_handshake(DUNGEON_SCENE_PATH)


## Hôte uniquement : diffuse "préparez-vous" à tous les pairs déjà connectés
## et attend leur accusé de réception (avec timeout de sécurité si un pair ne
## répond jamais -- déconnexion en plein transit) avant de diffuser le
## changement de scène réel.
func _change_scene_with_handshake(scene_path: String) -> void:
	# Phase 9 (loader) : affiché dès le tout début de la transition (avant même
	# l'accusé de réception réseau) -- couvre tout le temps mort visible côté
	# joueurs : accusés de réception, destruction/chargement de la scène,
	# génération du donjon (plus longue à mesure que l'étage augmente, cf.
	# game.gd._room_count_for_floor) et réplication des spawns aux clients.
	show_loading_screen()
	_peers_acked_scene_change.clear()
	var expected_peers: PackedInt32Array = NetworkManager.get_peers()
	if not expected_peers.is_empty():
		_rpc_prepare_scene_change.rpc()
		var elapsed: float = 0.0
		while elapsed < SCENE_CHANGE_ACK_TIMEOUT:
			var all_acked: bool = true
			for peer_id in expected_peers:
				if not _peers_acked_scene_change.has(peer_id):
					all_acked = false
					break
			if all_acked:
				break
			await get_tree().create_timer(SCENE_CHANGE_ACK_POLL_INTERVAL).timeout
			elapsed += SCENE_CHANGE_ACK_POLL_INTERVAL
	_rpc_change_scene.rpc(scene_path)


## Envoyé uniquement aux clients (l'hôte n'a pas besoin de s'auto-notifier) :
## répond immédiatement par un accusé de réception, ne fait rien d'autre --
## le simple aller-retour de ce message fiable et ordonné suffit à vider le
## plus gros du trafic en vol accumulé avant ce point.
@rpc("authority", "reliable")
func _rpc_prepare_scene_change() -> void:
	_rpc_ack_scene_change.rpc_id(1)


## Toujours appelé par un pair distant (jamais l'hôte lui-même, cf.
## _rpc_prepare_scene_change qui n'est pas call_local) : get_remote_sender_id()
## y est donc toujours valide.
@rpc("any_peer", "reliable")
func _rpc_ack_scene_change() -> void:
	if not multiplayer.is_server():
		return
	_peers_acked_scene_change[multiplayer.get_remote_sender_id()] = true


@rpc("authority", "call_local", "reliable")
func _rpc_change_scene(scene_path: String) -> void:
	# call_deferred : end_run() est atteint depuis take_damage() -> _update_health()
	# -> died.emit(), souvent lui-même déclenché depuis un callback physique
	# (ex : contact ennemi, cf. enemy_erratic.gd._on_collision_area_body_entered).
	# Un change_scene_to_file() direct y détruit des CollisionObject2D en plein
	# callback physique (erreur moteur) et peut libérer le noeud joueur avant
	# que les autres listeners de "died" (ex : Player._on_died) aient tourné.
	get_tree().change_scene_to_file.call_deferred(scene_path)


## Hôte uniquement, appelé depuis game.gd._on_boss_defeated juste avant le
## retour au hub (délai BOSS_DEFEAT_TO_HUB_DELAY) : le prochain donjon généré
## (_generate_dungeon, lu au retour en run) doit déjà voir l'étage à jour.
func advance_floor() -> void:
	if not multiplayer.is_server():
		return
	_rpc_set_floor.rpc(current_floor + 1, true)


## Hôte uniquement : remet l'étage à 1, soit au tout début d'une nouvelle
## session réseau (cf. NetworkManager.hosting()/play_solo()), soit après une
## mort collective (cf. request_return_to_hub ci-dessus).
func reset_floor() -> void:
	if not multiplayer.is_server():
		return
	# Une mort doit faire perdre les objets de la run -- vide tout instantané
	# encore en attente (ex : un joueur n'a jamais atteint le prochain donjon
	# après un précédent floor_advance, cas limite improbable mais on ne veut
	# jamais qu'un vieil instantané fuite dans une run ultérieure).
	_saved_run_state.clear()
	_rpc_set_floor.rpc(1, false) # pas un "avancement" (retour après une défaite) : pas de SFX


## Hôte uniquement, appelé depuis game.gd._on_boss_defeated pour chaque
## joueur encore vivant (cf. _capture_run_state) juste avant le retour au hub.
func save_run_state(peer_id: int, snapshot: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	_saved_run_state[peer_id] = snapshot


## Hôte uniquement, appelé depuis game.gd._spawn_player sur le donjon suivant.
## Consomme l'instantané (erase) : une restauration ne doit jamais se
## répéter pour la même transition.
func take_saved_run_state(peer_id: int) -> Dictionary:
	if not _saved_run_state.has(peer_id):
		return {}
	var snapshot: Dictionary = _saved_run_state[peer_id]
	_saved_run_state.erase(peer_id)
	return snapshot


## play_sound distingue une vraie progression (advance_floor) d'une remise à
## zéro (reset_floor, après une défaite) -- même RPC toutes deux pour ne pas
## dupliquer la logique de réplication, seul le SFX diffère.
@rpc("authority", "call_local", "reliable")
func _rpc_set_floor(new_floor: int, play_sound: bool = true) -> void:
	current_floor = new_floor
	floor_changed.emit(new_floor)
	if play_sound:
		AudioManager.play_sfx("floor_advance")


## Hôte uniquement, appelé en tout début de _change_scene_with_handshake.
func show_loading_screen() -> void:
	if not multiplayer.is_server():
		return
	_rpc_set_loading.rpc(true)


## Hôte uniquement, appelé une fois le contenu de la nouvelle scène
## entièrement généré/spawné côté hôte (cf. game.gd._generate_dungeon,
## hub.gd._ready) -- repose sur l'ordre garanti des canaux fiables de Godot
## (même canal que les spawns des MultiplayerSpawner concernés) pour n'arriver
## chez chaque client qu'après que ses propres spawns aient déjà été appliqués,
## plutôt qu'un accusé de réception explicite par client (jugé superflu ici :
## contrairement au changement de scène lui-même, rater ce timing ne casse
## rien, l'écran resterait juste affiché un instant de trop).
func hide_loading_screen() -> void:
	if not multiplayer.is_server():
		return
	_rpc_set_loading.rpc(false)


@rpc("authority", "call_local", "reliable")
func _rpc_set_loading(is_loading: bool) -> void:
	if is_loading:
		_loading_screen.show_loading()
	else:
		_loading_screen.hide_loading()
