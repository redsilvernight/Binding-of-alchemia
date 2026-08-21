extends Room
## Scène hub (Phase 8.1) : écran "hors run", chargé quand tous les joueurs
## meurent (cf. game.gd._check_all_players_dead / RunManager.end_run) et
## point de départ d'une nouvelle run via RunStartStation. Spawn minimal des
## joueurs, réutilise PlayerManager.spawnPlayer comme game.gd — pas de
## donjon, d'ennemis ni de pickups ici, ces systèmes restent propres à
## game.gd.
##
## Style "boutique" (rework visuel) : hérite de Room pour réutiliser tel
## quel le pipeline sol/murs en tuiles Wang (_paint_floor/_paint_walls,
## cf. room.gd) au lieu de dupliquer cette logique -- le hub est une salle
## fixe, jamais générée procéduralement, donc set_open_sides([]) est appelé
## une seule fois ici avec AUCUN côté ouvert (murs pleins sur tout le
## pourtour, pas d'embrasure de porte) : contrairement aux salles de donjon,
## le hub n'est connecté à aucune salle voisine. Le tileset
## (hub_shop_terrain.tres) est assigné statiquement dans hub.tscn plutôt que
## via set_floor_tileset(), même convention que les salles spéciales fixes
## (room_weapon.tscn, room_alchemy.tscn) qui ne changent jamais de pool.
## Tout le reste hérité de Room (RoomTrigger, verrouillage, navigation) est
## inerte ici : aucun ennemi n'est jamais enregistré dans ce hub.
##
## Retour utilisateur (2e passe) : (1) le tileset "meuble" de la 1re passe
## lisait comme un mur (motif répété sur toute la paroi) -- régénéré en
## planches unies, même sol qu'avant via lower_base_tile_id pour ne pas y
## retoucher. (2) l'ancien tileset "meuble" n'est pas jeté : réutilisé tel
## quel comme prop d'étagère AGRANDI (128x176, cf. SHOP_SHELF_TEXTURE),
## posé en Sprite2D autonome comme les autres meubles du projet
## (RunStartStation/UnlockStation/WeaponStation) plutôt qu'en tuile répétée.
## (3) les lanternes suivent maintenant EXACTEMENT le pipeline WallLight du
## donjon (cf. Phase 11.6, room.gd::_setup_wall_light()) au lieu d'un
## Sprite2D+PointLight2D posés à la main : la tuile de lanterne est peinte
## sur PropsDecor via set_decor_props(), et set_wall_light() reçoit LES
## MÊMES cellules -- Room positionne alors le PointLight2D pile au centre
## de chaque tuile, sans calcul de position manuel. Vue "side" (pas "low
## top-down") pour la lanterne, même correction que le torche de donjon
## (cf. mémoire Phase 11.6) : une lanterne murale vue de dessus ne se lit
## pas comme montée sur le mur. (4) assombrissement ambiant ajouté
## (CanvasModulate + AmbientLight, cf. game.tscn/game.gd) -- sans lui un
## PointLight2D nu dans une pièce déjà pleinement éclairée ne se voit
## presque pas ; teinte plus chaude/claire que le donjon (boutique cosy,
## pas un donjon sombre).

@onready var players: Node2D = $Players
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var HUD: Node2D = $HUD
@onready var _canvas_modulate: CanvasModulate = $CanvasModulate
@onready var _ambient_light: DirectionalLight2D = $AmbientLight
@onready var _run_start_station: Node2D = $RunStartStation

## Couleur chaude façon vitrine de boutique éclairée (cf. WallLight,
## scripts/props/wall_light.gd) -- même mécanisme que les torches de donjon.
const SHOP_LIGHT_COLOR: Color = Color(1.0, 0.78, 0.45)
## Tuile de lanterne : source_id 1 de hub_shop_terrain.tres. Peinte sur le
## mur du fond (row 0, cf. Room._paint_walls), aux colonnes les plus proches
## des deux stations (x=450/900 -> col ~7/~14 à 64px la tuile) pour qu'elles
## flanquent RunStartStation/UnlockStation comme deux appliques au-dessus
## d'un comptoir.
const SHOP_LANTERN_SOURCE_ID: int = 1
const SHOP_LANTERN_ROW: int = 0
const SHOP_LANTERN_COLS: Array[int] = [7, 14]

