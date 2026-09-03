class_name HitStop
extends RefCounted

const TIME_SCALE_DURING_STOP: float = 0.05
const DAMAGE_RATIO_THRESHOLD: float = 0.35
const STOP_DURATION_MIN: float = 0.02
const STOP_DURATION_MAX: float = 0.08

static var _active: bool = false

static func trigger_for_damage(damage: float, target_max_lifepoint: float) -> void:
	if _active or target_max_lifepoint <= 0.0:
		return
	var ratio: float = damage / target_max_lifepoint
	if ratio < DAMAGE_RATIO_THRESHOLD:
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_active = true
	Engine.time_scale = TIME_SCALE_DURING_STOP
	var duration: float = lerp(STOP_DURATION_MIN, STOP_DURATION_MAX, clamp(ratio, 0.0, 1.0))
	var timer: SceneTreeTimer = tree.create_timer(duration, true, false, true)
	timer.timeout.connect(_restore)

static func _restore() -> void:
	Engine.time_scale = 1.0
	_active = false
