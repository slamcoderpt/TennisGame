extends Node2D

const CourtSim := preload("res://src/sim/court_sim.gd")
const CourtView := preload("res://src/view/court_view.gd")
const Hud := preload("res://src/view/hud.gd")
const PlayerInput := preload("res://src/input/player_input.gd")
const WallAI := preload("res://src/ai/wall_ai.gd")

const SHAKE_DECAY := 0.6         # shake magnitude removed per rendered frame

var sim := CourtSim.new()
var view: Node2D
var hud: Node2D
var player_input: Node2D
var ai := WallAI.new()

var _seen_hits := 0
var _pause_frames := 0
var _shake := 0.0

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
			_restart()
		return
	if _pause_frames > 0:
		_pause_frames -= 1
		return
	sim.tick([frame, ai.frame(sim)])
	if sim.hit_count != _seen_hits:
		_seen_hits = sim.hit_count
		_pause_frames = int(round(2.0 + 4.0 * sim.hit_strength))
		_shake = 4.0 + 10.0 * sim.hit_strength

func _restart() -> void:
	sim = CourtSim.new()
	_seen_hits = 0
	_pause_frames = 0
	_shake = 0.0

func _process(_delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - SHAKE_DECAY)
	if _shake > 0.1:
		view.position = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	else:
		view.position = Vector2.ZERO
	view.render(sim)
	hud.render(sim)