## Étagères : Sprite2D autonome (comme les autres meubles du hub), pas une
## tuile -- l'asset (128x176) est trop grand et non-répétable pour un décor
## en tuile. x=128/1216 = juste à l'intérieur des murs est/ouest (murs
## larges d'une tuile, 64px, + moitié de la largeur du sprite) pour rester
## flush contre la paroi sans la chevaucher.
const SHOP_SHELF_TEXTURE: Texture2D = preload("res://assets/tiles/hub_shop_shelf.png")
const SHOP_SHELF_POSITIONS: Array[Vector2] = [
	Vector2(128, 300), Vector2(128, 620),
	Vector2(1216, 300), Vector2(1216, 620),
]
## Collision + ombre portée, exactement comme les props bloquants du donjon
## (caisses/piliers/gravats, cf. _setup_props_blocking_layer() -- même
## layer 8 depuis la migration en tuiles de la Phase 11.5, "tous les masques
## consommateurs incluaient déjà 8 ET 64 ensemble"). Contrairement à ces
## props-là, l'étagère n'est pas une tuile (asset 128x176, non répétable) :
## StaticBody2D + CollisionShape2D + LightOccluder2D posés à la main plutôt
## qu'un physics_layer_0/occlusion_layer_0 sur une TileSetAtlasSource,
## mais même résultat (bloque le joueur, projette une ombre). Rectangle un
## peu plus petit que le sprite (110x160 sur 128x176) pour ne pas déborder
## visuellement sur les tuiles voisines.
const SHOP_SHELF_FOOTPRINT_SIZE: Vector2 = Vector2(110, 160)

## Objets physiques posés sur les étagères (retour utilisateur : "les items
## posés un peu au hasard sur les étagères... c'est en s'approchant d'eux
## que l'on peut interagir avec eux et les acheter"), un par entrée du pool
## LOCAL du joueur (cf. ShopItemProp, scripts/world/shop_item_prop.gd) --
## achat direct par proximité, en plus (pas à la place) du grand écran de
## la table déjà en place au comptoir (UnlockStation, inchangé). Purement
## local à chaque pair, comme MetaProgression elle-même : deux coéquipiers
## voient chacun LEURS PROPRES objets sur les mêmes étagères.
var _shop_item_props: Array[Node2D] = []
## Retour utilisateur (2e passe) : la rangée basse tombait dans le placard
## en bois du pied de l'étagère, pas dans un renfoncement -- repéré cette
## fois en échantillonnant hub_shop_shelf.png pixel par pixel (comptage
## fond sombre vs bois par ligne) plutôt qu'en estimant à l'oeil : les 3
## VRAIS renfoncements sombres du sprite (128x176, pivot centré) sont
## centrés vers y=-58 (rangée de bouteilles du haut), y=-16 (rangée de
## boîtes) et y=+6 (rangée basse) -- tout ce qui suit (y>+20) est le
## placard en bois massif, jamais une position valide. Couplé au fond de
## masquage de ShopItemProp (cf. shop_item_prop.gd), l'alignement pixel-
## parfait avec le décor peint importe moins : le fond cache ce qu'il y a
## dessous quel que soit l'objet du sprite à cet endroit.
## Retour utilisateur (4e passe) : la rangée du milieu (paquets/boîtes)
## s'est révélée trop étroite (~16px de haut, mesurée pixel par pixel dans
## hub_shop_shelf.png) pour n'importe quel fond qui reste lisible -- son
## fond débordait sur la rangée du dessous à l'écran. Abandonnée
## complètement plutôt que rétrécie encore : il ne reste que les deux
## rangées de bouteilles (haute ~32px, basse ~16-20px), toutes deux
## couplées au BACKDROP_SIZE réduit (cf. shop_item_prop.gd) pour tenir dans
## la plus étroite des deux sans déborder sur le voisinage peint.
## Retour utilisateur (5e passe) : les objets "lévitaient" au-dessus de la
## ligne des bouteilles peintes -- une icône centrée (pas une bouteille
## avec son col en haut et sa base en bas) lue à la même hauteur Y qu'une
## bouteille voisine paraît plus haute que sa base réelle. Descendues de
## ~8px sur les deux rangées pour que leur bas visuel retombe au niveau du
## pied des bouteilles plutôt qu'au niveau de leur milieu/col.
const SHOP_ITEM_SLOTS: Array[Vector2] = [
	Vector2(-28, -42), Vector2(-2, -42), Vector2(24, -42),
	Vector2(-30, 11), Vector2(0, 11), Vector2(26, 11),
]

