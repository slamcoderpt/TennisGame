extends "res://tests/test_base.gd"

const CourtSim := preload("res://src/sim/court_sim.gd")
const InputFrame := preload("res://src/sim/input_frame.gd")

func _held() -> InputFrame:
	var f := InputFrame.new()
	f.hit_held = true
	return f

func test_charge_builds_while_held() -> void:
	var sim := CourtSim.new()
	for i in 20:
		sim.tick([_held(), InputFrame.new()])
	check(sim.players[0].charge > 0.0, "charge must build while the hit is held")

func test_charge_locks_movement() -> void:
	var sim := CourtSim.new()
	var f := _held()
	f.move = Vector2(1, 0)
	var start: Vector2 = sim.players[0].pos
	for i in 10:
		sim.tick([f, InputFrame.new()])
	check(sim.players[0].pos == start, "holding charge must lock movement")

func test_charged_shot_faster_than_tap() -> void:
	var tap := CourtSim.new()
	var t := InputFrame.new()
	t.hit_pressed = true
	tap.tick([t, InputFrame.new()])
	var tap_speed: float = tap.ball.vel.length()

	var chg := CourtSim.new()
	for i in 45:
		chg.tick([_held(), InputFrame.new()])
	var rel := InputFrame.new()
	rel.hit_pressed = true
	chg.tick([rel, InputFrame.new()])
	var chg_speed: float = chg.ball.vel.length()

	check(chg_speed > tap_speed + 1.0, "a charged shot must leave faster than a tap")

func test_charge_resets_after_shot() -> void:
	var sim := CourtSim.new()
	for i in 20:
		sim.tick([_held(), InputFrame.new()])
	check(sim.players[0].charge > 0.0, "charge should have built")
	var rel := InputFrame.new()
	rel.hit_pressed = true
	sim.tick([rel, InputFrame.new()])
	check(sim.players[0].charge == 0.0, "charge must reset after the swing")
