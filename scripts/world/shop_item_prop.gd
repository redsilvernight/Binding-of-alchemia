class_name ShopItemProp
extends Node2D
## Objet de boutique posé sur une étagère (retour utilisateur : "les items
## posés un peu au hasard sur les étagères... c'est en s'approchant d'eux
## que l'on peut interagir avec eux et les acheter"). Construit entièrement
## en code, pas de scène dédiée -- même choix que WallLight (cf.
## scripts/props/wall_light.gd) : retour utilisateur déjà acté ailleurs
## ("je ne veux pas de scène exclusive à un props"). Instancié par
## Hub._setup_shop_items() pour chaque entrée du pool LOCAL du joueur
## (MetaProgression.get_shop_pool) -- achat direct par interaction de
## proximité, sans passer par le grand écran de la table (UnlockScreen
## reste disponible en secours au comptoir, cf. UnlockStation, inchangé --
## ceci est un raccourci d'achat, pas un remplacement).
##
## Purement local à chaque pair, comme le pool lui-même (MetaProgression
## est déjà par-joueur) : deux coéquipiers voient chacun LEURS PROPRES
## objets sur les mêmes étagères, sans réplication -- cohérent avec le
## reste de la progression méta, qui n'a jamais été pensée pour être
## partagée visuellement.

const INTERACT_RADIUS: float = 40.0
## Retour utilisateur : les icônes (64x64, même échelle que les slots
## d'inventaire) sont bien trop grandes une fois posées sur l'étagère --
## les bouteilles peintes dans le sprite de l'étagère elle-même font à
## peine plus d'une dizaine de pixels à cette résolution. Réduites pour
## rester un petit objet posé PARMI le décor, pas plus gros que lui.
const ICON_SCALE: float = 0.3
## Retour utilisateur (2e passe) : même réduite, l'icône se superpose
## toujours mal aux bouteilles/objets déjà peints dans le sprite de
## l'étagère à cet endroit -- au lieu de chercher un alignement pixel-
## parfait avec un décor qui n'a pas été conçu pour recevoir d'objets
## dessus, on peint un petit fond plein de LA MÊME couleur que le fond
## sombre du renfoncement de l'étagère (échantillonné directement dans
## hub_shop_shelf.png) juste derrière l'icône -- ça masque proprement
## ce qu'il y avait dessous, quel que soit l'objet peint à cet endroit.
const BACKDROP_COLOR: Color = Color(32.0 / 255.0, 32.0 / 255.0, 48.0 / 255.0, 1.0)
## Retour utilisateur (4e passe) : les renfoncements sombres de l'étagère
## sont étroits (~16px de haut pour la rangée du milieu/basse, mesuré en
## comptant fond sombre vs bois ligne par ligne dans hub_shop_shelf.png) --
## un fond plus grand déborde sur la rangée peinte voisine (paquets/
## bouteilles du dessous). Réduit pour tenir dans la plus étroite des
## rangées utilisées (cf. SHOP_ITEM_SLOTS, hub.gd, qui a aussi laissé
## tomber la rangée du milieu -- la plus encombrée visuellement).
const BACKDROP_SIZE: int = 22

var item_path: String = ""
var _cost: int = 0

var _backdrop: Sprite2D = Sprite2D.new()
var _sprite: Sprite2D = Sprite2D.new()
var _interactable: Interactable = Interactable.new()

## Partagée entre toutes les instances (texture identique à chaque fois,
## cf. BACKDROP_COLOR/BACKDROP_SIZE) -- générée une seule fois plutôt qu'une
## image par objet de boutique.
static var _backdrop_texture: ImageTexture = null


static func _get_backdrop_texture() -> ImageTexture:
	if _backdrop_texture == null:
		var img: Image = Image.create_empty(BACKDROP_SIZE, BACKDROP_SIZE, false, Image.FORMAT_RGBA8)
		img.fill(BACKDROP_COLOR)
		_backdrop_texture = ImageTexture.create_from_image(img)
	return _backdrop_texture


## Doit être appelée avant l'entrée dans l'arbre (avant add_child dans
## Hub._setup_shop_items()) : prompt_text doit être en place quand
## Interactable._ready() le copie dans son PromptLabel.
func setup(entry: Dictionary) -> void:
	item_path = entry["item_path"]
	_cost = entry["cost"]
	var resource: Resource = load(item_path)
	if resource != null and "icon" in resource:
		_sprite.texture = resource.icon
	_sprite.scale = Vector2.ONE * ICON_SCALE
	_interactable.prompt_text = "Appuyer sur E pour acheter %s (%d monnaie)" % [entry["display_name"], _cost]


func _ready() -> void:
	var prompt_label := Label.new()
	prompt_label.name = "PromptLabel"
	prompt_label.position = Vector2(-110, -60)
	prompt_label.size = Vector2(220, 30)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Contour sombre, même correctif que hub.tscn (LabelSettings_prompt) :
	# CanvasModulate assombrit/teinte tout le hub, un texte blanc brut y
	# perd son contraste selon la couleur du fond derrière lui.
	var label_settings := LabelSettings.new()
	label_settings.font_size = 15
	label_settings.outline_size = 5
	label_settings.outline_color = Color(0.15, 0.1, 0.05, 1)
	prompt_label.label_settings = label_settings
	_interactable.add_child(prompt_label)

	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = INTERACT_RADIUS
	collision.shape = circle
	_interactable.add_child(collision)

	add_child(_interactable)
	# _backdrop AVANT _sprite : l'ordre du tree suffit à dessiner l'icône
	# par-dessus le cache (même z_index par défaut pour les deux, cf.
	# room.gd::_setup_props_decor_layer pour le même raisonnement).
	_backdrop.texture = _get_backdrop_texture()
	add_child(_backdrop)
	add_child(_sprite)

	_interactable.interacted.connect(_on_interacted)


## Pré-vérifications côté client avant d'envoyer la requête, même esprit que
## unlock_screen.gd::_on_unlock_pressed -- l'hôte revalide de toute façon
## (cf. MetaProgression.request_unlock), mais un retour audio immédiat sur
## un objet qu'on ne peut pas encore se payer est plus lisible qu'un
## silence total en attendant une réponse réseau qui ne viendra jamais
## (request_unlock ne notifie pas explicitement un refus, cf. son code).
func _on_interacted(_player: Node2D) -> void:
	var local_id: int = NetworkManager.get_unique_id()
	if MetaProgression.is_unlocked(local_id, item_path):
		return
	if MetaProgression.get_currency(local_id) < _cost:
		AudioManager.play_sfx("ui_error")
		return
	MetaProgression.request_unlock.rpc_id(1, item_path)
