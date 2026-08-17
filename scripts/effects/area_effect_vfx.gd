extends Node2D
class_name AreaEffectVfx
## Feedback visuel pur pour ImpactArea (cf. impact_area.gd::spawn_visual) --
## aucune logique de gameplay ici, juste un sprite qui grossit jusqu'au
## diamètre réel de la zone puis s'efface. Instancié/détruit par appel,
## jamais réutilisé (pas de pool : ces impacts sont rares comparés aux
## balles, cf. discussion mixture).

const TEXTURE_SIZE: float = 128.0
const GROW_DURATION: float = 0.18
const FADE_DURATION: float = 0.25

@export var texture_feu: Texture2D
@export var texture_glace: Texture2D
@export var texture_poison: Texture2D
@export var texture_electrique: Texture2D
@export var texture_explosif: Texture2D

@onready var sprite: Sprite2D = $Sprite2D


func play(type_alchimie: Ingredient.TypeAlchimie, radius: float) -> void:
	sprite.texture = _texture_for(type_alchimie)
	sprite.scale = Vector2.ONE * 0.15
	sprite.modulate.a = 1.0

	# Le diamètre visuel doit correspondre au vrai rayon de zone (celui qui
	# détermine quels ennemis sont touchés, cf. ImpactArea.apply) -- sinon le
	# feedback mentirait sur la portée réelle de l'effet.
	var target_scale: float = (radius * 2.0) / TEXTURE_SIZE

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2.ONE * target_scale, GROW_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate:a", 0.0, FADE_DURATION).set_delay(GROW_DURATION * 0.5)
	tween.chain().tween_callback(queue_free)


func _texture_for(type_alchimie: Ingredient.TypeAlchimie) -> Texture2D:
	match type_alchimie:
		Ingredient.TypeAlchimie.FEU:
			return texture_feu
		Ingredient.TypeAlchimie.GLACE:
			return texture_glace
		Ingredient.TypeAlchimie.POISON:
			return texture_poison
		Ingredient.TypeAlchimie.ELECTRIQUE:
			return texture_electrique
		Ingredient.TypeAlchimie.EXPLOSIF:
			return texture_explosif
		_:
			return texture_feu
