extends "res://tests/test_base.gd"

const Courts := preload("res://src/data/courts.gd")
const CourtSim := preload("res://src/sim/court_sim.gd")

func test_courts_has_four() -> void:
	check(Courts.COURTS.size() == 4, "there are 4 launch courts")

func test_by_id_finds_and_falls_back() -> void:
	check(Courts.by_id("clay").bounce_speed == 0.85, "clay slows the bounce")
	check(Courts.by_id("nope").id == "hard", "unknown id falls back to hard")

func test_apply_to_copies_params() -> void:
	var sim := CourtSim.new()
	Courts.apply_to(sim, Courts.by_id("ice"))
	check(sim.move_response == 0.15, "ice move_response applied")
	check(sim.move_speed == 1.2, "ice move_speed applied")
	check(sim.bounce_speed == 1.0 and sim.bounce_height == 1.0, "ice ball params stay neutral")
