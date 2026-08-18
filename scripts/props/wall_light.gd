class_name WallLight
extends Node2D

# Source de lumière pure (Phase 11, ambiance visuelle) -- construite en code
# comme AreaEffectVfx, PAS de scène (retour utilisateur : "pas de scène
# exclusive à un props"). La partie VISUELLE (torche/cristal/brasero) est
# désormais une tuile peinte sur PropsDecor comme n'importe quel autre décor
# (cf. Room._setup_wall_light(), qui positionne ce noeud exactement sur
# cette même tuile) -- ce noeud ne porte donc plus de sprite du tout, juste
# le PointLight2D qui l'éclaire, séparé de la tuile qu'il illumine.

const LIGHT_TEXTURE: Texture2D = preload("res://resources/vfx/point_light_radial.tres")
const FLICKER_MIN_ENERGY: float = 0.85
const FLICKER_MAX_ENERGY: float = 1.15
const FLICKER_MIN_DURATION: float = 0.4
const FLICKER_MAX_DURATION: float = 0.9

## Construit immédiatement (pas de @onready) : ce noeud est créé et configuré
## par Room._setup_wall_light() avant/après add_child selon l'ordre choisi
## là-bas -- set_color() doit rester utilisable dans les deux cas, cf. le
## même piège que Room.set_floor_tileset() (get_node() direct plutôt qu'un
## @onready pas encore assigné).
var _light: PointLight2D = PointLight2D.new()


func set_color(color: Color) -> void:
	_light.color = color


func _ready() -> void:
	_light.texture = LIGHT_TEXTURE
	_light.texture_scale = 1.1
	_light.shadow_enabled = true
	_light.shadow_color = Color(0, 0, 0, 0.3)
	add_child(_light)
	_light.energy = randf_range(FLICKER_MIN_ENERGY, FLICKER_MAX_ENERGY)
	_flicker_loop()


func _flicker_loop() -> void:
	var target_energy: float = randf_range(FLICKER_MIN_ENERGY, FLICKER_MAX_ENERGY)
	var duration: float = randf_range(FLICKER_MIN_DURATION, FLICKER_MAX_DURATION)
	var tween: Tween = create_tween()
	tween.tween_property(_light, "energy", target_energy, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(_flicker_loop)
