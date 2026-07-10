extends RefCounted

# The 6 launch archetypes as plain data. Stats are multipliers on the sim's
# baseline (1.0 = baseline). `tint` is a placeholder colour hex for later visual
# differentiation (applied by the view in a later sub-project).

const ROSTER := [
	{ "id": "allrounder", "name": "All-Rounder", "tint": "457b9d", "speed": 1.0, "power": 1.0, "charge_rate": 1.0, "reach": 1.0 },
	{ "id": "speedster", "name": "Speedster", "tint": "2a9d8f", "speed": 1.25, "power": 0.8, "charge_rate": 1.0, "reach": 0.95 },
	{ "id": "power", "name": "Power Hitter", "tint": "e63946", "speed": 0.85, "power": 1.3, "charge_rate": 0.9, "reach": 1.0 },
	{ "id": "charger", "name": "Charger", "tint": "f4a261", "speed": 1.0, "power": 1.0, "charge_rate": 1.4, "reach": 0.85 },
	{ "id": "defender", "name": "Defender", "tint": "8ecae6", "speed": 0.95, "power": 0.8, "charge_rate": 1.0, "reach": 1.3 },
	{ "id": "wildcard", "name": "Wildcard", "tint": "b5179e", "speed": 1.25, "power": 1.25, "charge_rate": 0.7, "reach": 0.75 },
]

static func by_id(id: String) -> Dictionary:
	for c in ROSTER:
		if c.id == id:
			return c
	return ROSTER[0]

static func apply_to(player, character: Dictionary) -> void:
	player.speed = character.speed
	player.power = character.power
	player.charge_rate = character.charge_rate
	player.reach = character.reach
