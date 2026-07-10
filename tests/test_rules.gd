extends "res://tests/test_base.gd"

const CourtSim := preload("res://src/sim/court_sim.gd")
const InputFrame := preload("res://src/sim/input_frame.gd")

func _idle() -> Array:
	return [InputFrame.new(), InputFrame.new()]

func _tick_n(sim, n: int) -> void:
	for i in n:
		sim.tick(_idle())

func _rally_ball(sim, pos: Vector2, vel: Vector2, height: float, v_height := 0.0) -> void:
	# put the sim into a mid-rally state as if player 0 just hit the ball
	sim.last_hitter = 0
	sim.is_serve = false
	sim.ball.in_play = true
	sim.ball.pos = pos
	sim.ball.vel = vel
	sim.ball.height = height
	sim.ball.v_height = v_height

func test_double_bounce_wins_point() -> void:
	var sim := CourtSim.new()
	_rally_ball(sim, Vector2(0, 5), Vector2(0, 2), 1.0)
	_tick_n(sim, 90)
	check(sim.score.points[0] == 1, "double bounce on receiver side must score for the hitter")

func test_bounce_out_loses_point() -> void:
	var sim := CourtSim.new()
	_rally_ball(sim, Vector2(0, 5), Vector2(16, 4), 1.0)
	_tick_n(sim, 60)
	check(sim.score.points[1] == 1, "landing out must score for the opponent")

func test_receiver_must_let_serve_bounce() -> void:
	var sim := CourtSim.new()
	sim.players[1].pos = Vector2(0.0, 3.5)
	var frames := _idle()
	frames[0].hit_pressed = true
	frames[1].hit_pressed = true
	sim.tick(frames)
	check(sim.is_serve, "player 0 should have served")
	var pressing := _idle()
	pressing[1].hit_pressed = true
	for i in 200:
		sim.tick(pressing)
		if not sim.is_serve:
			break
		check(sim.ball.vel.y > 0.0, "serve must not be returnable before it bounces")

func test_serve_fault_gives_second_serve() -> void:
	var sim := CourtSim.new()
	var frames := _idle()
	frames[0].hit_pressed = true
	sim.tick(frames)
	# force the serve to land on the server's own side -> fault
	sim.ball.pos = Vector2(0, -4)
	sim.ball.vel = Vector2.ZERO
	sim.ball.height = 0.5
	sim.ball.v_height = 0.0
	_tick_n(sim, 30)
	check(sim.serve_faults == 1, "own-side landing on the serve must be a fault")
	check(sim.score.points[0] == 0 and sim.score.points[1] == 0, "a first fault must not score")
	_tick_n(sim, CourtSim.POINT_PAUSE_TICKS + 2)
	check(not sim.ball.in_play and sim.ball.pos.y < 0.0, "ball must re-hover on the server side for the second serve")

func test_double_fault_scores_for_receiver() -> void:
	var sim := CourtSim.new()
	for attempt in 2:
		var frames := _idle()
		frames[0].hit_pressed = true
		sim.tick(frames)
		sim.ball.pos = Vector2(0, -4)
		sim.ball.vel = Vector2.ZERO
		sim.ball.height = 0.5
		sim.ball.v_height = 0.0
		_tick_n(sim, 30 + CourtSim.POINT_PAUSE_TICKS)
	check(sim.score.points[1] == 1, "double fault must score for the receiver")
	check(sim.serve_faults == 0, "faults must reset after the point")

func test_server_alternates_each_game() -> void:
	var sim := CourtSim.new()
	for i in 4:
		sim._end_point(0, "")
	check(sim.server == 1, "server must alternate after a game ends")
	_tick_n(sim, CourtSim.POINT_PAUSE_TICKS + 2)
	check(sim.ball.pos.y > 0.0, "ball must hover on the new server's side")

func test_match_over_freezes_sim() -> void:
	var sim := CourtSim.new()
	for i in 12:
		sim._end_point(0, "")
	check(sim.score.match_winner == 0, "12 straight points must win the match")
	var frames := _idle()
	frames[0].move = Vector2(1, 0)
	var before: Vector2 = sim.players[0].pos
	sim.tick(frames)
	check(sim.players[0].pos == before, "sim must freeze after the match ends")

func test_net_blocks_low_ball() -> void:
	var sim := CourtSim.new()
	_rally_ball(sim, Vector2(0, -1), Vector2(0, 20), 0.4, 2.0)
	_tick_n(sim, 6)
	check(sim.ball.pos.y < 0.0, "low ball must be blocked by the net")
	check(sim.ball.vel.y < 0.0, "blocked ball must rebound")
	_tick_n(sim, 120)
	check(sim.score.points[1] == 1, "netted ball must cost the hitter the point")

func test_high_ball_clears_net() -> void:
	var sim := CourtSim.new()
	_rally_ball(sim, Vector2(0, -1), Vector2(0, 20), 2.0)
	_tick_n(sim, 6)
	check(sim.ball.pos.y > 0.0, "high ball must pass over the net")
