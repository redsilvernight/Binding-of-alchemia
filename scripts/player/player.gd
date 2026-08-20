# player.gd
extends Character
signal instance_hud(hud: Node)
signal instance_projectile(data: Dictionary)
@export var speed: float = 300.0
@export var invulnerability_duration: float = 1.0
@export var hud_scene: PackedScene = preload("res://scenes/HUD/hud.tscn")
@export var inventory_screen_scene: PackedScene = preload("res://scenes/ui/inventory_screen.tscn")
@export var alchemy_crafting_scene: PackedScene = preload("res://scenes/ui/alchemy_crafting.tscn")
@export var weapon_crafting_scene: PackedScene = preload("res://scenes/ui/weapon_crafting.tscn")
@export var unlock_screen_scene: PackedScene = preload("res://scenes/ui/unlock_screen.tscn")
@export var pause_menu_scene: PackedScene = preload("res://scenes/ui/pause_menu.tscn")
## Facteur de zoom-in supplémentaire au-delà du strict nécessaire pour que la
## zone visible tienne dans une salle (cf. _update_camera_zoom()) -- évite
## qu'un pixel de la salle voisine ne dépasse au bord de l'écran par arrondi.
const CAMERA_ZOOM_MARGIN: float = 1.05
@onready var player_camera: Camera2D = $Camera2D
@onready var damage_timer: Timer = $DamageTimer
@onready var weapon: Weapon = $Weapon
@onready var inventory: Inventory = $Inventory
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var _light: PointLight2D = $PlayerLight
var was_water_pressed: bool = false
var was_mixture_pressed: bool = false
var last_aim_direction: Vector2 = Vector2.RIGHT
var last_stick_activity_time: float = -INF
var last_mouse_activity_time: float = -INF
var last_mouse_screen_position: Vector2 = Vector2.ZERO
var mouse_position_initialized: bool = false
var last_movement_activity_time: float = -INF
var inventory_screen: Node = null
var alchemy_crafting_screen: Node = null
var weapon_crafting_screen: Node = null
var unlock_screen: Node = null
var _spectate_target: Node2D = null
var _pending_fire_type: String = ""
var _pending_fire_direction: Vector2 = Vector2.ZERO
## Bruits de pas (retour utilisateur : uniquement le joueur, pas les ennemis --
## essayé sur Character/EnemyBase d'abord, retiré). Calé sur la FRAME de l'anim
## "walk-*" (0 et milieu de cycle = 2 pas par cycle, un par pied) plutôt qu'une
## distance/un minuteur fixe : suit exactement la vitesse de lecture réelle de
## l'AnimatedSprite2D. Dans _process (pas _physics_process, non gardé par
## is_multiplayer_authority()) : "chaque instance avance ses propres frames
## localement" (cf. sprite.play() dans _ready()), donc sprite.frame est fiable
## identiquement sur chaque pair -- y compris pour voir/entendre les pas des
## AUTRES joueurs, pas seulement le sien.
var _footstep_last_frame: int = -1
## Phase 9.3 : vrai une fois l'anim death-* terminée -- gate _process_spectating()
## pour que la caméra reste sur le corps le temps de l'anim au lieu de sauter
## instantanément sur un coéquipier (cf. _on_died).
var _death_animation_done: bool = false
## Vrai uniquement dans le donjon (activé par game.gd via
## enable_dungeon_camera_mode(), cf. _spawn_player) -- le Hub (hub.gd) est une
## scène à part, sans grille de salles Room.ROOM_WIDTH_PX/HEIGHT_PX, donc le
## zoom/clamp caméra basé sur cette grille ne doit jamais s'y appliquer.
var _dungeon_camera_mode: bool = false

