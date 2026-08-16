class_name Door
extends Node2D

# Habillage d'une embrasure de porte (Phase 10). Porte désormais seule
# responsable de bloquer le passage quand elle est fermée : les murs
# Room._closed_by_side/_open_by_side ne servent plus qu'aux côtés sans
# aucune porte (pas de voisin structurel) -- cf. Room._apply_walls(). Les
# tuiles de mur/sol (Room._paint_walls()) reflètent uniquement la
# connectivité structurelle, jamais le verrouillage : l'embrasure reste
# visuellement ouverte en permanence, seule la porte (sprite + collision
# ici) se ferme pendant un combat.
# Deux sprites (Closed/Open) plutôt qu'une AnimatedSprite2D à frames
# interpolées : un fondu enchaîné entre les deux états suffit à lire le
# changement de porte et évite une génération d'animation PixelLab
# supplémentaire (coût + attente) pour un effet purement cosmétique.

const FADE_DURATION: float = 0.3

@onready var _closed_sprite: Sprite2D = $Closed
@onready var _open_sprite: Sprite2D = $Open
@onready var _collision: CollisionShape2D = $StaticBody2D/CollisionShape2D

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
	_collision.disabled = false


func set_state(effectively_open: bool) -> void:
	if effectively_open == _open and _initialized:
		return
	var should_play_sound: bool = _initialized
	_initialized = true
	_open = effectively_open
	if should_play_sound:
		AudioManager.play_sfx("door_open" if effectively_open else "door_close")
	_collision.set_deferred("disabled", effectively_open)
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_closed_sprite, "modulate:a", 0.0 if effectively_open else 1.0, FADE_DURATION)
	_tween.tween_property(_open_sprite, "modulate:a", 1.0 if effectively_open else 0.0, FADE_DURATION)
