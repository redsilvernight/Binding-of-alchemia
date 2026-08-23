extends Button


signal activated(payload: Resource)

@onready var icon_rect: TextureRect = $Icon
@onready var quantity_label: Label = $QuantityLabel

var payload: Resource


func setup(p_payload: Resource, icon: Texture2D, tooltip: String = "", quantity: int = -1) -> void:
	payload = p_payload
	icon_rect.texture = icon
	tooltip_text = tooltip
	if quantity >= 0:
		quantity_label.text = "x%d" % quantity
		quantity_label.visible = true
	else:
		quantity_label.visible = false


func _ready() -> void:
	pressed.connect(func() -> void: activated.emit(payload))


func _get_drag_data(_position: Vector2) -> Variant:
	var preview := TextureRect.new()
	preview.texture = icon_rect.texture
	preview.custom_minimum_size = Vector2(48, 48)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.modulate.a = 0.85
	set_drag_preview(preview)
	return {"part": payload}
