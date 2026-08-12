extends Control
## Menu principal (Phase 8.4), nouveau point d'entrée (project.godot run/main_scene).
## "Jouer" = solo, aucun réseau impliqué (NetworkManager.play_solo()).
## "Multijoueur" = écran host/join existant (scenes/menu.tscn), inchangé.
##
## Sélection de profil (Phase 8.5) : purement un choix de SaveManager.active_profile
## avant de lancer une partie -- Play/Multiplayer lisent ce profil au moment de
## hosting()/play_solo()/joining() (cf. network_manager.gd), donc changer de
## profil ici suffit, aucune autre logique réseau/meta_progression à toucher.

@onready var _play_button: Button = $Panel/MenuVBox/Play
@onready var _multiplayer_button: Button = $Panel/MenuVBox/Multiplayer
@onready var _options_button: Button = $Panel/MenuVBox/Options
@onready var _change_profile_button: Button = $Panel/MenuVBox/ChangeProfile
@onready var _quit_button: Button = $Panel/MenuVBox/Quit
@onready var _profile_label: Label = $Panel/MenuVBox/ProfileLabel

@onready var _options_panel: Control = $OptionsPanel
@onready var _volume_slider: HSlider = $OptionsPanel/OptionsVBox/VolumeSlider
@onready var _fullscreen_check: CheckButton = $OptionsPanel/OptionsVBox/FullscreenCheck
@onready var _back_button: Button = $OptionsPanel/OptionsVBox/Back

@onready var _profile_panel: Control = $ProfilePanel
@onready var _profile_buttons: Array[Button] = [
	$ProfilePanel/ProfileVBox/Profile0,
	$ProfilePanel/ProfileVBox/Profile1,
	$ProfilePanel/ProfileVBox/Profile2,
]
@onready var _profile_back_button: Button = $ProfilePanel/ProfileVBox/Back


func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_multiplayer_button.pressed.connect(_on_multiplayer_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_change_profile_button.pressed.connect(_on_change_profile_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

	_volume_slider.value_changed.connect(_on_volume_changed)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	_back_button.pressed.connect(_on_back_pressed)

	for i in _profile_buttons.size():
		_profile_buttons[i].pressed.connect(_on_profile_selected.bind(i))
	_profile_back_button.pressed.connect(_on_profile_back_pressed)

	_options_panel.visible = false
	_profile_panel.visible = false
	_update_profile_label()


func _on_play_pressed() -> void:
	NetworkManager.play_solo()


func _on_multiplayer_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _on_options_pressed() -> void:
	_volume_slider.value = Settings.master_volume
	_fullscreen_check.button_pressed = Settings.fullscreen
	_options_panel.visible = true


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_volume_changed(value: float) -> void:
	Settings.set_master_volume(value)


func _on_fullscreen_toggled(enabled: bool) -> void:
	Settings.set_fullscreen(enabled)


func _on_back_pressed() -> void:
	_options_panel.visible = false


func _on_change_profile_pressed() -> void:
	for i in _profile_buttons.size():
		var preview: Dictionary = SaveManager.get_profile_preview(i)
		_profile_buttons[i].text = "Profil %d — %d pièces" % [i + 1, preview["currency"]]
	_profile_panel.visible = true


func _on_profile_selected(index: int) -> void:
	SaveManager.set_active_profile(index)
	_update_profile_label()
	_profile_panel.visible = false


func _on_profile_back_pressed() -> void:
	_profile_panel.visible = false


func _update_profile_label() -> void:
	_profile_label.text = "Profil actif : Profil %d" % [SaveManager.get_active_profile() + 1]
