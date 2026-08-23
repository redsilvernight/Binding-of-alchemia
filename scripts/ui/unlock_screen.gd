extends CanvasLayer


@onready var root: Control = $Root
@onready var currency_label: Label = $Root/Content/CurrencyLabel
@onready var unlock_list: ItemList = $Root/Content/UnlockList
@onready var unlock_button: Button = $Root/Content/UnlockButton
@onready var result_label: Label = $Root/Content/ResultLabel

var _local_peer_id: int = 0
var _visible_entries: Array[Dictionary] = []


func _ready() -> void:
	root.visible = false
	unlock_button.pressed.connect(_on_unlock_pressed)
	_local_peer_id = NetworkManager.get_unique_id()
	MetaProgression.currency_changed.connect(_on_currency_changed)
	MetaProgression.unlocks_changed.connect(_on_unlocks_changed)
	MetaProgression.shop_pool_changed.connect(_on_shop_pool_changed)


func open() -> void:
	AudioManager.play_sfx("station_open")
	result_label.text = ""
	_refresh_currency()
	_refresh_list()
	root.visible = true


func close() -> void:
	root.visible = false


func is_open() -> bool:
	return root.visible


func toggle() -> void:
	if root.visible:
		close()
	else:
		open()


func _on_currency_changed(_new_amount: int) -> void:
	if root.visible:
		_refresh_currency()


func _on_unlocks_changed() -> void:
	if root.visible:
		AudioManager.play_sfx("craft_success")
		_refresh_list()


func _on_shop_pool_changed() -> void:
	if root.visible:
		_refresh_list()


func _refresh_currency() -> void:
	currency_label.text = "Monnaie : %d" % MetaProgression.get_currency(_local_peer_id)


func _refresh_list() -> void:
	unlock_list.clear()
	_visible_entries.clear()
	var pool: Array = MetaProgression.get_shop_pool(_local_peer_id)
	for entry in MetaProgression.UNLOCKABLES:
		if not pool.has(entry["item_path"]):
			continue
		var unlocked: bool = MetaProgression.is_unlocked(_local_peer_id, entry["item_path"])
		var status: String = "débloqué" if unlocked else "%d monnaie" % entry["cost"]
		unlock_list.add_item("%s — %s" % [entry["display_name"], status])
		if unlocked:
			unlock_list.set_item_disabled(unlock_list.item_count - 1, true)
		_visible_entries.append(entry)


func _on_unlock_pressed() -> void:
	var selection: PackedInt32Array = unlock_list.get_selected_items()
	if selection.is_empty():
		AudioManager.play_sfx("ui_error")
		result_label.text = "Sélectionne un élément à débloquer."
		return

	var entry: Dictionary = _visible_entries[selection[0]]
	if MetaProgression.is_unlocked(_local_peer_id, entry["item_path"]):
		AudioManager.play_sfx("ui_error")
		result_label.text = "Déjà débloqué."
		return

	MetaProgression.request_unlock.rpc_id(1, entry["item_path"])
	result_label.text = "Déblocage demandé..."