## Portail (retour utilisateur : "améliore le portail") -- le sprite
## d'origine (Phase 8.1, dais+arche discrète) est régénéré en arche de
## pierre imposante avec un cercle de transmutation au sol, seule exception
## déjà actée à la règle "pas de glow sur l'équipement statique" (cf.
## roadmap_status). Couleur violet-teal délibérément DIFFÉRENTE du
## SHOP_LIGHT_COLOR ambré des lanternes -- contraste voulu, un portail
## magique ne doit pas se confondre avec l'éclairage chaleureux du reste de
## la boutique. Réutilise WallLight (générique : couleur + scintillement,
## déjà utilisé pour 2 contextes différents -- torches de donjon, lanternes
## de la boutique) plutôt qu'un 3e système dédié.
const PORTAL_LIGHT_COLOR: Color = Color(0.55, 0.45, 0.95)
const PORTAL_LIGHT_OFFSET: Vector2 = Vector2(0, 80)


func _ready() -> void:
	_setup_shop_wall_lights()
	super._ready()
	set_open_sides([])
	_setup_shop_shelves()
	_setup_portal_glow()
	_setup_ambient_lighting()
	AudioManager.play_music("hub") # local à chaque pair, comme game.gd
	NetworkManager.multiplayer.peer_connected.connect(_on_peer_connected)
	player_spawner.spawn_function = _spawn_player
	# Connectés AVANT tout appel à ensure_shop_pool()/le reste de _ready() :
	# ce dernier peut émettre shop_pool_changed de façon SYNCHRONE pour
	# l'hôte lui-même (cf. MetaProgression._notify_shop_pool), donc la
	# connexion doit déjà exister pour ne pas rater ce premier signal.
	MetaProgression.shop_pool_changed.connect(_setup_shop_items)
	MetaProgression.unlocks_changed.connect(_setup_shop_items)
	if multiplayer.is_server():
		player_spawner.spawn(NetworkManager.get_unique_id())
		# Rattrapage identique à _on_peer_connected ci-dessous, pour l'hôte
		# lui-même ET tout pair déjà connecté avant que ce hub charge (retour
		# hub après une run) -- n'écrase jamais un pool déjà tiré (cf.
		# ensure_shop_pool(), pas reroll_shop_pool_for_all() ici : seul
		# RunManager.request_start_run doit renouveler la vitrine).
		MetaProgression.ensure_shop_pool(NetworkManager.get_unique_id())
		for peer_id in NetworkManager.get_peers():
			player_spawner.spawn(peer_id)
			MetaProgression.ensure_shop_pool(peer_id)
			MetaProgression._rpc_shop_pool.rpc_id(peer_id, MetaProgression.get_shop_pool(peer_id))
		# Phase 9 (loader) : cf. RunManager.hide_loading_screen.
		RunManager.hide_loading_screen()
	# Appel explicite en plus des connexions ci-dessus : couvre le cas où
	# ensure_shop_pool() n'émet RIEN parce que ce pair avait déjà un pool
	# (retour au hub après une run précédente dans la même session) --
	# shop_pool_changed ne rejoue alors jamais tout seul. Sans effet pour un
	# client dont le pool n'est pas encore arrivé (pool vide -> aucun objet
	# affiché tant que le rattrapage RPC ne déclenche pas un rebuild).
	_setup_shop_items()


