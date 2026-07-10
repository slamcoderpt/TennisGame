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

func test_player_moves_and_is_clamped() -> void:
	var sim := CourtSim.new()
	var frames := _idle()
	frames[0].move = Vector2(0, 1)
	for i in 600:
		sim.tick(frames)
	check(sim.players[0].pos.y == -0.5, "bottom player must stop before the net")
	frames[0].move = Vector2(-1, 0)
	for i in 600:
		sim.tick(frames)
	check(sim.players[0].pos.x == -CourtSim.HALF_WIDTH, "player must stop at the side line")

func test_diagonal_not_faster() -> void:
	var sim := CourtSim.new()
	var frames := _idle()
	frames[0].move = Vector2(1, 1)
	sim.tick(frames)
	var moved: float = sim.players[0].pos.distance_to(Vector2(0, -9))
	check(absf(moved - CourtSim.PLAYER_SPEED * CourtSim.TICK) < 0.001, "diagonal speed must equal straight speed")

func test_serve_hit_sends_ball_to_far_side() -> void:
	var sim := CourtSim.new()
	var frames := _idle()
	frames[0].hit_pressed = true
	sim.tick(frames)
	check(sim.ball.in_play, "hit should put ball in play")
	check(sim.ball.vel.y > 0.0, "ball should travel toward the far side")
	check(sim.ball.v_height > 0.0, "shot should launch upward")
	_tick_n(sim, 90)
	check(sim.ball.pos.y > 0.0, "ball should cross the net line within 1.5s")

func test_cannot_hit_out_of_reach() -> void:
	var sim := CourtSim.new()
	sim.players[0].pos = Vector2(3.5, -11.0)
	var frames := _idle()
	frames[0].hit_pressed = true
	sim.tick(frames)
	check(not sim.ball.in_play, "out-of-reach hit must do nothing")

func test_cannot_hit_own_outgoing_ball() -> void:
	var sim := CourtSim.new()
	var frames := _idle()
	frames[0].hit_pressed = true
	sim.tick(frames)
	var vel_after_serve: Vector2 = sim.ball.vel
	sim.tick(frames)
	check(sim.ball.vel == vel_after_serve, "own outgoing ball must not be re-hit")

func test_aim_follows_stick() -> void:
	var sim := CourtSim.new()
	var frames := _idle()
	frames[0].hit_pressed = true
	frames[0].move = Vector2(-1, 0)
	sim.tick(frames)
	check(sim.ball.vel.x < 0.0, "stick held left should aim the shot left")
