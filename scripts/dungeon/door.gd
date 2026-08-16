class_name Door
extends Node2D

# Habillage VISUEL d'une embrasure de porte (Phase 10, collision passée aux
# tuiles en Phase 10.x). La porte n'a plus de collision propre : c'est
# Room._set_door_gap_tiles() qui bloque le passage en repeignant l'embrasure
# (Room._paint_walls()) en tuile de mur pendant un verrouillage, via le
# physics layer de dungeon_stone_terrain.tres -- avoir deux systèmes de
# collision distincts (mur en tuiles + StaticBody2D de porte) togglés en
# parallèle laissait des fenêtres où l'un désynchronisait l'autre et le
# joueur passait à travers une porte pourtant fermée à l'écran. Ce script ne
# gère donc plus que le fondu visuel entre les deux sprites et le son.
# Deux sprites (Closed/Open) plutôt qu'une AnimatedSprite2D à frames
# interpolées : un fondu enchaîné entre les deux états suffit à lire le
# changement de porte et évite une génération d'animation PixelLab
# supplémentaire (coût + attente) pour un effet purement cosmétique.

const FADE_DURATION: float = 0.3

@onready var _closed_sprite: Sprite2D = $Closed
@onready var _open_sprite: Sprite2D = $Open

var _open: bool = false
var _tween: Tween
## Phase 9.4 : la toute première application d'état (dungeon_generator, via
## Room.set_open_sides -> _apply_walls) ouvrirait sinon TOUTES les portes du
## donjon fraîchement généré en même temps -- silencieuse, seuls les VRAIS
## verrouillages/déverrouillages de combat (appels suivants) sonnent.
var _initialized: bool = false


func _ready() -> void:
	_closed_sprite.modulate.a = 1.0
	_open_sprite.modulate.a = 0.0


func set_state(effectively_open: bool) -> void:
	if effectively_open == _open and _initialized:
		return
	var should_play_sound: bool = _initialized
	_initialized = true
	_open = effectively_open
	if should_play_sound:
		AudioManager.play_sfx("door_open" if effectively_open else "door_close")
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_closed_sprite, "modulate:a", 0.0 if effectively_open else 1.0, FADE_DURATION)
	_tween.tween_property(_open_sprite, "modulate:a", 1.0 if effectively_open else 0.0, FADE_DURATION)