func _spawn_player(id: int) -> Node:
	var player = PlayerManager.spawnPlayer(id)
	player.instance_hud.connect(_hud_instance)
	return player


func _hud_instance(hud: Node) -> void:
	HUD.add_child(hud)


func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		player_spawner.spawn(peer_id)
		# Rattrape la monnaie/les déblocages déjà acquis par ce pair (8.2) :
		# MetaProgression._notify_currency/_notify_unlock ne poussent l'état
		# qu'au moment où il change, un pair qui rejoint après coup ne les a
		# jamais reçus autrement (même piège que le rattrapage HP du boss, 7.4).
		MetaProgression._rpc_currency_changed.rpc_id(peer_id, MetaProgression.get_currency(peer_id))
		for item_path in MetaProgression.unlocked_by_peer.get(peer_id, {}).keys():
			MetaProgression._rpc_unlocked.rpc_id(peer_id, item_path)
		# Même rattrapage pour la vitrine de boutique (cf. const SHOP_POOL_SIZE,
		# meta_progression.gd) -- un pair qui rejoint en cours de partie n'a
		# jamais reçu son pool autrement.
		MetaProgression.ensure_shop_pool(peer_id)
		MetaProgression._rpc_shop_pool.rpc_id(peer_id, MetaProgression.get_shop_pool(peer_id))


## DOIT tourner avant super._ready() : _setup_props_decor_layer()/
## _setup_wall_light() (Room) consomment _pending_decor_cells/
## _pending_wall_light_cells dès que Room._ready() s'exécute -- même
## contrainte de timing que set_decor_props() pour les salles de donjon
## (cf. room.gd), l'appel se fait juste en tête de notre propre _ready()
## plutôt que depuis un spawner externe (game.gd) comme pour le donjon.
func _setup_shop_wall_lights() -> void:
	var cells: Array = []
	var source_ids: Array = []
	for col in SHOP_LANTERN_COLS:
		cells.append(Vector2i(col, SHOP_LANTERN_ROW))
		source_ids.append(SHOP_LANTERN_SOURCE_ID)
	set_decor_props(cells, source_ids)
	set_wall_light(cells, SHOP_LIGHT_COLOR)


## StaticBody2D + Sprite2D + CollisionShape2D + LightOccluder2D par étagère
## -- après super._ready() : pas de contrainte de timing ici, contrairement
## à _setup_shop_wall_lights(), ce sont des nodes ajoutés directement en
## enfants du hub. Shape/polygone construits une seule fois et réutilisés
## sur les 4 instances (Resource partageable tant qu'il n'est pas modifié
## par instance, cf. RectangleShape2D/OccluderPolygon2D).
## light_mask=2 sur le Sprite2D (pas sur le body) : même piège que
## _props_blocking (Phase 11.5, room.gd) -- sans ça l'étagère reçoit sa
## propre ombre sur son propre socle (son polygone d'occlusion l'assombrit
## lui-même), visible comme un carré sombre incohérent avec sa silhouette.
func _setup_shop_shelves() -> void:
	var collision_shape: RectangleShape2D = RectangleShape2D.new()
	collision_shape.size = SHOP_SHELF_FOOTPRINT_SIZE
	var half: Vector2 = SHOP_SHELF_FOOTPRINT_SIZE / 2.0
	var occluder_polygon: OccluderPolygon2D = OccluderPolygon2D.new()
	occluder_polygon.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])
	for pos in SHOP_SHELF_POSITIONS:
		var body: StaticBody2D = StaticBody2D.new()
		body.collision_layer = 8
		body.collision_mask = 0
		body.position = pos
		add_child(body)

		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = SHOP_SHELF_TEXTURE
		sprite.light_mask = 2
		body.add_child(sprite)

		var collision: CollisionShape2D = CollisionShape2D.new()
		collision.shape = collision_shape
		body.add_child(collision)

		var occluder: LightOccluder2D = LightOccluder2D.new()
		occluder.occluder = occluder_polygon
		body.add_child(occluder)