func _ready() -> void:
	super()
	add_to_group("Players")
	# Option "Éclairage dynamique" (retour utilisateur) : cf. game.gd pour le
	# pendant CanvasModulate -- purement visuel/local, chaque pair applique
	# indépendamment son propre réglage sur sa propre instance du joueur (pas
	# de sens à répliquer "ma torche est éteinte" aux autres pairs). Pas de
	# garde is_multiplayer_authority() volontairement : mon réglage local
	# s'applique à TOUTE torche affichée sur MON écran, y compris celle des
	# coéquipiers -- si je désactive l'éclairage, je ne veux voir aucune
	# torche, pas seulement la mienne. Connecté au signal (pas juste lu une
	# fois) : re-basculable en cours de partie depuis le menu pause, cf.
	# Settings.dynamic_lighting_changed.
	_light.visible = Settings.dynamic_lighting
	Settings.dynamic_lighting_changed.connect(func(enabled: bool) -> void: _light.visible = enabled)
	damage_timer.wait_time = invulnerability_duration
	weapon.projectile_requested.connect(_on_projectile_requested)
	died.connect(_on_died)
	health_changed.connect(_on_health_changed)
	# Doit tourner sur TOUS les pairs (pas seulement l'autorité) : seul le nom
	# de l'animation est répliqué (Sprite2D:animation), pas l'index de frame --
	# chaque instance doit faire avancer les frames de sa propre marche
	# localement, sinon un pair distant verrait un cycle de marche figé sur sa
	# frame 0 (l'anim Idle n'a qu'1 frame, donc ce bug ne s'y voyait pas).
	sprite.play()
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	# Corrige un figeage constaté chez les pairs distants : "Sprite2D:animation"
	# ne réplique que le NOM de l'anim (cf. SceneReplicationConfig), pas l'état
	# playing du AnimatedSprite2D. Or playing repasse à false localement, sur
	# CHAQUE pair, dès qu'une anim non bouclée se termine (attack-*/hit-*/
	# death-*) -- ces trois-là relancent bien play() partout (RPC dédiée ou
	# call_local), mais walk-*/idle-* ne comptent que sur la synchro passive :
	# une simple assignation de propriété ne relance pas la lecture si playing
	# était déjà à false. Sans ce hook, un pair distant qui a tapé/encaissé/
	# est mort une fois reste figé sur la dernière frame pour tout le monde
	# sauf lui-même, même si le NOM d'anim continue bien à se mettre à jour.
	sprite.animation_changed.connect(_on_sprite_animation_changed)
	if is_multiplayer_authority():
		player_camera.enabled = true
		get_viewport().size_changed.connect(_on_viewport_size_changed)
		var hud = hud_scene.instantiate()
		health_changed.connect(hud.get_node("VBoxBar").get_node("LifeBar")._on_heal_changed)
		var mixture_bar = hud.get_node("VBoxBar").get_node("MixtureBar")
		weapon.ammo_changed.connect(mixture_bar._on_ammo_changed)
		mixture_bar._on_ammo_changed(weapon.mixture_max_capacity, weapon.current_mixture_ammo)
		instance_hud.emit(hud)
		var inventory_screen_instance = inventory_screen_scene.instantiate()
		add_child(inventory_screen_instance)
		inventory_screen_instance.bind_inventory(inventory)
		inventory_screen_instance.bind_weapon(weapon)
		inventory_screen = inventory_screen_instance
		var alchemy_crafting = alchemy_crafting_scene.instantiate()
		add_child(alchemy_crafting)
		alchemy_crafting.bind_inventory(inventory)
		alchemy_crafting_screen = alchemy_crafting
		var weapon_crafting = weapon_crafting_scene.instantiate()
		add_child(weapon_crafting)
		weapon_crafting.bind_inventory(inventory)
		weapon_crafting_screen = weapon_crafting
		var unlock = unlock_screen_scene.instantiate()
		add_child(unlock)
		unlock_screen = unlock
		add_child(pause_menu_scene.instantiate())
	else:
		player_camera.enabled = false

