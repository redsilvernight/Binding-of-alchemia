class_name ShopItemProp
extends Node2D

const INTERACT_SIZE: Vector2 = Vector2(90, 80)
const ICON_SCALE: float = 0.3
const BACKDROP_COLOR: Color = Color(32.0 / 255.0, 32.0 / 255.0, 48.0 / 255.0, 1.0)
const BACKDROP_SIZE: int = 22
const HIGHLIGHT_COLOR: Color = Color(1.5, 1.5, 1.3)
const HIGHLIGHT_SCALE_FACTOR: float = 1.15
const HIGHLIGHT_PULSE_DURATION: float = 0.5

var item_path: String = ""
var _cost: int = 0
var _highlight_tween: Tween = null

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


func setup(entry: Dictionary, interact_offset: Vector2 = Vector2.ZERO) -> void:
	item_path = entry["item_path"]
	_cost = entry["cost"]
	var resource: Resource = load(item_path)
	if resource != null and "icon" in resource:
		_sprite.texture = resource.icon
	_sprite.scale = Vector2.ONE * ICON_SCALE
	_interactable.position = interact_offset
	_interactable.prompt_text = "Appuyer sur E pour acheter %s (%d monnaie)" % [entry["display_name"], _cost]


func _ready() -> void:
	z_index = 1
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
	var rect := RectangleShape2D.new()
	rect.size = INTERACT_SIZE
	collision.position = Vector2(0, INTERACT_SIZE.y / 2.0)
	collision.shape = rect
	_interactable.add_child(collision)

	add_child(_interactable)
	_backdrop.texture = _get_backdrop_texture()
	_backdrop.light_mask = 2
	add_child(_backdrop)
	_sprite.light_mask = 2
	add_child(_sprite)

	_interactable.interacted.connect(_on_interacted)
	_interactable.player_entered.connect(_on_player_entered)
	_interactable.player_left.connect(_on_player_left)


func _on_interacted(_player: Node2D) -> void:
	if MetaProgression.get_currency() < _cost:
		AudioManager.play_sfx("ui_error")
		return
	MetaProgression.request_unlock.rpc_id(1, item_path)


func _on_player_entered(_player: Node2D) -> void:
	if _highlight_tween:
		_highlight_tween.kill()
	_highlight_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_highlight_tween.tween_property(_sprite, "modulate", HIGHLIGHT_COLOR, HIGHLIGHT_PULSE_DURATION)
	_highlight_tween.parallel().tween_property(_sprite, "scale", Vector2.ONE * ICON_SCALE * HIGHLIGHT_SCALE_FACTOR, HIGHLIGHT_PULSE_DURATION)
	_highlight_tween.tween_property(_sprite, "modulate", Color.WHITE, HIGHLIGHT_PULSE_DURATION)
	_highlight_tween.parallel().tween_property(_sprite, "scale", Vector2.ONE * ICON_SCALE, HIGHLIGHT_PULSE_DURATION)


func _on_player_left(_player: Node2D) -> void:
	if _highlight_tween:
		_highlight_tween.kill()
		_highlight_tween = null
	_sprite.modulate = Color.WHITE
	_sprite.scale = Vector2.ONE * ICON_SCALE
