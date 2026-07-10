extends RefCounted

const InputFrame := preload("res://src/sim/input_frame.gd")
const CourtSim := preload("res://src/sim/court_sim.gd")

func frame(sim) -> InputFrame:
	var f := InputFrame.new()
	var me = sim.players[1]
	var dx: float = sim.ball.pos.x - me.pos.x
	if absf(dx) > 0.2:
		f.move.x = signf(dx)
	if sim.ball.pos.distance_to(me.pos) <= CourtSim.REACH:
		f.hit_pressed = true
	return f
