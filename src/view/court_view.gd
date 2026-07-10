extends Node2D

const Proj := preload("res://src/view/projection.gd")
const CourtSim := preload("res://src/sim/court_sim.gd")

const COURT_COLOR := Color("2d6a4f")
const LINE_COLOR := Color.WHITE
const NET_COLOR := Color(1, 1, 1, 0.35)
const P1_COLOR := Color("457b9d")
const P2_COLOR := Color("e63946")
const BALL_COLOR := Color("ffd166")
const SHADOW_COLOR := Color(0, 0, 0, 0.35)

var sim = null

func render(s) -> void:
	sim = s
	queue_redraw()

func _draw() -> void:
	if sim == null:
		return
	var f := Engine.get_physics_interpolation_fraction()
	_draw_court()
	_draw_player(sim.players[1], P2_COLOR, f)
	_draw_net()
	_draw_ball(f)
	_draw_player(sim.players[0], P1_COLOR, f)

func _draw_court() -> void:
	var hw := CourtSim.HALF_WIDTH
	var hl := CourtSim.HALF_LENGTH
	var pts := PackedVector2Array([
		Proj.to_screen(Vector2(-hw, -hl)),
		Proj.to_screen(Vector2(hw, -hl)),
		Proj.to_screen(Vector2(hw, hl)),
		Proj.to_screen(Vector2(-hw, hl)),
	])
	draw_colored_polygon(pts, COURT_COLOR)
	draw_polyline(pts + PackedVector2Array([pts[0]]), LINE_COLOR, 3.0)

func _draw_net() -> void:
	var hw := CourtSim.HALF_WIDTH
	var h := CourtSim.NET_HEIGHT
	var quad := PackedVector2Array([
		Proj.to_screen(Vector2(-hw, 0.0)),
		Proj.to_screen(Vector2(hw, 0.0)),
		Proj.to_screen(Vector2(hw, 0.0), h),
		Proj.to_screen(Vector2(-hw, 0.0), h),
	])
	draw_colored_polygon(quad, NET_COLOR)
	draw_line(quad[3], quad[2], LINE_COLOR, 2.0)

func _draw_player(p, color: Color, f: float) -> void:
	var pos: Vector2 = p.prev_pos.lerp(p.pos, f)
	var s := Proj.scale_at(pos.y)
	var screen := Proj.to_screen(pos)
	var size := Vector2(0.9, 1.4) * s
	draw_rect(Rect2(screen - Vector2(size.x / 2.0, size.y), size), color)

func _draw_ball(f: float) -> void:
	var b = sim.ball
	var pos: Vector2 = b.prev_pos.lerp(b.pos, f)
	var h := lerpf(b.prev_height, b.height, f)
	var s := Proj.scale_at(pos.y)
	draw_circle(Proj.to_screen(pos), 0.25 * s, SHADOW_COLOR)
	draw_circle(Proj.to_screen(pos, h), 0.22 * s, BALL_COLOR)
