extends RefCounted

# The 4 launch courts as plain data. Params are multipliers on the sim's
# neutral surface (1.0 = neutral). `color` is a placeholder court colour hex
# for later visual differentiation (applied by the view in a later sub-project).

const COURTS := [
	{ "id": "hard", "name": "Hard Court", "color": "2d6a4f", "bounce_speed": 1.0, "bounce_height": 1.0, "move_response": 1.0, "move_speed": 1.0 },
	{ "id": "clay", "name": "Clay", "color": "b5651d", "bounce_speed": 0.85, "bounce_height": 1.2, "move_response": 1.0, "move_speed": 1.0 },
	{ "id": "grass", "name": "Grass", "color": "3a7d44", "bounce_speed": 1.0, "bounce_height": 0.7, "move_response": 1.0, "move_speed": 1.0 },
	{ "id": "ice", "name": "Ice Rink", "color": "a8dadc", "bounce_speed": 1.0, "bounce_height": 1.0, "move_response": 0.15, "move_speed": 1.2 },
]

static func by_id(id: String) -> Dictionary:
	for c in COURTS:
		if c.id == id:
			return c
	return COURTS[0]

static func apply_to(sim, court: Dictionary) -> void:
	sim.bounce_speed = court.bounce_speed
	sim.bounce_height = court.bounce_height
	sim.move_response = court.move_response
	sim.move_speed = court.move_speed
