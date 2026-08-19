extends Button

## Objet possédé, cliquable ET glissable, dans une grille (weapon_crafting.gd
## pour les pièces d'arme, alchemy_crafting.gd pour les ingrédients). Button
## plutôt qu'un Control nu (comme inventory_slot) pour hériter gratuitement de
## l'activation clic/Entrée/manette (pressed) -- exactement ce qu'il fallait
## pour rester jouable à la manette sans code d'input dédié. Généralisé
## depuis weapon_part_slot.gd au 2e cas d'usage réel (cf.
## design_no_premature_genericity) : payload est un Resource quelconque
## (pièce d'arme OU ingrédient), l'écran appelant décide seul de ce que
## "activated" déclenche (équiper immédiatement / ajouter à une mixture en
## préparation).

signal activated(payload: Resource)

@onready var icon_rect: TextureRect = $Icon
@onready var quantity_label: Label = $QuantityLabel

var payload: Resource


## quantity == -1 : pas de quantité affichée (pièce d'arme, unique par nature).
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


## Drag & drop natif Godot : le contenu de retour ({"part": ...}) est ce que
## WeaponSocket._can_drop_data/_drop_data et MixtureDropTarget lisent.
func _get_drag_data(_position: Vector2) -> Variant:
	var preview := TextureRect.new()
	preview.texture = icon_rect.texture
	preview.custom_minimum_size = Vector2(48, 48)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.modulate.a = 0.85
	set_drag_preview(preview)
	return {"part": payload}
