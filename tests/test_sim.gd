extends "res://tests/test_base.gd"

const CourtSim := preload("res://src/sim/court_sim.gd")
const InputFrame := preload("res://src/sim/input_frame.gd")

func _idle() -> Array:
	return [InputFrame.new(), InputFrame.new()]

func _tick_n(sim, n: int) -> void:
	for i in n:
		sim.tick(_idle())

func test_ball_waits_for_serve() -> void:
	var sim := CourtSim.new()
	_tick_n(sim, 60)
	check(sim.ball.height == CourtSim.SERVE_HEIGHT, "ball should hover until first hit")
	check(not sim.ball.in_play, "ball should not be in play before serve")

func test_ball_falls_and_bounces() -> void:
	var sim := CourtSim.new()
	sim.ball.in_play = true
	sim.ball.height = 2.0
	var start := sim.ball.height
	_tick_n(sim, 10)
	check(sim.ball.height < start, "gravity should pull the ball down")
	_tick_n(sim, 40)
	check(sim.ball.bounce_count >= 1, "ball should have bounced")

func test_bounce_loses_energy() -> void:
	var sim := CourtSim.new()
	sim.ball.in_play = true
	sim.ball.height = 2.0
	var v_after := 0.0
	for i in 300:
		sim.tick(_idle())
		if sim.ball.bounce_count == 1:
			v_after = sim.ball.v_height
			break
	check(v_after > 0.0, "ball should move up after a bounce")
	check(v_after < sqrt(2.0 * CourtSim.GRAVITY * 2.0), "bounce should lose energy")

func test_dead_ball_resets() -> void:
	var sim := CourtSim.new()
	sim.ball.in_play = true
	sim.ball.height = 2.0
	_tick_n(sim, 600)
	check(not sim.ball.in_play, "ball should reset to serve state after bouncing out")
