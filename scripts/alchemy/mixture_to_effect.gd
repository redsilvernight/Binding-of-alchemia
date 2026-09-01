class_name MixtureToEffect
extends RefCounted

const ZONE_SCALE: float = 100.0

static func convertir(mixture: Mixture) -> ImpactEffect:
	var effets: Array[ImpactEffect] = []

	for type in mixture.get_types_presents():
		if type == Ingredient.TypeAlchimie.REBOND:
			continue
		var effet_par_type: Mixture.EffetParType = mixture.get_effet(type)
		effets.append(_creer_impact(type, effet_par_type))

	var composite := ImpactComposite.new()
	composite.effets = effets

	return composite


static func extraire_bounce_count(mixture: Mixture) -> int:
	if mixture == null:
		return 0
	var effet_rebond: Mixture.EffetParType = mixture.get_effet(Ingredient.TypeAlchimie.REBOND)
	if effet_rebond == null:
		return 0
	return roundi(effet_rebond.degats)


static func _creer_impact(type: Ingredient.TypeAlchimie, effet_par_type: Mixture.EffetParType) -> ImpactEffect:
	if type == Ingredient.TypeAlchimie.SOIN:
		var impact_heal := ImpactHeal.new()
		impact_heal.amount = abs(effet_par_type.degats)
		return impact_heal

	if type == Ingredient.TypeAlchimie.ATTRACTION:
		var impact_pull := ImpactPull.new()
		impact_pull.radius = effet_par_type.zone * ZONE_SCALE
		impact_pull.duration = effet_par_type.duree
		impact_pull.pull_strength = effet_par_type.degats
		return impact_pull

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
