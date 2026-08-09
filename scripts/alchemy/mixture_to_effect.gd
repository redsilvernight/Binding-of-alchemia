class_name MixtureToEffect
extends RefCounted

static func convertir(mixture: Mixture) -> ImpactEffect:
	var effets: Array[ImpactEffect] = []

	for type in mixture.get_types_presents():
		var effet_par_type: Mixture.EffetParType = mixture.get_effet(type)
		effets.append(_creer_impact(effet_par_type))

	var composite := ImpactComposite.new()
	composite.effets = effets

	return composite


static func _creer_impact(effet_par_type: Mixture.EffetParType) -> ImpactEffect:
	if effet_par_type.zone > 0.0:
		var impact_area := ImpactArea.new()
		impact_area.damage = effet_par_type.degats
		impact_area.radius = effet_par_type.zone
		return impact_area

	var impact_damage := ImpactDamage.new()
	impact_damage.damage = effet_par_type.degats
	return impact_damage
