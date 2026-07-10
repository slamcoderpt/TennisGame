extends "res://tests/test_base.gd"

const CourtSim := preload("res://src/sim/court_sim.gd")
const InputFrame := preload("res://src/sim/input_frame.gd")

func _held() -> InputFrame:
	var f := InputFrame.new()
	f.hit_held = true
	return f

func test_serve_starts_in_hand_at_the_server() -> void:
	var sim := CourtSim.new()
	check(sim.ball.pos == sim.players[sim.server].pos, "the serve ball starts in the server's hand")
	check(sim.ball.height == CourtSim.SERVE_HEIGHT, "serve ball rests at the in-hand height")
	check(not sim.ball.in_play, "serve ball is not in play until struck")

func test_serve_ball_follows_the_hand() -> void:
	var sim := CourtSim.new()
	var move := InputFrame.new()
	move.move = Vector2(-1, 0)          # walk left while the ball is in hand (not holding hit)
	for i in 20:
		sim.tick([move, InputFrame.new()])
	check(sim.players[0].pos.x < 0.0, "the server moved left")
	check(sim.ball.pos == sim.players[0].pos, "the in-hand ball follows the server")

func test_toss_rises_then_falls() -> void:
	var sim := CourtSim.new()
	var start: float = sim.ball.height
	var peak := start
	for i in 60:
		sim.tick([_held(), InputFrame.new()])
		peak = maxf(peak, sim.ball.height)
	check(peak > start + 0.5, "the toss must rise well above the rest height")
	check(sim.ball.height < peak, "the toss must come back down from its peak")

func test_missed_toss_is_a_fault() -> void:
	var sim := CourtSim.new()
	for i in 120:
		sim.tick([_held(), InputFrame.new()])
	check(sim.serve_faults >= 1, "a toss that lands untouched must be a serve fault")

func _toss_and_release_at(sim, hold_ticks: int, stick := Vector2.ZERO) -> void:
	for i in hold_ticks:
		var h := _held()
		h.move = stick
		sim.tick([h, InputFrame.new()])
	var rel := InputFrame.new()
	rel.move = stick
	rel.hit_pressed = true
	sim.tick([rel, InputFrame.new()])

func test_timing_near_apex_serves_faster() -> void:
	var good := CourtSim.new()
	_toss_and_release_at(good, 24)
	var good_speed: float = good.ball.vel.length()
	var early := CourtSim.new()
	_toss_and_release_at(early, 3)
	var early_speed: float = early.ball.vel.length()
	check(good.ball.in_play, "a well-timed toss must produce a live serve")
	check(good_speed > early_speed + 1.0, "releasing near the apex must serve faster than an early release")

func test_serve_speed_follows_toss_timing_not_hold_time() -> void:
	var apex := CourtSim.new()
	_toss_and_release_at(apex, 24)
	var late := CourtSim.new()
	_toss_and_release_at(late, 44)
	check(apex.ball.in_play and late.ball.in_play, "both serves should be live")
	check(apex.ball.vel.length() > late.ball.vel.length() + 1.0, "apex timing must serve faster than a late (longer-held) release")

func test_serve_aims_by_stick() -> void:
	var left := CourtSim.new()
	_toss_and_release_at(left, 24, Vector2(-1, 0))
	check(left.ball.in_play and left.ball.vel.x < 0.0, "stick left must serve to the left")
	var right := CourtSim.new()
	_toss_and_release_at(right, 24, Vector2(1, 0))
	check(right.ball.in_play and right.ball.vel.x > 0.0, "stick right must serve to the right")

func test_tap_serve_still_works() -> void:
	var sim := CourtSim.new()
	var f := InputFrame.new()
	f.hit_pressed = true
	sim.tick([f, InputFrame.new()])
	check(sim.ball.in_play, "a plain tap must still serve the ball")
	check(sim.ball.vel.y > 0.0, "the tap serve travels to the far side")
	check(sim.is_serve, "the tap serve is flagged as a serve")
