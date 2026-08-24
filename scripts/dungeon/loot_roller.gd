class_name LootRoller
extends RefCounted


const CHEST_TRAP_CHANCE: float = 0.05
const CHEST_WEAPON_PART_CHANCE: float = 0.65
const CHEST_CURRENCY_CHANCE: float = 0.5
const CHEST_CURRENCY_COINS_MIN: int = 3
const CHEST_CURRENCY_COINS_MAX: int = 6
const CHEST_LOOT_MIN_RADIUS: float = 60.0
const CHEST_LOOT_SCATTER_RADIUS: float = 140.0

const CURRENCY_PER_COIN: int = 5
const CURRENCY_SCATTER_RADIUS: float = 40.0

func random_position_near(center: Vector2, min_radius: float, max_radius: float) -> Vector2:
	var angle: float = randf_range(0.0, TAU)
	var distance: float = randf_range(min_radius, max_radius)
	return center + Vector2(cos(angle), sin(angle)) * distance

func currency_coin_positions(amount: int, center: Vector2) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if amount <= 0:
		return positions
	var coin_count: int = maxi(1, amount / CURRENCY_PER_COIN)
	for i in coin_count:
		positions.append(random_position_near(center, 0.0, CURRENCY_SCATTER_RADIUS))
	return positions

func roll_chest_contents(room_data: Dictionary, room_world_rect: Rect2, enemy_table_path: String, weapon_part_table_path: String) -> Dictionary:
	var chest_position: Vector2 = room_world_rect.get_center()
	if randf() < CHEST_TRAP_CHANCE:
		var enemy_table: SpawnTable = load(enemy_table_path) as SpawnTable
		return {
			"is_trap": true,
			"enemy_scene_path": enemy_table.pick_one(),
			"position": random_position_near(chest_position, CHEST_LOOT_MIN_RADIUS, CHEST_LOOT_SCATTER_RADIUS),
		}

	var contents: Dictionary = {
		"is_trap": false,
		"weapon_part_path": "",
		"currency": 0,
		"position": random_position_near(chest_position, CHEST_LOOT_MIN_RADIUS, CHEST_LOOT_SCATTER_RADIUS),
	}
	if randf() < CHEST_WEAPON_PART_CHANCE:
		var weapon_part_table: SpawnTable = load(weapon_part_table_path) as SpawnTable
		contents["weapon_part_path"] = weapon_part_table.pick_one()
	if randf() < CHEST_CURRENCY_CHANCE:
		contents["currency"] = randi_range(CHEST_CURRENCY_COINS_MIN, CHEST_CURRENCY_COINS_MAX) * CURRENCY_PER_COIN
	return contents
