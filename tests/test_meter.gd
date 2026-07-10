extends "res://tests/test_base.gd"

const CourtSim := preload("res://src/sim/court_sim.gd")
const InputFrame := preload("res://src/sim/input_frame.gd")

func _serve_tap(sim) -> void:
	var f := InputFrame.new()
	f.hit_pressed = true
	sim.tick([f, InputFrame.new()])

func test_meter_fills_on_hit() -> void:
	var sim := CourtSim.new()
	_serve_tap(sim)
	check(sim.meter[0] > 0.0, "hitting the ball must add to the hitter's meter")

func test_meter_persists_across_points() -> void:
	var sim := CourtSim.new()
	sim.meter[0] = 0.5
	sim._end_point(0, "")
	check(sim.meter[0] >= 0.5, "the meter must persist across points (and gain on a won point)")

func test_special_needs_full_meter_and_full_charge() -> void:
	var weak := CourtSim.new()
	weak.meter[0] = 1.0
	var tap := InputFrame.new()
	tap.hit_pressed = true
	weak.tick([tap, InputFrame.new()])
	check(weak.ball.swerve == 0.0, "a tap must not spend the special even with a full meter")
	check(weak.meter[0] == 1.0, "meter must not drain without a special")

	var strong := CourtSim.new()
	strong.meter[0] = 1.0
	for i in 45:
		var h := InputFrame.new()
		h.hit_held = true
		strong.tick([h, InputFrame.new()])
	var rel := InputFrame.new()
	rel.hit_pressed = true
	strong.tick([rel, InputFrame.new()])
	check(strong.ball.swerve != 0.0, "a full-charge swing on a full meter must fire a swerving special")
	check(strong.meter[0] == 0.0, "the special must drain the meter")

func test_special_ball_curves() -> void:
	var sim := CourtSim.new()
	sim.meter[0] = 1.0
	for i in 45:
		var h := InputFrame.new()
		h.hit_held = true
		sim.tick([h, InputFrame.new()])
	var rel := InputFrame.new()
	rel.hit_pressed = true
	sim.tick([rel, InputFrame.new()])
	var vx0: float = sim.ball.vel.x
	for i in 10:
		sim.tick([InputFrame.new(), InputFrame.new()])
	check(sim.ball.vel.x != vx0, "a special ball's horizontal velocity must curve over time")
