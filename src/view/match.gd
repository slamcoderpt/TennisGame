extends Node2D

const CourtSim := preload("res://src/sim/court_sim.gd")
const CourtView := preload("res://src/view/court_view.gd")
const Hud := preload("res://src/view/hud.gd")
const PlayerInput := preload("res://src/input/player_input.gd")
const WallAI := preload("res://src/ai/wall_ai.gd")

var sim := CourtSim.new()
var view: Node2D
var hud: Node2D
var player_input: Node2D
var ai := WallAI.new()

func _ready() -> void:
	view = CourtView.new()
	add_child(view)
	hud = Hud.new()
	add_child(hud)
	player_input = PlayerInput.new()
	add_child(player_input)

func _physics_process(_delta: float) -> void:
	var frame = player_input.consume_frame()
	if sim.score.match_winner != -1:
		if frame.hit_pressed:
			sim = CourtSim.new()
		return
	sim.tick([frame, ai.frame(sim)])

func _process(_delta: float) -> void:
	view.render(sim)
	hud.render(sim)
