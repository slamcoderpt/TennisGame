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
