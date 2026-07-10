extends "res://tests/test_base.gd"

const Roster := preload("res://src/data/roster.gd")
const CourtSim := preload("res://src/sim/court_sim.gd")

func test_roster_has_six_characters() -> void:
	check(Roster.ROSTER.size() == 6, "roster has 6 characters")

func test_by_id_finds_the_character() -> void:
	check(Roster.by_id("speedster").speed == 1.25, "speedster has speed 1.25")
	check(Roster.by_id("nope").id == "allrounder", "unknown id falls back to all-rounder")

func test_apply_to_copies_multipliers() -> void:
	var sim := CourtSim.new()
	Roster.apply_to(sim.players[0], Roster.by_id("defender"))
	check(sim.players[0].reach == 1.3, "defender reach applied")
	check(sim.players[0].power == 0.8, "defender power applied")
	check(sim.players[0].speed == 0.95, "defender speed applied")
	check(sim.players[0].charge_rate == 1.0, "defender charge_rate applied")
