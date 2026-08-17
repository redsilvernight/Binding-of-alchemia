class_name MixtureToEffect
extends RefCounted

## zone_base des ingrédients est une unité "de conception" (1.0-3.5, cf.
## resources/Ingredients/*.tres) -- converti ici en pixels via ce facteur.
## Calibré sur ImpactArea.tres (radius=200 pour une zone "pleine"), pertinent
## à l'échelle des salles (ROOM_CELL_SIZE = 1344x960, cf. game.gd).
const ZONE_SCALE: float = 60.0

static func convertir(mixture: Mixture) -> ImpactEffect:
	var effets: Array[ImpactEffect] = []

	for type in mixture.get_types_presents():
		var effet_par_type: Mixture.EffetParType = mixture.get_effet(type)
		effets.append(_creer_impact(type, effet_par_type))

	var composite := ImpactComposite.new()
	composite.effets = effets

	return composite


## type est nécessaire pour distinguer SOIN (vol de vie sur le tireur) des
## types offensifs (dégâts sur la cible touchée) -- avant cette correction,
## un ingrédient Soin (degats_base négatif) soignait l'ENNEMI touché au lieu
## du joueur, puisque ImpactDamage/ImpactArea appliquent toujours leur effet
## sur la cible du tir, jamais sur le tireur.
static func _creer_impact(type: Ingredient.TypeAlchimie, effet_par_type: Mixture.EffetParType) -> ImpactEffect:
	if type == Ingredient.TypeAlchimie.SOIN:
		var impact_heal := ImpactHeal.new()
		impact_heal.amount = abs(effet_par_type.degats)
		return impact_heal

	if effet_par_type.zone > 0.0:
		var impact_area := ImpactArea.new()
		impact_area.damage = effet_par_type.degats
		impact_area.radius = effet_par_type.zone * ZONE_SCALE
		impact_area.duration = effet_par_type.duree
		impact_area.type_alchimie = type
		return impact_area

	var impact_damage := ImpactDamage.new()
	impact_damage.damage = effet_par_type.degats
	impact_damage.duration = effet_par_type.duree
	return impact_damage
