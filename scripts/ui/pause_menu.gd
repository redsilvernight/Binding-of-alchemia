extends CanvasLayer


@onready var root: Control = $Root
@onready var _resume_button: Button = $Root/Panel/VBox/Resume
@onready var _volume_slider: HSlider = $Root/Panel/VBox/VolumeSlider
@onready var _music_volume_slider: HSlider = $Root/Panel/VBox/MusicVolumeSlider
@onready var _sfx_volume_slider: HSlider = $Root/Panel/VBox/SfxVolumeSlider
@onready var _fullscreen_check: CheckButton = $Root/Panel/VBox/FullscreenCheck
@onready var _dynamic_lighting_check: CheckButton = $Root/Panel/VBox/DynamicLightingCheck
@onready var _controller_device_option: OptionButton = $Root/Panel/VBox/ControllerDeviceOption
@onready var _return_to_menu_button: Button = $Root/Panel/VBox/ReturnToMenu


func _ready() -> void:
	root.visible = RunManager.is_paused
	RunManager.pause_changed.connect(_on_pause_changed)
	_resume_button.pressed.connect(_request_toggle_pause)
	_volume_slider.value_changed.connect(Settings.set_master_volume)
	_music_volume_slider.value_changed.connect(Settings.set_music_volume)
	_sfx_volume_slider.value_changed.connect(Settings.set_sfx_volume)
	_fullscreen_check.toggled.connect(Settings.set_fullscreen)
	_dynamic_lighting_check.toggled.connect(Settings.set_dynamic_lighting)
	_controller_device_option.item_selected.connect(_on_controller_device_selected)
	_return_to_menu_button.pressed.connect(_on_return_to_menu_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_request_toggle_pause()


func _request_toggle_pause() -> void:
	RunManager.request_toggle_pause.rpc()


func _on_pause_changed(paused: bool) -> void:
	root.visible = paused
	if paused:
		_volume_slider.value = Settings.master_volume
		_music_volume_slider.value = Settings.music_volume
		_sfx_volume_slider.value = Settings.sfx_volume
		_fullscreen_check.button_pressed = Settings.fullscreen
		_dynamic_lighting_check.button_pressed = Settings.dynamic_lighting
		_refresh_controller_device_options()
	AudioManager.play_sfx("ui_toggle")


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


func _on_return_to_menu_pressed() -> void:
	RunManager.request_return_to_menu.rpc()
