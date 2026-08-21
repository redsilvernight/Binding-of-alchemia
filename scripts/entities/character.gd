class_name Character
extends CharacterBody2D

signal health_changed(max_lifepoint: float, lifepoint: float)
## Distinct de health_changed (Phase 9.2, 3e passe, ennemi soigneur) : les
## sous-classes concrètes réagissent à health_changed en jouant une anim
## "hit-*" dès que lifepoint > 0, sans distinguer dégât et soin -- réutiliser
## ce signal pour un soin y jouerait donc à tort l'anim de coup. healed()
## permet à heal() de répliquer lifepoint sans déclencher ce chemin.
signal healed(max_lifepoint: float, lifepoint: float)
signal died
@export var max_lifepoint: float = 20.0
var lifepoint: float
var is_dead: bool = false
var can_take_damage: bool = true

func _ready() -> void:
	# Jeu topdown sans gravité : GROUNDED (défaut CharacterBody2D) classe les
	# contacts en sol/mur/plafond selon up_direction et fait hériter la
	# vélocité d'un "sol" en mouvement -- non pertinent ici, et cause de
	# blocages/glissements erratiques quand deux capsules se poussent selon
	# certains angles (joueur coincé contre un mur par un ennemi, par ex.).
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	lifepoint = max_lifepoint

func move(direction: Vector2, speed: float) -> void:
	velocity = direction * speed
	move_and_slide()

func take_damage(degat: float) -> void:
	if not multiplayer.is_server():
		return
	if is_dead:
		return
	if not can_take_damage:
		return
	lifepoint -= degat
	_update_health.rpc(max_lifepoint, lifepoint)
	if lifepoint <= 0:
		kill()
	else:
		_start_invulnerability()

## Phase 9.2 (3e passe, ennemi soigneur) : hôte-only comme take_damage(),
## plafonné à max_lifepoint. Passe par une RPC dédiée (_update_heal) plutôt
## que _update_health -- voir le commentaire sur le signal healed.
func heal(amount: float) -> void:
	if not multiplayer.is_server():
		return
	if is_dead:
		return
	lifepoint = min(lifepoint + amount, max_lifepoint)
	_update_heal.rpc(lifepoint)

@rpc("any_peer", "call_local", "reliable")
func _update_heal(p_lifepoint: float) -> void:
	lifepoint = p_lifepoint
	healed.emit(max_lifepoint, lifepoint)

## Point d'extension : ne fait rien par défaut. Les sous-classes qui veulent
## des i-frames (ex: Player, via son DamageTimer) surchargent cette méthode.
func _start_invulnerability() -> void:
	pass

@rpc("any_peer", "call_local", "reliable")
func _update_health(p_max_lifepoint: float, p_lifepoint: float) -> void:
	var previous_lifepoint: float = lifepoint
	max_lifepoint = p_max_lifepoint
	lifepoint = p_lifepoint
	health_changed.emit(max_lifepoint, lifepoint)
	# is_dead/died sont dérivés ici plutôt que dans take_damage (hôte
	# uniquement) pour se répliquer identiquement chez tous les pairs via ce
	# même RPC (call_local, y compris l'hôte) — cf. Player._on_died (8.1) qui
	# a besoin de is_dead sur chaque client, pas seulement l'hôte. Même point
	# centralisé pour le SFX de dégât/mort (Phase 9.4) : couvre joueur ET
	# tous les types d'ennemis sans dupliquer un hook par script concret.
	#
	# "hit" et "death" ne sont PAS mutuellement exclusifs (contrairement à la
	# 1ère version, if/elif) : un coup fatal doit s'entendre comme un coup EN
	# PLUS de sonner la mort, sinon un ennemi tué en un coup (fréquent sur les
	# mobs faibles) ne fait jamais entendre le moindre son de dégât.
	if lifepoint < previous_lifepoint:
		AudioManager.play_sfx(_get_hit_sfx_key())
	if lifepoint <= 0 and not is_dead:
		is_dead = true
		died.emit()
		AudioManager.play_sfx(_get_death_sfx_key())

func kill() -> void:
	if multiplayer.is_server():
		_die_and_free()

## Point d'extension (Phase 9.3) : libère immédiatement par défaut. Les
## sous-classes avec une animation de mort peuvent surcharger pour l'attendre
## avant de se libérer réellement -- is_dead bloque déjà toute interaction
## entre-temps (take_damage, ciblage ennemi via _closest_living_player), donc
## le nœud peut rester dans l'arbre le temps de l'anim sans risque.
func _die_and_free() -> void:
	queue_free()

## Point d'extension (Phase 9.4) : clé SFX ("assets/audio/sfx/<clé>.ogg")
## jouée à la mort. Les sous-classes avec un son de mort distinct (ex: Boss01)
## surchargent -- même pattern d'extension que _die_and_free().
func _get_death_sfx_key() -> String:
	return "death"

## Même pattern d'extension que _get_death_sfx_key() -- EnemyBase surcharge
## pour un son distinct de celui du joueur (cf. enemy_base.gd).
func _get_hit_sfx_key() -> String:
	return "hit"
