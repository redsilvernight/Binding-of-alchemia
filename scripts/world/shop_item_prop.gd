class_name ShopItemProp
extends Node2D

const INTERACT_SIZE: Vector2 = Vector2(90, 80)
const ICON_SCALE: float = 0.3
const PROMPT_LABEL_HEIGHT: float = 30.0
const PROMPT_LABEL_GAP: float = 20.0
const PROMPT_LABEL_Y_OFFSET: float = -15.0
const HIGHLIGHT_COLOR: Color = Color(1.5, 1.5, 1.3)
const HIGHLIGHT_SCALE_FACTOR: float = 1.15
const HIGHLIGHT_PULSE_DURATION: float = 0.5

const SHELF_TEXTURE: Texture2D = preload("res://assets/tiles/hub_shop_shelf.png")
const BACKDROP_SEARCH_RADIUS: Vector2i = Vector2i(14, 16)
const BACKDROP_COLOR_THRESHOLD: float = 60.0 / 255.0
const BACKDROP_PADDING: float = 3.0
const BACKDROP_FEATHER: float = 3.0
const BACKDROP_LIFT: float = 4.0
const BACKDROP_BOTTOM_EXTRA: float = 3.0

var item_path: String = ""
var _cost: int = 0
var _highlight_tween: Tween = null
var _slot_offset: Vector2 = Vector2.ZERO

var _backdrop: Sprite2D = Sprite2D.new()
var _sprite: Sprite2D = Sprite2D.new()
var _interactable: Interactable = Interactable.new()

static var _shelf_image: Image = null


static func _get_shelf_image() -> Image:
	if _shelf_image == null:
		_shelf_image = SHELF_TEXTURE.get_image()
	return _shelf_image


func setup(entry: Dictionary, interact_offset: Vector2 = Vector2.ZERO, slot_offset: Vector2 = Vector2.ZERO) -> void:
	item_path = entry["item_path"]
	_cost = entry["cost"]
	var resource: Resource = load(item_path)
	if resource != null and "icon" in resource:
		_sprite.texture = resource.icon
	_sprite.scale = Vector2.ONE * ICON_SCALE
	_interactable.position = interact_offset
	_interactable.prompt_text = "Appuyer sur E pour acheter %s (%d monnaie)" % [entry["display_name"], _cost]
	_slot_offset = slot_offset


func _ready() -> void:
	z_index = 1
	var prompt_label := Label.new()
	prompt_label.name = "PromptLabel"
	var label_settings := LabelSettings.new()
	label_settings.font_size = 15
	label_settings.outline_size = 5
	label_settings.outline_color = Color(0.15, 0.1, 0.05, 1)
	prompt_label.label_settings = label_settings
	prompt_label.text = _interactable.prompt_text
	var text_width: float = prompt_label.get_minimum_size().x
	prompt_label.size = Vector2(text_width, PROMPT_LABEL_HEIGHT)
	prompt_label.position = _prompt_label_offset(text_width)
	_interactable.add_child(prompt_label)

	var collision := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = INTERACT_SIZE
	collision.position = Vector2(0, INTERACT_SIZE.y / 2.0)
	collision.shape = rect
	_interactable.add_child(collision)

	add_child(_interactable)
	_setup_backdrop()
	_backdrop.light_mask = 2
	add_child(_backdrop)
	_sprite.light_mask = 2
	add_child(_sprite)

	_interactable.interacted.connect(_on_interacted)
	_interactable.player_entered.connect(_on_player_entered)
	_interactable.player_left.connect(_on_player_left)


func _setup_backdrop() -> void:
	var hidden_area: Dictionary = ShelfBackdropLocator.find_hidden_area(
		_get_shelf_image(), _slot_offset, BACKDROP_SEARCH_RADIUS, BACKDROP_COLOR_THRESHOLD, BACKDROP_PADDING
	)
	var rect: Rect2 = hidden_area["rect"]
	if rect.size.x < 1.0 or rect.size.y < 1.0:
		return
	var color: Color = hidden_area["color"]
	var icon_center: Vector2 = rect.get_center() + Vector2(0, -BACKDROP_LIFT)
	var backdrop_rect: Rect2 = Rect2(rect.position, rect.size + Vector2(0, BACKDROP_BOTTOM_EXTRA))
	var width: int = maxi(1, roundi(backdrop_rect.size.x))
	var height: int = maxi(1, roundi(backdrop_rect.size.y))
	var img: Image = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			var edge_dist: float = minf(minf(x, width - 1 - x), minf(y, height - 1 - y))
			var alpha: float = clampf(edge_dist / BACKDROP_FEATHER, 0.0, 1.0)
			img.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	_backdrop.texture = ImageTexture.create_from_image(img)
	_backdrop.position = backdrop_rect.get_center() + Vector2(0, -BACKDROP_LIFT)
	_sprite.position = icon_center


func _room_center_is_to_the_right() -> bool:
	var room_col := floori(global_position.x / Room.ROOM_WIDTH_PX)
	var room_center_x: float = (room_col + 0.5) * Room.ROOM_WIDTH_PX
	return global_position.x < room_center_x


func _prompt_label_offset(text_width: float) -> Vector2:
	var y: float = -_interactable.position.y + PROMPT_LABEL_Y_OFFSET
	if _room_center_is_to_the_right():
		return Vector2(PROMPT_LABEL_GAP, y)
	return Vector2(-PROMPT_LABEL_GAP - text_width, y)


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
