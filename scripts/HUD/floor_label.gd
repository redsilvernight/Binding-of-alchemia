extends Label
## Affiche l'étage courant (Phase 9). RunManager.current_floor est déjà
## répliqué à tous les pairs (cf. RunManager._rpc_set_floor) : pas besoin de
## passer par game.gd/le groupe "Game" comme minimap.gd, un simple abonnement
## au signal suffit.

func _ready() -> void:
	RunManager.floor_changed.connect(_on_floor_changed)
	_on_floor_changed(RunManager.current_floor)

func _on_floor_changed(new_floor: int) -> void:
	text = "Étage : %d" % new_floor
