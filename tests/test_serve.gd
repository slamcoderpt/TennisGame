extends "res://tests/test_base.gd"

const CourtSim := preload("res://src/sim/court_sim.gd")
const InputFrame := preload("res://src/sim/input_frame.gd")

func _held() -> InputFrame:
	var f := InputFrame.new()
	f.hit_held = true
	return f

func test_serve_starts_on_a_deuce_or_ad_spot() -> void:
	var sim := CourtSim.new()
	check(absf(sim.ball.pos.x) == CourtSim.SERVE_X, "serve ball must start offset to a deuce/ad spot")
	check(sim.ball.height == CourtSim.SERVE_HEIGHT, "serve ball rests at the in-hand height")

func test_serve_side_alternates_each_point() -> void:
	var sim := CourtSim.new()
	var first_x: float = sim.ball.pos.x
	sim.score.points = [1, 0]        # one point played -> next serve is the other court
	sim.reset_for_serve()
	check(sim.ball.pos.x == -first_x, "the serve spot must switch sides after a point")

func test_center_server_can_still_reach_the_serve() -> void:
	var sim := CourtSim.new()
	var dist: float = sim.ball.pos.distance_to(sim.players[0].pos)
	check(dist <= CourtSim.REACH, "center server must reach the offset serve spot (dist=%s)" % dist)

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
	# hold and never release: the toss falls to the ground untouched -> fault
	for i in 120:
		sim.tick([_held(), InputFrame.new()])
	check(sim.serve_faults >= 1, "a toss that lands untouched must be a serve fault")

func _toss_and_release_at(sim, hold_ticks: int) -> void:
	for i in hold_ticks:
		sim.tick([_held(), InputFrame.new()])
	var rel := InputFrame.new()
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

func test_serve_aims_cross_court() -> void:
	var sim := CourtSim.new()
	var serve_x: float = sim.ball.pos.x
	_toss_and_release_at(sim, 24)
	check(sim.ball.in_play, "serve should be live")
	check(signf(sim.ball.vel.x) == -signf(serve_x), "the serve must travel cross-court (toward the opposite side)")

func test_tap_serve_still_works() -> void:
	var sim := CourtSim.new()
	var f := InputFrame.new()
	f.hit_pressed = true
	sim.tick([f, InputFrame.new()])
	check(sim.ball.in_play, "a plain tap must still serve the ball")
	check(sim.ball.vel.y > 0.0, "the tap serve travels to the far side")
	check(sim.is_serve, "the tap serve is flagged as a serve")
