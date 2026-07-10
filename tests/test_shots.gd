extends "res://tests/test_base.gd"

const CourtSim := preload("res://src/sim/court_sim.gd")
const InputFrame := preload("res://src/sim/input_frame.gd")

# Put a returnable ball right on player 0 (near the net so a drop can clear it) and fire once.
func _hit_with_stick(stick: Vector2) -> CourtSim:
	var sim := CourtSim.new()
	sim.last_hitter = 1
	sim.is_serve = false
	sim.ball.in_play = true
	sim.ball.pos = Vector2(0, -2)
	sim.ball.vel = Vector2(0, -6)
	sim.ball.height = 1.0
	sim.ball.v_height = 0.0
	sim.players[0].pos = Vector2(0, -2)
	var f := InputFrame.new()
	f.hit_pressed = true
	f.move = stick
	sim.tick([f, InputFrame.new()])
	return sim

func test_lob_launches_higher_than_flat() -> void:
	var flat := _hit_with_stick(Vector2.ZERO)
	var lob := _hit_with_stick(Vector2(0, -1))   # player 0 side=-1: stick toward own baseline
	check(lob.ball.v_height > flat.ball.v_height, "a lob must launch higher than a flat drive")

func test_drop_slower_than_flat() -> void:
	var flat := _hit_with_stick(Vector2.ZERO)
	var drop := _hit_with_stick(Vector2(0, 1))    # stick toward the net
	check(drop.ball.vel.length() < flat.ball.vel.length(), "a drop shot must be slower than a flat drive")

func test_drop_lands_shorter_than_flat() -> void:
	var flat := _hit_with_stick(Vector2.ZERO)
	var drop := _hit_with_stick(Vector2(0, 1))
	for i in 180:
		flat.tick([InputFrame.new(), InputFrame.new()])
		drop.tick([InputFrame.new(), InputFrame.new()])
		if flat.ball.bounce_count >= 1 and drop.ball.bounce_count >= 1:
			break
	check(drop.ball.pos.y < flat.ball.pos.y, "a drop shot must land nearer the net than a flat drive")
