class_name FacingDirection
extends RefCounted

const LABELS: Array[String] = [
	"east", "south-east", "south", "south-west",
	"west", "north-west", "north", "north-east",
]

static func label_for(direction: Vector2) -> String:
	var degrees := fposmod(rad_to_deg(direction.angle()), 360.0)
	var index := int(round(degrees / 45.0)) % 8
	return LABELS[index]
