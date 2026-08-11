extends Node2D

# Station de départ de run, hub (Phase 8.1). Même convention que
# alchemy_station.gd/weapon_station.gd : Interactable détecte, ce script
# relaie vers l'action réseau correspondante — ici RunManager plutôt que
# l'inventaire local du joueur.

@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	interactable.interacted.connect(_on_interacted)


func _on_interacted(_player: Node2D) -> void:
	RunManager.request_start_run.rpc_id(1)
