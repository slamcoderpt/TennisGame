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
	# an in-play rally ball far from the player must not be returnable
	sim.last_hitter = 1
	sim.is_serve = false
	sim.ball.in_play = true
	sim.ball.pos = Vector2(3.5, 5.0)
	sim.ball.vel = Vector2(0, -6)
	sim.ball.height = 1.0
	sim.players[0].pos = Vector2(-3.5, -11.0)
	var frames := _idle()
	frames[0].hit_pressed = true
	sim.tick(frames)
	check(sim.ball.vel.y < 0.0, "an out-of-reach rally ball must not be returned")

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

func _scripted(i: int) -> Array:
	var p0 := InputFrame.new()
	p0.move = Vector2(sin(i * 0.05), cos(i * 0.07))
	p0.hit_pressed = i % 30 == 0
	var p1 := InputFrame.new()
	p1.move = Vector2(cos(i * 0.03), 0.0)
	p1.hit_pressed = i % 45 == 0
	return [p0, p1]

func test_determinism() -> void:
	var a := CourtSim.new()
	var b := CourtSim.new()
	for i in 600:
		a.tick(_scripted(i))
		b.tick(_scripted(i))
	check(a.ball.pos == b.ball.pos and a.ball.height == b.ball.height, "ball state must match exactly")
	check(a.players[0].pos == b.players[0].pos and a.players[1].pos == b.players[1].pos, "player state must match exactly")

func test_hit_buffer_forgives_early_press() -> void:
	var sim := CourtSim.new()
	sim.players[0].pos = Vector2(0.0, -9.0)
	sim.ball.in_play = true
	sim.ball.pos = Vector2(0.0, -6.5)      # ~2.5 units away — just out of REACH
	sim.ball.vel = Vector2(0.0, -12.0)     # approaching the near player
	sim.ball.height = 1.0
	sim.ball.v_height = 0.0
	var frames := _idle()
	frames[0].hit_pressed = true
	sim.tick(frames)                       # press while still out of reach
	check(sim.ball.vel.y < 0.0, "ball should not be hit yet on the early press tick")
	for i in 6:
		sim.tick(_idle())                  # no new press; the buffered swing should connect
	check(sim.ball.vel.y > 0.0, "buffered swing should connect as the ball enters reach")

func test_hit_buffer_expires() -> void:
	var sim := CourtSim.new()
	sim.players[0].pos = Vector2(0.0, -9.0)
	sim.ball.in_play = true
	sim.ball.pos = Vector2(0.0, -6.6)      # out of REACH, approaching very slowly
	sim.ball.vel = Vector2(0.0, -1.5)      # reaches the player only long after the buffer expires
	sim.ball.height = 1.0
	sim.ball.v_height = 4.0                # stays airborne past the assertion, no early bounce
	var frames := _idle()
	frames[0].hit_pressed = true
	sim.tick(frames)
	for i in 18:
		sim.tick(_idle())                  # buffer (8 ticks) expires before the ball arrives
	check(sim.ball.vel.y < 0.0, "an expired buffer must not hit a ball that arrives late")
