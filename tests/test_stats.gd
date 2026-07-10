extends "res://tests/test_base.gd"

const CourtSim := preload("res://src/sim/court_sim.gd")
const InputFrame := preload("res://src/sim/input_frame.gd")

# An in-play rally ball `dist` units in front of player 0, incoming and reachable.
func _rally_ball(sim, dist: float) -> void:
	sim.last_hitter = 1
	sim.is_serve = false
	sim.ball.in_play = true
	sim.ball.pos = Vector2(0, -9.0 + dist)
	sim.ball.vel = Vector2(0, -6)
	sim.ball.height = 1.0
	sim.players[0].pos = Vector2(0, -9.0)

func test_default_multipliers_are_one() -> void:
	var sim := CourtSim.new()
	var p = sim.players[0]
	check(p.speed == 1.0 and p.power == 1.0 and p.charge_rate == 1.0 and p.reach == 1.0, "stats default to 1.0")

func test_speed_multiplier_moves_faster() -> void:
	var slow := CourtSim.new()
	var fast := CourtSim.new()
	fast.players[0].speed = 1.5
	var f := InputFrame.new()
	f.move = Vector2(1, 0)
	slow.tick([f, InputFrame.new()])
	fast.tick([f, InputFrame.new()])
	var d_slow: float = slow.players[0].pos.distance_to(Vector2(0, -9))
	var d_fast: float = fast.players[0].pos.distance_to(Vector2(0, -9))
	check(d_fast > d_slow, "higher speed moves farther per tick")

func test_power_multiplier_hits_harder() -> void:
	var weak := CourtSim.new()
	_rally_ball(weak, 0.0)
	weak.players[0].power = 1.0
	weak._try_hit(0, InputFrame.new())
	var s1: float = weak.ball.vel.length()
	var strong := CourtSim.new()
	_rally_ball(strong, 0.0)
	strong.players[0].power = 1.3
	strong._try_hit(0, InputFrame.new())
	var s2: float = strong.ball.vel.length()
	check(s2 > s1 + 1.0, "higher power sends the ball faster")

func test_reach_multiplier_extends_reach() -> void:
	var base := CourtSim.new()
	_rally_ball(base, 2.3)
	base.players[0].reach = 1.0
	check(not base._try_hit(0, InputFrame.new()), "baseline reach cannot hit a ball 2.3 away")
	var reachy := CourtSim.new()
	_rally_ball(reachy, 2.3)
	reachy.players[0].reach = 1.3
	check(reachy._try_hit(0, InputFrame.new()), "extended reach hits the 2.3-away ball")

func test_charge_rate_fills_faster() -> void:
	var base := CourtSim.new()
	var fast := CourtSim.new()
	fast.players[0].charge_rate = 2.0
	var h := InputFrame.new()
	h.hit_held = true
	for i in 5:
		base.tick([h, InputFrame.new()])
		fast.tick([h, InputFrame.new()])
	check(fast.players[0].charge > base.players[0].charge, "higher charge_rate fills the meter faster")