## Appelée par game.gd après avoir positionné le joueur dans le donjon (cf.
## _spawn_player) -- jamais par hub.gd. Active le zoom/clamp caméra basé sur
## la grille de salles, avec un calcul immédiat pour la position de spawn.
## _spawn_player est la spawn_function du MultiplayerSpawner du joueur : à cet
## instant précis le noeud n'est PAS encore dans l'arbre (le MultiplayerSpawner
## fait l'add_child juste après, pas avant) -- is_multiplayer_authority() a
## besoin d'être dans l'arbre pour répondre correctement, d'où le report en
## call_deferred le temps que l'add_child ait eu lieu (même classe de piège
## que le add_child-avant-setup() documenté ailleurs dans le projet).
func enable_dungeon_camera_mode() -> void:
	_dungeon_camera_mode = true
	if not is_inside_tree():
		call_deferred("enable_dungeon_camera_mode")
		return
	if not is_multiplayer_authority():
		return
	_update_camera_zoom()
	_update_camera_room_limits(global_position)

func _on_viewport_size_changed() -> void:
	if _dungeon_camera_mode:
		_update_camera_zoom()

func _process(_delta: float) -> void:
	if is_dead:
		return
	if not sprite.animation.begins_with("walk-"):
		_footstep_last_frame = -1
		return
	var current_frame: int = sprite.frame
	if current_frame == _footstep_last_frame:
		return
	_footstep_last_frame = current_frame
	var frame_count: int = sprite.sprite_frames.get_frame_count(sprite.animation)
	if current_frame == 0 or current_frame == frame_count / 2:
		AudioManager.play_sfx(RunManager.footstep_key_for_floor(RunManager.current_floor))

func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if is_dead:
		# Caméra figée sur le corps tant que death-* joue (cf. _on_died) --
		# _process_spectating() ne prend la main qu'une fois l'anim terminée.
		if _death_animation_done:
			_process_spectating()
		return
	var aim_direction = _get_aim_direction()
	var input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var facing_direction = _get_facing_direction(aim_direction, input_direction)
	_update_facing(facing_direction, input_direction.length() > 0.0)
	var water_pressed = Input.is_action_pressed("fire_water")
	var mixture_pressed = Input.is_action_pressed("fire_mixture")
	var fire_type := ""
	# Retour utilisateur : aucun tir (ni son animation) tant qu'une interface
	# (inventaire, crafting, déblocage) est ouverte -- fire_type reste "",
	# donc _try_play_attack_animation() sort tôt et request_fire() n'est
	# jamais programmé (cf. _on_sprite_animation_finished).
	if not _is_ui_open():
		if water_pressed and not mixture_pressed:
			fire_type = "water"
		elif mixture_pressed and not water_pressed:
			fire_type = "mixture"
		elif water_pressed and mixture_pressed:
			if was_water_pressed:
				fire_type = "water"
			elif was_mixture_pressed:
				fire_type = "mixture"
			else:
				fire_type = "water"
	_try_play_attack_animation(aim_direction, fire_type)
	was_water_pressed = water_pressed
	was_mixture_pressed = mixture_pressed
	move(input_direction, speed)
	if _dungeon_camera_mode:
		_update_camera_room_limits(global_position)

