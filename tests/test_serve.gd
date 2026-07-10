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
