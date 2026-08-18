extends CanvasLayer

# Menu pause (retour utilisateur : la première version togguait juste sa
# propre visibilité localement, le jeu continuait de tourner derrière). Pause
# désormais RÉELLE et PARTAGÉE via RunManager.is_paused/pause_changed
# (get_tree().paused synchronisé par RPC sur tous les pairs, cf.
# run_manager.gd) : ce script ne fait plus que REQUÊTER le bascule et
# REFLÉTER l'état reçu, il ne décide jamais lui-même d'afficher root.
#
# process_mode = PROCESS_MODE_ALWAYS (cf. .tscn) : sans ça, ce noeud arrête
# de recevoir _unhandled_input/les clics sur ses propres boutons dès que
# get_tree().paused passe à true (comportement par défaut de tout Node) --
# on ne pourrait plus jamais rouvrir/refermer le panneau une fois en pause.

@onready var root: Control = $Root
@onready var _resume_button: Button = $Root/Panel/VBox/Resume
@onready var _volume_slider: HSlider = $Root/Panel/VBox/VolumeSlider
@onready var _music_volume_slider: HSlider = $Root/Panel/VBox/MusicVolumeSlider
@onready var _sfx_volume_slider: HSlider = $Root/Panel/VBox/SfxVolumeSlider
@onready var _fullscreen_check: CheckButton = $Root/Panel/VBox/FullscreenCheck
@onready var _dynamic_lighting_check: CheckButton = $Root/Panel/VBox/DynamicLightingCheck
@onready var _abandon_run_button: Button = $Root/Panel/VBox/AbandonRun


func _ready() -> void:
	root.visible = RunManager.is_paused
	RunManager.pause_changed.connect(_on_pause_changed)
	_resume_button.pressed.connect(_request_toggle_pause)
	_volume_slider.value_changed.connect(Settings.set_master_volume)
	_music_volume_slider.value_changed.connect(Settings.set_music_volume)
	_sfx_volume_slider.value_changed.connect(Settings.set_sfx_volume)
	_fullscreen_check.toggled.connect(Settings.set_fullscreen)
	_dynamic_lighting_check.toggled.connect(Settings.set_dynamic_lighting)
	_abandon_run_button.pressed.connect(_on_abandon_run_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_request_toggle_pause()


## N'importe quel pair peut demander le bascule (touche "pause" ou bouton
## Reprendre) -- request_toggle_pause() ne fait qu'exprimer l'intention,
## seul l'hôte décide réellement et rediffuse l'état réel via pause_changed
## (cf. run_manager.gd) : root.visible n'est jamais mis à jour ici
## directement, seulement depuis _on_pause_changed.
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


## request_return_to_hub (RunManager) réinitialise l'étage et ramène TOUT le
## groupe au hub (même RPC que le bouton "Rejouer" du panneau de résumé de
## run après une défaite) -- un pair qui abandonne met donc fin à la run pour
## tout le monde, pas seulement pour lui-même. Le libellé du bouton
## ("Abandonner la run") reflète cette portée volontairement.
func _on_abandon_run_pressed() -> void:
	RunManager.request_return_to_hub.rpc()