## Rebuild complet (pas de diff incrémental) à chaque changement de pool ou
## de déblocage -- SHOP_POOL_SIZE reste petit (3), le coût est négligeable
## et ça évite d'avoir à suivre quel item est apparu/a disparu. Une étagère
## par objet (slot choisi au hasard, cf. SHOP_ITEM_SLOTS) : ne place jamais
## deux objets sur la même étagère tant qu'il reste des étagères libres
## (4 étagères pour SHOP_POOL_SIZE=3 objets au maximum).
func _setup_shop_items() -> void:
	for prop in _shop_item_props:
		if is_instance_valid(prop):
			prop.queue_free()
	_shop_item_props.clear()

	var local_id: int = NetworkManager.get_unique_id()
	var pool: Array = MetaProgression.get_shop_pool(local_id)
	var free_shelves: Array = SHOP_SHELF_POSITIONS.duplicate()
	free_shelves.shuffle()

	for item_path in pool:
		if MetaProgression.is_unlocked(local_id, item_path) or free_shelves.is_empty():
			continue
		var entry: Dictionary = _find_unlockable_entry(item_path)
		if entry.is_empty():
			continue
		var base_pos: Vector2 = free_shelves.pop_back()
		var prop: ShopItemProp = ShopItemProp.new()
		prop.setup(entry)
		prop.position = base_pos + SHOP_ITEM_SLOTS[randi() % SHOP_ITEM_SLOTS.size()]
		add_child(prop)
		_shop_item_props.append(prop)


func _find_unlockable_entry(item_path: String) -> Dictionary:
	for entry in MetaProgression.UNLOCKABLES:
		if entry["item_path"] == item_path:
			return entry
	return {}


## Positionnée relativement à RunStartStation (pas une constante absolue,
## contrairement aux lanternes/étagères) : lit sa position réelle dans la
## scène plutôt que de dupliquer (450, 320) en dur ici, pour ne pas se
## désynchroniser si la station est repositionnée plus tard dans hub.tscn.
func _setup_portal_glow() -> void:
	var glow: WallLight = WallLight.new()
	glow.set_color(PORTAL_LIGHT_COLOR)
	glow.position = _run_start_station.position + PORTAL_LIGHT_OFFSET
	add_child(glow)


## Même mécanisme que game.gd (donjon) : CanvasModulate assombrit toute la
## scène par multiplication, AmbientLight (DirectionalLight2D,
## shadow_enabled=false, cf. game.tscn) réintroduit une teinte uniforme
## visible même dans les zones hors de la torche du joueur -- sans lui la
## teinte de CanvasModulate reste quasi noire (couleur * presque-zéro).
## Les deux suivent Settings.dynamic_lighting comme dans le donjon (et
## comme PlayerLight, cf. player.gd) : le joueur peut couper tout le
## système d'éclairage dynamique d'un coup depuis les options.
func _setup_ambient_lighting() -> void:
	_canvas_modulate.visible = Settings.dynamic_lighting
	Settings.dynamic_lighting_changed.connect(func(enabled: bool) -> void: _canvas_modulate.visible = enabled)
	_ambient_light.visible = Settings.dynamic_lighting
	Settings.dynamic_lighting_changed.connect(func(enabled: bool) -> void: _ambient_light.visible = enabled)