@rpc("any_peer", "call_local", "reliable")
func request_fire(fire_type: String, direction: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != int(name):
		return
	if fire_type == "water":
		weapon.try_fire_water(direction)
	else:
		weapon.try_fire_mixture(direction)

func _get_aim_direction() -> Vector2:
	var now = Time.get_ticks_msec() / 1000.0
	var stick_input = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick_input.length() > 0.0:
		last_stick_activity_time = now
	var current_mouse_screen_position = get_viewport().get_mouse_position()
	if not mouse_position_initialized:
		last_mouse_screen_position = current_mouse_screen_position
		mouse_position_initialized = true
	elif current_mouse_screen_position != last_mouse_screen_position:
		last_mouse_activity_time = now
		last_mouse_screen_position = current_mouse_screen_position
	if last_stick_activity_time > last_mouse_activity_time:
		if stick_input.length() > 0.0:
			last_aim_direction = stick_input.normalized()
	else:
		var mouse_delta = get_global_mouse_position() - global_position
		if mouse_delta.length() > 0.0:
			last_aim_direction = mouse_delta.normalized()
	return last_aim_direction

## Oriente le sprite vers la direction de marche par défaut, mais laisse la
## visée (souris/stick) reprendre la main dès qu'elle est plus récemment
## active que le déplacement -- même pattern d'arbitrage par timestamp que
## _get_aim_direction() pour stick vs souris. Le tir continue lui d'utiliser
## aim_direction directement (non affecté par cette fonction).
func _get_facing_direction(aim_direction: Vector2, input_direction: Vector2) -> Vector2:
	var now = Time.get_ticks_msec() / 1000.0
	if input_direction.length() > 0.0:
		last_movement_activity_time = now
	var aim_activity_time = max(last_stick_activity_time, last_mouse_activity_time)
	if last_movement_activity_time >= aim_activity_time and input_direction.length() > 0.0:
		return input_direction.normalized()
	return aim_direction

## Phase 9.3 : ne tourne que côté instance locale (autorité), comme le reste
## de _physics_process -- mais le résultat (sprite.animation) est répliqué
## aux autres pairs via le MultiplayerSynchronizer de la scène (propriété
## "Sprite2D:animation", même mécanisme que la position), donc les autres
## joueurs voient bien l'orientation, pas seulement le joueur local.
func _update_facing(direction: Vector2, is_moving: bool) -> void:
	# Ne pas couper une animation d'attaque ou de hit en cours (cf.
	# _try_play_attack_animation / _on_health_changed) : sinon la reprise du
	# mouvement l'écrase dès la frame suivante (constaté en jeu).
	if (sprite.animation.begins_with("attack") or sprite.animation.begins_with("hit")) and sprite.is_playing():
		return
	if direction.length() < 0.001:
		return
	var prefix := "walk-" if is_moving else "idle-"
	var anim_name := StringName(prefix + FacingDirection.label_for(direction))
	if sprite.animation != anim_name:
		sprite.play(anim_name)

## Rejoue le swing tant que le tir est maintenu : ne redémarre que quand le
## cycle précédent est terminé (sprite.is_playing() == false, animation non
## bouclée), sinon un appel par frame sur is_action_pressed couperait
## l'animation en boucle dès la 2e frame. Le tir réel (request_fire) n'est
## plus envoyé ici : il est différé jusqu'à la fin du swing (cf.
## _on_sprite_animation_finished), pour que le projectile parte après
## l'animation plutôt qu'au moment de l'appui.
##
## L'anim est jouée localement tout de suite (réactivité), ET diffusée par RPC
## explicite à tous les pairs (_rpc_play_attack_animation) plutôt que de
## compter uniquement sur le sync passif de "Sprite2D:animation" du
## MultiplayerSynchronizer (utilisé pour walk/idle) : ce sync est un simple
## mirroring de propriété, pas garanti de capturer un état transitoire d'à
## peine 0.6s (un seul tick de retard ou de coalescing suffit à le manquer),
## contrairement à un déplacement continu. Constaté en jeu : le swing de
## l'hôte restait invisible chez les clients alors que la marche répliquait
## normalement.
## Vrai si une interface plein écran (inventaire, crafting arme/alchimie,
## déblocage) est actuellement ouverte pour ce joueur -- utilisé pour couper
## le tir en amont plutôt que de patcher chaque écran séparément.
func _is_ui_open() -> bool:
	if inventory_screen and inventory_screen.is_open():
		return true
	if alchemy_crafting_screen and alchemy_crafting_screen.is_open():
		return true
	if weapon_crafting_screen and weapon_crafting_screen.is_open():
		return true
	if unlock_screen and unlock_screen.is_open():
		return true
	return false

func _try_play_attack_animation(direction: Vector2, fire_type: String) -> void:
	if fire_type == "" or direction.length() < 0.001:
		return
	if sprite.animation.begins_with("attack") and sprite.is_playing():
		return
	_pending_fire_type = fire_type
	_pending_fire_direction = direction
	var anim_name := "attack-" + FacingDirection.label_for(direction)
	sprite.play(StringName(anim_name))
	_rpc_play_attack_animation.rpc(anim_name)

## Reçu uniquement par les pairs distants (l'autorité s'est déjà joué l'anim
## localement dans _try_play_attack_animation, pas de call_local ici pour
## éviter un redémarrage redondant de sa propre animation).
@rpc("authority", "call_remote", "reliable")
func _rpc_play_attack_animation(anim_name: String) -> void:
	sprite.play(StringName(anim_name))

## Déclenche le tir une fois le swing terminé (direction/type figés au lancement
## de l'animation, cf. _try_play_attack_animation) -- même si le bouton a été
## relâché entre-temps, le swing engagé va jusqu'au bout et tire. Les cycles
## walk/idle (loop=true) réémettent aussi animation_finished à chaque boucle,
## d'où le filtre sur le préfixe "attack".
func _on_sprite_animation_finished() -> void:
	if not sprite.animation.begins_with("attack"):
		return
	if _pending_fire_type == "":
		return
	# SFX joué ici (pas dans weapon.gd, hôte-only) car cette fonction tourne
	# identiquement sur tous les pairs -- même raisonnement que le swing
	# d'attaque (cf. commentaire de _try_play_attack_animation). Réservoir
	# vide détecté localement via can_fire_mixture_locally() (ammo répliqué,
	# contrairement au cooldown) plutôt que d'attendre un retour de l'hôte.
	if _pending_fire_type == "mixture" and not weapon.can_fire_mixture_locally():
		AudioManager.play_sfx("weapon_empty")
	else:
		AudioManager.play_sfx("fire_water" if _pending_fire_type == "water" else "fire_mixture")
	request_fire.rpc_id(1, _pending_fire_type, _pending_fire_direction)
	_pending_fire_type = ""

## Cf. commentaire sur la connexion dans _ready() : ne concerne que les pairs
## distants -- l'autorité relance déjà play() elle-même à chaque changement de
## nom d'anim (_update_facing), donc ce hook y serait redondant.
func _on_sprite_animation_changed() -> void:
	if is_multiplayer_authority():
		return
	sprite.play()

func open_alchemy_crafting() -> void:
	if alchemy_crafting_screen:
		alchemy_crafting_screen.toggle()

## Retour utilisateur : l'écran d'alchimie se ferme tout seul en s'éloignant
## de la table (cf. AlchemyStation._on_player_left, via Interactable.player_left).
func close_alchemy_crafting() -> void:
	if alchemy_crafting_screen:
		alchemy_crafting_screen.close()

func open_weapon_crafting() -> void:
	if weapon_crafting_screen:
		weapon_crafting_screen.toggle()

## Retour utilisateur : l'écran d'arme se ferme tout seul en s'éloignant
## de la table (cf. WeaponStation._on_player_left, via Interactable.player_left).
func close_weapon_crafting() -> void:
	if weapon_crafting_screen:
		weapon_crafting_screen.close()

func open_unlock_screen() -> void:
	if unlock_screen:
		unlock_screen.toggle()

@rpc("any_peer", "call_local", "reliable")
func request_equip_weapon_part(part_path: String) -> void:
	# Même garde que request_craft_mixture : seul l'hôte valide, et seulement
	# pour le joueur qui a réellement envoyé la requête (anti-usurpation).
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != int(name):
		return

	var owned: bool = false
	for part in inventory.weapon_parts:
		if part.resource_path == part_path:
			owned = true
			break
	if not owned:
		return # désync UI/inventaire : on ignore plutôt que d'équiper une pièce non possédée

	weapon.equip_networked(load(part_path))

## Retour utilisateur : rendre l'alchimie rare et marquante -- un craft ne
## peut plus mélanger un nombre arbitraire d'ingrédients d'un coup (cf.
## alchemy_crafting.gd, qui applique déjà ce plafond côté UI ; revérifié ici
## côté hôte, seul point d'autorité).
const MAX_INGREDIENTS_PER_CRAFT: int = 3

@rpc("any_peer", "call_local", "reliable")
func request_craft_mixture(ingredient_paths: Array[String]) -> void:
	# Même garde que request_fire : seul l'hôte résout, et seulement pour
	# le joueur qui a réellement envoyé la requête (anti-usurpation).
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != int(name):
		return
	if ingredient_paths.is_empty():
		return
	if ingredient_paths.size() > MAX_INGREDIENTS_PER_CRAFT:
		return
	if RunManager.has_used_alchemy(sender_id):
		return # ce joueur a déjà utilisé la table sur cet étage (désync UI possible, cf. AlchemyStation)

	# On compte d'abord tout ce qu'il faut et on vérifie le stock AVANT de
	# retirer quoi que ce soit : un retrait partiel suivi d'un échec plus
	# loin consommerait des ingrédients sans produire de mixture (perte
	# silencieuse pour le joueur). L'opération doit rester atomique.
	var required_counts: Dictionary = {} # String (resource_path) -> int
	for path in ingredient_paths:
		required_counts[path] = required_counts.get(path, 0) + 1

	for path in required_counts.keys():
		var ingredient: Ingredient = load(path) as Ingredient
		if ingredient == null:
			push_error("request_craft_mixture: ingrédient introuvable: %s" % path)
			return
		if inventory.get_ingredient_count(ingredient) < required_counts[path]:
			return # stock insuffisant (désync UI/inventaire) : on abandonne sans rien consommer

	for path in required_counts.keys():
		inventory.remove_ingredient(load(path) as Ingredient, required_counts[path])

	# La mixture chargée ACCUMULE au lieu de se remplacer à chaque craft
	# (retour utilisateur, esprit "Rounds") : les ingrédients déjà présents
	# dans weapon.mixture_ingredient_paths (crafts précédents, toujours
	# chargés puisqu'aucun tir/mort n'a eu lieu entre-temps) sont rejoués aux
	# côtés des nouveaux avant résolution -- AlchemyResolver additionne déjà
	# degats/duree/zone par TypeAlchimie pour plusieurs ingrédients d'un seul
	# coup, donc la même logique s'étend naturellement à travers plusieurs
	# crafts successifs sans rien dupliquer. Seule la mort (nouveau Player/
	# Weapon recréés, cf. PlayerManager.spawnPlayer) remet mixture_ingredient_paths
	# à vide.
	var combined_ingredient_paths: Array[String] = weapon.mixture_ingredient_paths.duplicate()
	combined_ingredient_paths.append_array(ingredient_paths)

	var full_recipe: Array[Ingredient] = []
	for path in combined_ingredient_paths:
		full_recipe.append(load(path) as Ingredient)

	# Résolution et conversion en effet : appelées uniquement depuis ce
	# chemin autoritaire côté hôte (cf. architecture_reseau.md, 4.2).
	var mixture: Mixture = AlchemyResolver.resoudre(full_recipe)
	var effect: ImpactEffect = MixtureToEffect.convertir(mixture)
	weapon.mixture_impact_effect = effect
	weapon.set_mixture_ingredients_networked(combined_ingredient_paths)
	RunManager.mark_alchemy_used(sender_id)
	print("Mixture appliquée pour %s: %s" % [name, effect])

func _on_projectile_requested(data: Dictionary) -> void:
	instance_projectile.emit(data)

func _on_damage_timer_timeout() -> void:
	can_take_damage = true

func _start_invulnerability() -> void:
	can_take_damage = false
	damage_timer.start()

@rpc("any_peer", "call_local", "reliable")
func teleport(new_position: Vector2) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	position = new_position

func kill() -> void:
	pass

## Tourne sur tous les pairs (died vient de Character._update_health,
## call_local RPC déjà répliqué identiquement partout). La désactivation de
## collision reste immédiate (plus aucune interaction physique dès la mort),
## mais le visuel (sprite caché, bascule spectateur) attend la fin de
## death-* pour laisser le joueur voir sa propre mort plutôt que de sauter
## instantanément sur un coéquipier.
func _on_died() -> void:
	collision_shape.set_deferred("disabled", true)
	sprite.play(StringName("death-" + FacingDirection.label_for(last_aim_direction)))
	await sprite.animation_finished
	if not is_instance_valid(self):
		return
	sprite.visible = false
	_death_animation_done = true
	if is_multiplayer_authority():
		_show_spectator_label()
		_pick_spectate_target()
		player_camera.position_smoothing_enabled = true
		player_camera.position_smoothing_speed = 2.5

## Réaction visuelle à un coup non-létal (Phase 9.3). hp<=0 est géré par
## _on_died via le signal died (émis juste après health_changed dans
## Character._update_health) -- pas de jouer un hit qui serait de toute façon
## immédiatement écrasé par l'anim de mort.
func _on_health_changed(_max_lifepoint: float, lifepoint: float) -> void:
	if lifepoint <= 0:
		return
	if sprite.animation.begins_with("attack"):
		return
	sprite.play(StringName("hit-" + FacingDirection.label_for(last_aim_direction)))

## Le projet n'impose aucune résolution/stretch fixe (cf. project.godot) : la
## taille du viewport suit donc la fenêtre réelle du joueur. Un zoom fixe
## calculé pour une résolution de référence laisserait voir au-delà de la
## salle sur un écran plus large -- on recalcule ici le zoom pour que la zone
## visible tienne toujours dans les dimensions d'une salle, quelle que soit
## la taille de fenêtre (rappelée à chaque redimensionnement, cf.
## _on_viewport_size_changed()). N'est jamais appelée hors donjon (cf.
## _dungeon_camera_mode).
func _update_camera_zoom() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var zoom_x: float = viewport_size.x / float(Room.ROOM_WIDTH_PX)
	var zoom_y: float = viewport_size.y / float(Room.ROOM_HEIGHT_PX)
	var target_zoom: float = max(zoom_x, zoom_y) * CAMERA_ZOOM_MARGIN
	player_camera.zoom = Vector2(target_zoom, target_zoom)

## Empêche la caméra de montrer au-delà de la salle courante (couloir/salle
## voisine visible par une porte ouverte) : les salles sont juxtaposées sans
## marge dans la grille du donjon (cf. game.gd::ROOM_CELL_SIZE, identique à
## Room.ROOM_WIDTH_PX/HEIGHT_PX), donc une simple division entière de la
## position retrouve la salle qui contient reference_position.
func _update_camera_room_limits(reference_position: Vector2) -> void:
	var room_col := floori(reference_position.x / Room.ROOM_WIDTH_PX)
	var room_row := floori(reference_position.y / Room.ROOM_HEIGHT_PX)
	player_camera.limit_left = room_col * Room.ROOM_WIDTH_PX
	player_camera.limit_top = room_row * Room.ROOM_HEIGHT_PX
	player_camera.limit_right = (room_col + 1) * Room.ROOM_WIDTH_PX
	player_camera.limit_bottom = (room_row + 1) * Room.ROOM_HEIGHT_PX

func _process_spectating() -> void:
	if Input.is_action_just_pressed("spectate_next"):
		_pick_spectate_target(true)
	elif not is_instance_valid(_spectate_target) or _spectate_target.is_dead:
		_pick_spectate_target()
	if is_instance_valid(_spectate_target):
		player_camera.global_position = _spectate_target.global_position
		if _dungeon_camera_mode:
			_update_camera_room_limits(_spectate_target.global_position)

func _pick_spectate_target(cycle: bool = false) -> void:
	var candidates: Array = []
	for p in get_tree().get_nodes_in_group("Players"):
		if p != self and not p.is_dead:
			candidates.append(p)
	if candidates.is_empty():
		_spectate_target = null
		return
	if not cycle or _spectate_target == null or not candidates.has(_spectate_target):
		_spectate_target = candidates[0]
		return
	var current_index: int = candidates.find(_spectate_target)
	_spectate_target = candidates[(current_index + 1) % candidates.size()]

func _show_spectator_label() -> void:
	var label := Label.new()
	label.text = "Vous êtes mort — Espace pour changer de vue"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.position.y = 40
	label.size.x = 400
	label.position.x -= 200
	var layer := CanvasLayer.new()
	layer.add_child(label)
	add_child(layer)
