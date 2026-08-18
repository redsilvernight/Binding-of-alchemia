extends CanvasLayer

# Écran de déblocage méta (Phase 8.2). Contrairement à alchemy_crafting.gd/
# weapon_crafting.gd (bind_inventory sur le Node par-joueur), cet écran lit
# directement l'autoload MetaProgression : la monnaie/les déblocages ne sont
# PAS dans Inventory (qui est détruit/recréé à chaque run, cf. run_manager.gd),
# ils doivent survivre au cycle hub <-> donjon. N'agit jamais lui-même : il
# envoie l'intention d'achat par RPC vers l'hôte (MetaProgression.request_unlock),
# qui seul valide le coût et débite (cf. architecture_reseau.md).

@onready var root: Control = $Root
@onready var currency_label: Label = $Root/Content/CurrencyLabel
@onready var unlock_list: ItemList = $Root/Content/UnlockList
@onready var unlock_button: Button = $Root/Content/UnlockButton
@onready var result_label: Label = $Root/Content/ResultLabel

var _local_peer_id: int = 0


func _ready() -> void:
	root.visible = false
	unlock_button.pressed.connect(_on_unlock_pressed)
	_local_peer_id = NetworkManager.get_unique_id()
	MetaProgression.currency_changed.connect(_on_currency_changed)
	MetaProgression.unlocks_changed.connect(_on_unlocks_changed)


func open() -> void:
	AudioManager.play_sfx("station_open")
	result_label.text = ""
	_refresh_currency()
	_refresh_list()
	root.visible = true


func close() -> void:
	root.visible = false


## Retour utilisateur : se ferme désormais avec la même touche qu'à
## l'ouverture (E, via Interactable -> Player.open_unlock_screen()) plutôt
## qu'avec Échap -- Échap est maintenant réservé au menu pause
## (pause_menu.gd), les deux se disputaient la même touche.
func toggle() -> void:
	if root.visible:
		close()
	else:
		open()


func _on_currency_changed(_new_amount: int) -> void:
	if root.visible:
		_refresh_currency()


func _on_unlocks_changed() -> void:
	# Gardé par root.visible (comme _refresh_list) : unlocks_changed rejoue
	# aussi au rattrapage d'un pair qui rejoint la partie avec des
	# déblocages déjà acquis (cf. hub.gd._on_peer_connected -> _rpc_unlocked)
	# -- sans cette garde, se reconnecter ferait sonner "achat" pour chaque
	# déblocage déjà possédé, alors que l'écran n'a jamais été ouvert.
	if root.visible:
		AudioManager.play_sfx("craft_success")
		_refresh_list()


func _refresh_currency() -> void:
	currency_label.text = "Monnaie : %d" % MetaProgression.get_currency(_local_peer_id)


func _refresh_list() -> void:
	unlock_list.clear()
	for entry in MetaProgression.UNLOCKABLES:
		var unlocked: bool = MetaProgression.is_unlocked(_local_peer_id, entry["item_path"])
		var status: String = "débloqué" if unlocked else "%d monnaie" % entry["cost"]
		unlock_list.add_item("%s — %s" % [entry["display_name"], status])
		if unlocked:
			unlock_list.set_item_disabled(unlock_list.item_count - 1, true)


func _on_unlock_pressed() -> void:
	var selection: PackedInt32Array = unlock_list.get_selected_items()
	if selection.is_empty():
		AudioManager.play_sfx("ui_error")
		result_label.text = "Sélectionne un élément à débloquer."
		return

	var entry: Dictionary = MetaProgression.UNLOCKABLES[selection[0]]
	if MetaProgression.is_unlocked(_local_peer_id, entry["item_path"]):
		AudioManager.play_sfx("ui_error")
		result_label.text = "Déjà débloqué."
		return

	# L'hôte revalidera le coût/le stock de monnaie avant de débiter quoi que
	# ce soit ; on ne fait ici qu'exprimer l'intention.
	MetaProgression.request_unlock.rpc_id(1, entry["item_path"])
	result_label.text = "Déblocage demandé..."
