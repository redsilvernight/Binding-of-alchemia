extends Control

@onready var icon_rect: TextureRect = $Icon
@onready var quantity_label: Label = $QuantityLabel


func setup(icon: Texture2D, quantity: int = -1, tooltip: String = "") -> void:
	icon_rect.texture = icon
	tooltip_text = tooltip

	if quantity >= 0:
		quantity_label.text = "x%d" % quantity
		quantity_label.visible = true
	else:
		quantity_label.visible = false
