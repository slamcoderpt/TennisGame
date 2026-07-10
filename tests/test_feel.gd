extends "res://tests/test_base.gd"

const CourtSim := preload("res://src/sim/court_sim.gd")
const InputFrame := preload("res://src/sim/input_frame.gd")

func test_hit_count_increments_on_each_swing() -> void:
	var sim := CourtSim.new()
	check(sim.hit_count == 0, "hit_count starts at zero")
	var held := InputFrame.new()
	held.hit_held = true
	for i in 10:
		sim.tick([held, InputFrame.new()])       # build some charge first
	var rel := InputFrame.new()
	rel.hit_pressed = true
	sim.tick([rel, InputFrame.new()])            # release fires the swing
	check(sim.hit_count == 1, "a swing must increment hit_count")
	check(sim.hit_strength > 0.0, "hit_strength must record the (charged) shot power")
