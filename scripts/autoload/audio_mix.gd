class_name AudioMix
extends RefCounted

const DEFAULT_GAIN_DB: float = 0.0
const DEFAULT_PITCH_JITTER: float = 0.05
const DEFAULT_MIN_INTERVAL: float = 0.03

const MUSIC_GAIN_DB: Dictionary = {
	"cave": -5.0,
	"crypt": -6.2,
	"alchemy": -5.4,
	"hub": -6.0,
	"boss": -4.0,
}

const UI_KEYS: Array[String] = [
	"ui_click", "ui_hover", "ui_toggle", "ui_error", "station_open",
]

const SFX_GAIN_DB: Dictionary = {
	"fire_water": 1.0,
	"fire_mixture": 1.0,
	"weapon_empty": -3.0,
	"dash": -2.0,

	"hit": 2.0,
	"death": 3.0,
	"low_health": -1.0,

	"hit_enemy": -2.0,
	"impact_water": 2.0,
	"impact_mixture": 0.0,
	"vial_break": -4.0,

	"enemy_attack_melee": -6.0,
	"enemy_attack_ranged": -5.2,
	"enemy_attack_ranged_gunner": -5.4,
	"enemy_attack_ranged_sniper": -5.4,
	"enemy_attack_ranged_turret": -5.7,
	"enemy_attack_ranged_artillery": -6.0,
	"boss_attack_ranged": -3.0,

	"cry_melee_base": -11.0,
	"cry_melee_brute": -11.0,
	"cry_melee_swarm": -11.0,
	"cry_melee_splitter": -11.0,
	"cry_melee_splitter_shard": -12.0,
	"cry_ranged_base": -11.0,
	"cry_ranged_gunner": -11.0,
	"cry_ranged_sniper": -11.0,
	"cry_erratic_base": -11.0,
	"cry_erratic_bomber": -11.0,
	"cry_erratic_swift": -11.0,
	"cry_boss": 0.0,
	"mob_ambient_1": -12.0,
	"mob_ambient_2": -12.0,

	"footstep_alchemy": -10.0,
	"footstep_cave": -10.0,
	"footstep_crypt": -10.0,

	"door_open": -7.0,
	"door_close": -7.0,
	"chest_open": -3.0,
	"station_open": 0.0,
	"pickup_currency": -4.0,
	"pickup_ingredient": 2.0,
	"weapon_equip": -3.0,
	"craft_success": -5.0,

	"boss_phase": 2.0,
	"boss_death": 2.0,
	"floor_advance": 0.0,
	"room_clear": 0.0,

	"ui_click": -4.0,
	"ui_hover": -10.0,
	"ui_toggle": -5.0,
	"ui_error": -2.0,
}

const SFX_PITCH_JITTER: Dictionary = {
	"fire_water": 0.07,
	"fire_mixture": 0.07,
	"footstep_alchemy": 0.10,
	"footstep_cave": 0.10,
	"footstep_crypt": 0.10,
	"hit": 0.08,
	"hit_enemy": 0.08,
	"impact_water": 0.08,
	"impact_mixture": 0.08,
	"dash": 0.06,
	"enemy_attack_melee": 0.06,
	"enemy_attack_ranged": 0.06,
	"enemy_attack_ranged_gunner": 0.06,
	"enemy_attack_ranged_sniper": 0.06,
	"enemy_attack_ranged_turret": 0.06,
	"enemy_attack_ranged_artillery": 0.06,
	"boss_attack_ranged": 0.04,
	"cry_melee_base": 0.09,
	"cry_melee_brute": 0.09,
	"cry_melee_swarm": 0.09,
	"cry_melee_splitter": 0.09,
	"cry_melee_splitter_shard": 0.11,
	"cry_ranged_base": 0.09,
	"cry_ranged_gunner": 0.09,
	"cry_ranged_sniper": 0.09,
	"cry_erratic_base": 0.09,
	"cry_erratic_bomber": 0.09,
	"cry_erratic_swift": 0.09,
	"mob_ambient_1": 0.09,
	"mob_ambient_2": 0.09,
	"vial_break": 0.07,
	"pickup_currency": 0.04,
	"pickup_ingredient": 0.06,

	"ui_click": 0.0,
	"ui_hover": 0.0,
	"ui_toggle": 0.0,
	"ui_error": 0.0,
	"room_clear": 0.0,
	"craft_success": 0.0,
	"boss_phase": 0.0,
	"boss_death": 0.0,
	"floor_advance": 0.0,
	"low_health": 0.0,
	"death": 0.0,
	"cry_boss": 0.0,
}

const SFX_MIN_INTERVAL: Dictionary = {
	"cry_melee_base": 0.35,
	"cry_melee_brute": 0.35,
	"cry_melee_swarm": 0.35,
	"cry_melee_splitter": 0.35,
	"cry_melee_splitter_shard": 0.45,
	"cry_ranged_base": 0.35,
	"cry_ranged_gunner": 0.35,
	"cry_ranged_sniper": 0.35,
	"cry_erratic_base": 0.35,
	"cry_erratic_bomber": 0.35,
	"cry_erratic_swift": 0.35,
	"mob_ambient_1": 0.35,
	"mob_ambient_2": 0.35,
	"hit": 0.08,
	"hit_enemy": 0.05,
	"impact_water": 0.045,
	"impact_mixture": 0.045,
	"footstep_alchemy": 0.09,
	"footstep_cave": 0.09,
	"footstep_crypt": 0.09,
	"enemy_attack_melee": 0.05,
	"enemy_attack_ranged": 0.05,
	"enemy_attack_ranged_gunner": 0.05,
	"enemy_attack_ranged_sniper": 0.05,
	"enemy_attack_ranged_turret": 0.05,
	"enemy_attack_ranged_artillery": 0.05,
	"low_health": 1.0,
	"room_clear": 1.0,
}

const DUCK_KEYS: Dictionary = {
	"boss_phase": -7.0,
	"boss_death": -9.0,
	"room_clear": -6.0,
	"floor_advance": -6.0,
	"death": -9.0,
	"craft_success": -4.0,
}


static func gain_db(key: String) -> float:
	return SFX_GAIN_DB.get(key, DEFAULT_GAIN_DB)


static func music_gain_db(key: String) -> float:
	return MUSIC_GAIN_DB.get(key, DEFAULT_GAIN_DB)


static func pitch_jitter(key: String) -> float:
	return SFX_PITCH_JITTER.get(key, DEFAULT_PITCH_JITTER)


static func min_interval(key: String) -> float:
	return SFX_MIN_INTERVAL.get(key, DEFAULT_MIN_INTERVAL)


static func duck_db(key: String) -> float:
	return DUCK_KEYS.get(key, 0.0)


static func is_ui(key: String) -> bool:
	return key in UI_KEYS
