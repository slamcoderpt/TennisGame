extends "res://tests/test_base.gd"

const CourtSim := preload("res://src/sim/court_sim.gd")
const InputFrame := preload("res://src/sim/input_frame.gd")

func _flying_ball(sim) -> void:
	sim.last_hitter = 1
	sim.is_serve = false
	sim.ball.in_play = true
	sim.ball.pos = Vector2(0, -5)
	sim.ball.vel = Vector2(8, 0)
	sim.ball.height = 1.0
	sim.ball.v_height = 0.0

func _tick_until_bounce(sim) -> void:
	for i in 120:
		sim.tick([InputFrame.new(), InputFrame.new()])
		if sim.ball.bounce_count >= 1:
			return

func test_surface_defaults_are_neutral() -> void:
	var sim := CourtSim.new()
	check(sim.bounce_speed == 1.0 and sim.bounce_height == 1.0, "bounce params default neutral")
	check(sim.move_response == 1.0 and sim.move_speed == 1.0, "movement params default neutral")

func test_clay_slows_and_raises_the_bounce() -> void:
	var hard := CourtSim.new()
	_flying_ball(hard)
	_tick_until_bounce(hard)
	var clay := CourtSim.new()
	clay.bounce_speed = 0.85
	clay.bounce_height = 1.2
	_flying_ball(clay)
	_tick_until_bounce(clay)
	check(clay.ball.vel.length() < hard.ball.vel.length(), "clay keeps less horizontal speed across the bounce")
	check(clay.ball.v_height > hard.ball.v_height, "clay bounces higher")

func test_grass_bounces_lower() -> void:
	var hard := CourtSim.new()
	_flying_ball(hard)
	_tick_until_bounce(hard)
	var grass := CourtSim.new()
	grass.bounce_height = 0.7
	_flying_ball(grass)
	_tick_until_bounce(grass)
	check(grass.ball.v_height < hard.ball.v_height, "grass bounces lower")

func test_ice_is_slow_to_accelerate() -> void:
	var hard := CourtSim.new()
	var ice := CourtSim.new()
	ice.move_response = 0.15
	ice.move_speed = 1.2
	var f := InputFrame.new()
	f.move = Vector2(1, 0)
	hard.tick([f, InputFrame.new()])
	ice.tick([f, InputFrame.new()])
	var v_hard: float = hard.players[0].move_vel.x
	var v_ice: float = ice.players[0].move_vel.x
	check(v_ice < v_hard, "on ice the first tick of movement is slower (slow to get going)")

func test_ice_is_slow_to_reverse() -> void:
	var hard := CourtSim.new()
	var ice := CourtSim.new()
	ice.move_response = 0.15
	ice.move_speed = 1.2
	var right := InputFrame.new()
	right.move = Vector2(1, 0)
	for i in 30:
		hard.tick([right, InputFrame.new()])
		ice.tick([right, InputFrame.new()])
	var left := InputFrame.new()
	left.move = Vector2(-1, 0)
	hard.tick([left, InputFrame.new()])
	ice.tick([left, InputFrame.new()])
	var v_hard: float = hard.players[0].move_vel.x
	var v_ice: float = ice.players[0].move_vel.x
	check(v_hard < 0.0, "on hard court the reversal is instant")
	check(v_ice > 0.0, "on ice the player keeps drifting the old way for a while")

func test_ice_top_speed_is_higher() -> void:
	var ice := CourtSim.new()
	ice.move_response = 0.15
	ice.move_speed = 1.2
	var f := InputFrame.new()
	f.move = Vector2(1, 0)
	for i in 90:
		ice.tick([f, InputFrame.new()])
	var v: float = ice.players[0].move_vel.x
	check(v > CourtSim.PLAYER_SPEED, "ice top speed exceeds the hard-court max")
