extends Node2D

const CourtSim := preload("res://src/sim/court_sim.gd")
const CourtView := preload("res://src/view/court_view.gd")
const PlayerInput := preload("res://src/input/player_input.gd")
const WallAI := preload("res://src/ai/wall_ai.gd")

var sim := CourtSim.new()
var view: Node2D
var player_input: Node2D
var ai := WallAI.new()

func _ready() -> void:
	view = CourtView.new()
	add_child(view)
	player_input = PlayerInput.new()
	add_child(player_input)

func _physics_process(_delta: float) -> void:
	sim.tick([player_input.consume_frame(), ai.frame(sim)])

func _process(_delta: float) -> void:
	view.render(sim)
