extends "res://tests/test_base.gd"

const CourtSim := preload("res://src/sim/court_sim.gd")
const InputFrame := preload("res://src/sim/input_frame.gd")
const WallAI := preload("res://src/ai/wall_ai.gd")

func test_ai_returns_the_ball() -> void:
	var sim := CourtSim.new()
	var ai := WallAI.new()
	var serve := InputFrame.new()
	serve.hit_pressed = true
	sim.tick([serve, ai.frame(sim)])
	check(sim.ball.in_play, "serve should start the rally")
	var returned := false
	var idle := InputFrame.new()
	for i in 600:
		sim.tick([idle, ai.frame(sim)])
		if sim.ball.in_play and sim.ball.vel.y < 0.0:
			returned = true
			break
	check(returned, "AI should return the ball toward the player within 10s")
