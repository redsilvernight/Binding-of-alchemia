extends CanvasLayer


@onready var root: Control = $Root
@onready var _resume_button: Button = $Root/Panel/VBox/Resume
@onready var _volume_slider: HSlider = $Root/Panel/VBox/VolumeSlider
@onready var _music_volume_slider: HSlider = $Root/Panel/VBox/MusicVolumeSlider
@onready var _sfx_volume_slider: HSlider = $Root/Panel/VBox/SfxVolumeSlider
@onready var _fullscreen_check: CheckButton = $Root/Panel/VBox/FullscreenCheck
@onready var _dynamic_lighting_check: CheckButton = $Root/Panel/VBox/DynamicLightingCheck
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
	AudioManager.play_sfx("ui_toggle")


func _on_return_to_menu_pressed() -> void:
	RunManager.request_return_to_menu.rpc()
