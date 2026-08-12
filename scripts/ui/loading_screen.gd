extends CanvasLayer
## Écran de chargement plein écran (Phase 9), affiché pendant les transitions
## hub <-> donjon. Instancié une seule fois par RunManager (Autoload) et gardé
## comme enfant permanent -- un CanvasLayer survit à change_scene_to_file tant
## que son parent n'est pas dans la scène détruite, donc reste visible sans
## interruption pendant toute la transition (génération du donjon incluse),
## contrairement à un noeud de la scène elle-même qui serait détruit puis
## recréé.

const DOT_INTERVAL: float = 0.4
const MAX_DOTS: int = 3

@onready var label: Label = $Label

var _dot_count: int = 0
var _timer: Timer


func _ready() -> void:
	layer = 100 # au-dessus de tout HUD de jeu
	visible = false
	_timer = Timer.new()
	_timer.wait_time = DOT_INTERVAL
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)


func show_loading() -> void:
	_dot_count = 0
	label.text = "Chargement"
	visible = true
	_timer.start()


func hide_loading() -> void:
	visible = false
	_timer.stop()


func _on_timer_timeout() -> void:
	_dot_count = (_dot_count + 1) % (MAX_DOTS + 1)
	label.text = "Chargement" + ".".repeat(_dot_count)
