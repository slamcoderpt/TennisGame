extends "res://tests/test_base.gd"

const CourtSim := preload("res://src/sim/court_sim.gd")
const InputFrame := preload("res://src/sim/input_frame.gd")

func _serve_tap(sim) -> void:
	var f := InputFrame.new()
	f.hit_pressed = true
	sim.tick([f, InputFrame.new()])

func _rally_ball(sim) -> void:
	sim.last_hitter = 1
	sim.is_serve = false
	sim.ball.in_play = true
	sim.ball.pos = Vector2(0, -9)
	sim.ball.vel = Vector2(0, -6)
	sim.ball.height = 1.0
	sim.players[0].pos = Vector2(0, -9)

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
	_rally_ball(weak)
	weak.meter[0] = 1.0
	weak.players[0].charge = 0.0
	weak._try_hit(0, InputFrame.new())
	check(weak.ball.swerve == 0.0, "an uncharged shot must not fire the special even with a full meter")
	check(weak.meter[0] == 1.0, "meter must not drain without a special")

	var strong := CourtSim.new()
	_rally_ball(strong)
	strong.meter[0] = 1.0
	strong.players[0].charge = 1.0
	strong._try_hit(0, InputFrame.new())
	check(strong.ball.swerve != 0.0, "a full-charge shot on a full meter must fire a swerving special")
	check(strong.meter[0] == 0.0, "the special must drain the meter")

func test_special_ball_curves() -> void:
	var sim := CourtSim.new()
	_rally_ball(sim)
	sim.meter[0] = 1.0
	sim.players[0].charge = 1.0
	sim._try_hit(0, InputFrame.new())
	var vx0: float = sim.ball.vel.x
	for i in 10:
		sim.tick([InputFrame.new(), InputFrame.new()])
	check(sim.ball.vel.x != vx0, "a special ball's horizontal velocity must curve over time")
