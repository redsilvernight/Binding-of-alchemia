class_name ShopItemProp
extends Node2D

const INTERACT_RADIUS: float = 40.0
const ICON_SCALE: float = 0.3
const BACKDROP_COLOR: Color = Color(32.0 / 255.0, 32.0 / 255.0, 48.0 / 255.0, 1.0)
const BACKDROP_SIZE: int = 22

var item_path: String = ""
var _cost: int = 0

var _backdrop: Sprite2D = Sprite2D.new()
var _sprite: Sprite2D = Sprite2D.new()
var _interactable: Interactable = Interactable.new()

static var _backdrop_texture: ImageTexture = null


static func _get_backdrop_texture() -> ImageTexture:
	if _backdrop_texture == null:
		var img: Image = Image.create_empty(BACKDROP_SIZE, BACKDROP_SIZE, false, Image.FORMAT_RGBA8)
		img.fill(BACKDROP_COLOR)
		_backdrop_texture = ImageTexture.create_from_image(img)
	return _backdrop_texture


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
	_backdrop.texture = _get_backdrop_texture()
	add_child(_backdrop)
	add_child(_sprite)

	_interactable.interacted.connect(_on_interacted)


func _on_interacted(_player: Node2D) -> void:
	var local_id: int = NetworkManager.get_unique_id()
	if MetaProgression.is_unlocked(local_id, item_path):
		return
	if MetaProgression.get_currency(local_id) < _cost:
		AudioManager.play_sfx("ui_error")
		return
	MetaProgression.request_unlock.rpc_id(1, item_path)
