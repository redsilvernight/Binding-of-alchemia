extends Control

const DISCORD_INVITE_URL := "https://discord.gg/DFMnKzJA4"

@onready var _play_button: Button = $Panel/MenuVBox/Play
@onready var _multiplayer_button: Button = $Panel/MenuVBox/Multiplayer
@onready var _options_button: Button = $Panel/MenuVBox/Options
@onready var _change_profile_button: Button = $Panel/MenuVBox/ChangeProfile
@onready var _discord_button: Button = $Panel/MenuVBox/Discord
@onready var _quit_button: Button = $Panel/MenuVBox/Quit
@onready var _profile_label: Label = $Panel/MenuVBox/ProfileLabel

@onready var _options_panel: Control = $OptionsPanel
@onready var _volume_slider: HSlider = $OptionsPanel/OptionsVBox/VolumeSlider
@onready var _music_volume_slider: HSlider = $OptionsPanel/OptionsVBox/MusicVolumeSlider
@onready var _sfx_volume_slider: HSlider = $OptionsPanel/OptionsVBox/SfxVolumeSlider
@onready var _fullscreen_check: CheckButton = $OptionsPanel/OptionsVBox/FullscreenCheck
@onready var _dynamic_lighting_check: CheckButton = $OptionsPanel/OptionsVBox/DynamicLightingCheck
@onready var _controller_device_option: OptionButton = $OptionsPanel/OptionsVBox/ControllerDeviceOption
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
	_discord_button.pressed.connect(_on_discord_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

	_volume_slider.value_changed.connect(_on_volume_changed)
	_music_volume_slider.value_changed.connect(_on_music_volume_changed)
	_sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	_dynamic_lighting_check.toggled.connect(_on_dynamic_lighting_toggled)
	_controller_device_option.item_selected.connect(_on_controller_device_selected)
	_back_button.pressed.connect(_on_back_pressed)

	for i in _profile_buttons.size():
		_profile_buttons[i].pressed.connect(_on_profile_selected.bind(i))
	_profile_back_button.pressed.connect(_on_profile_back_pressed)

	var clickable_buttons: Array[Button] = [
		_play_button, _multiplayer_button, _options_button, _change_profile_button,
		_discord_button, _quit_button, _back_button, _profile_back_button,
	]
	clickable_buttons.append_array(_profile_buttons)
	for button in clickable_buttons:
		button.pressed.connect(AudioManager.play_sfx.bind("ui_click"))

	_options_panel.visible = false
	_profile_panel.visible = false
	_update_profile_label()
	_play_button.grab_focus()

	if OS.has_feature("web"):
		_multiplayer_button.disabled = true
		_multiplayer_button.tooltip_text = "Indisponible sur navigateur — télécharge la version Windows pour jouer en multijoueur."


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _profile_panel.visible:
		_on_profile_back_pressed()
	elif _options_panel.visible:
		_on_back_pressed()


func _on_play_pressed() -> void:
	NetworkManager.play_solo()


func _on_multiplayer_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _on_options_pressed() -> void:
	_volume_slider.value = Settings.master_volume
	_music_volume_slider.value = Settings.music_volume
	_sfx_volume_slider.value = Settings.sfx_volume
	_fullscreen_check.button_pressed = Settings.fullscreen
	_dynamic_lighting_check.button_pressed = Settings.dynamic_lighting
	_refresh_controller_device_options()
	_options_panel.visible = true
	_volume_slider.grab_focus()


func _on_discord_pressed() -> void:
	OS.shell_open(DISCORD_INVITE_URL)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_volume_changed(value: float) -> void:
	Settings.set_master_volume(value)


func _on_music_volume_changed(value: float) -> void:
	Settings.set_music_volume(value)


func _on_sfx_volume_changed(value: float) -> void:
	Settings.set_sfx_volume(value)


func _on_fullscreen_toggled(enabled: bool) -> void:
	Settings.set_fullscreen(enabled)


func _on_dynamic_lighting_toggled(enabled: bool) -> void:
	Settings.set_dynamic_lighting(enabled)


func _refresh_controller_device_options() -> void:
	_controller_device_option.clear()
	_controller_device_option.add_item("Toutes les manettes")
	_controller_device_option.set_item_metadata(0, -1)
	var selected_index := 0
	for device_id in Input.get_connected_joypads():
		var item_index: int = _controller_device_option.item_count
		_controller_device_option.add_item("Manette %d — %s" % [device_id + 1, Input.get_joy_name(device_id)])
		_controller_device_option.set_item_metadata(item_index, device_id)
		if device_id == Settings.controller_device_id:
			selected_index = item_index
	_controller_device_option.select(selected_index)


func _on_controller_device_selected(index: int) -> void:
	Settings.set_controller_device(_controller_device_option.get_item_metadata(index))


func _on_back_pressed() -> void:
	_options_panel.visible = false
	_options_button.grab_focus()


func _on_change_profile_pressed() -> void:
	for i in _profile_buttons.size():
		var preview: Dictionary = SaveManager.get_profile_preview(i)
		_profile_buttons[i].text = "Profil %d — %d pièces" % [i + 1, preview["currency"]]
	_profile_panel.visible = true
	_profile_buttons[0].grab_focus()


func _on_profile_selected(index: int) -> void:
	SaveManager.set_active_profile(index)
	_update_profile_label()
	_profile_panel.visible = false
	_change_profile_button.grab_focus()


func _on_profile_back_pressed() -> void:
	_profile_panel.visible = false
	_change_profile_button.grab_focus()


func _update_profile_label() -> void:
	_profile_label.text = "Profil actif : Profil %d" % [SaveManager.get_active_profile() + 1]
