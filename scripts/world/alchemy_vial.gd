class_name AlchemyVial
extends Node2D

# Petite fiole décorative liée à UN joueur (cf. AlchemyStation -- retour
# utilisateur : rendre visible côté client qui a déjà utilisé la table sur cet
# étage, sans que ce soit perçu comme une mécanique à part). Purement locale à
# chaque pair : aucune autorité réseau propre, aucun MultiplayerSpawner --
# elle ne fait que REFLÉTER un état déjà répliqué ailleurs
# (RunManager.alchemy_used_by_peer, cf. RunManager._rpc_set_alchemy_used) et
# suit la présence/absence du noeud Player correspondant (cf.
# AlchemyStation._on_player_added/_on_player_removed), donc rien ici n'a
# besoin d'être répliqué séparément.

@onready var _whole_sprite: Sprite2D = $WholeSprite
@onready var _broken_sprite: Sprite2D = $BrokenSprite

## Peer_id du joueur propriétaire -- assigné par AlchemyStation juste après
## instantiate(), purement informatif ici (utile pour déboguer/identifier).
var peer_id: int = 0


## Silencieux (pas de son ni d'effet) : utilisé pour poser l'état INITIAL
## d'une fiole, qui peut déjà être "cassée" (joueur ayant déjà utilisé la
## table avant que ce pair particulier ne rejoigne, cf. rattrapage à l'entrée
## dans l'arbre) -- cf. break_effect() pour l'évènement "vient de casser".
func set_broken(broken: bool) -> void:
	_whole_sprite.visible = not broken
	_broken_sprite.visible = broken


## Appelée depuis AlchemyStation quand RunManager.alchemy_lock_changed signale
## que CE joueur vient de réussir un craft -- contrairement à set_broken(),
## joue le bruit de bris de verre : c'est l'unique moment où la casse doit
## être perçue comme un évènement qui vient de se produire.
func break_effect() -> void:
	set_broken(true)
	AudioManager.play_sfx("vial_break")
