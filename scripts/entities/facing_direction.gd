## Phase 9.3 : direction 2D -> label de secteur à 45°, utilisé pour choisir
## quelle animation directionnelle jouer (joueur, puis ennemi mêlée -- 2e cas
## d'usage réel, généralisation faite à ce moment-là, cf.
## design_no_premature_genericity).
class_name FacingDirection
extends RefCounted

## Ordre des secteurs de 45° en partant de l'Est et en tournant dans le sens
## horaire (cohérent avec Vector2.angle() en repère écran où Y+ pointe vers
## le bas).
const LABELS: Array[String] = [
	"east", "south-east", "south", "south-west",
	"west", "north-west", "north", "north-east",
]

static func label_for(direction: Vector2) -> String:
	var degrees := fposmod(rad_to_deg(direction.angle()), 360.0)
	var index := int(round(degrees / 45.0)) % 8
	return LABELS[index]
