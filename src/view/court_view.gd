extends Node2D

const Proj := preload("res://src/view/projection.gd")
const CourtSim := preload("res://src/sim/court_sim.gd")
const SpriteSheet := preload("res://src/view/sprite_sheet.gd")

const COURT_COLOR := Color("2d6a4f")
const LINE_COLOR := Color.WHITE
const NET_COLOR := Color(1, 1, 1, 0.35)
const P1_COLOR := Color("457b9d")
const P2_COLOR := Color("e63946")
const BALL_COLOR := Color("ffd166")
const SHADOW_COLOR := Color(0, 0, 0, 0.35)
const REACH_OK_COLOR := Color(0.2, 1.0, 0.2, 0.8)    # ball is hittable now
const REACH_WAIT_COLOR := Color(1.0, 1.0, 0.2, 0.4)  # in range but not yet hittable

var sim = null
var debug_reach := true        # toggle with the D key; shows the near player's hit zone
const SWING_FRAMES := 12       # how long the swing pose shows after a hit

# near = the bottom player (seen from behind), far = the top player (seen from the front)
var _sprites := {
	"near_idle": load("res://assets/generated/cut/allrounder_back_idle.png"),
	"near_run": load("res://assets/generated/cut/allrounder_back_run.png"),
	"near_run2": load("res://assets/generated/cut/allrounder_back_run2.png"),
	"near_charge": load("res://assets/generated/cut/allrounder_back_charge.png"),
	"near_swing": load("res://assets/generated/cut/allrounder_back_swing.png"),
	"far_idle": load("res://assets/generated/cut/allrounder_front_idle.png"),
	"far_run": load("res://assets/generated/cut/allrounder_front_run.png"),
	"far_run2": load("res://assets/generated/cut/allrounder_front_run2.png"),
	"far_charge": load("res://assets/generated/cut/allrounder_front_charge.png"),
	"far_swing": load("res://assets/generated/cut/allrounder_front_swing.png"),
}
var _anim := 0.0
var _swing_timer := [0, 0]     # frames of swing pose left, per player
var _last_hit_count := 0

func render(s) -> void:
	sim = s
	_anim += 0.05
	if sim != null and sim.hit_count != _last_hit_count:
		_last_hit_count = sim.hit_count
		if sim.last_hitter >= 0:
			_swing_timer[sim.last_hitter] = SWING_FRAMES
	for i in 2:
		if _swing_timer[i] > 0:
			_swing_timer[i] -= 1
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_D:
		debug_reach = not debug_reach
		queue_redraw()

func _draw() -> void:
	if sim == null:
		return
	var f := Engine.get_physics_interpolation_fraction()
	_draw_court()
	_draw_player(sim.players[1], 1, f)
	_draw_net()
	if debug_reach:
		_draw_reach(sim.players[0])
	_draw_ball(f)
	_draw_player(sim.players[0], 0, f)
	_draw_charge(sim.players[0])

func _draw_reach(p) -> void:
	var b = sim.ball
	# Mirror the sim's _try_hit conditions so the green light never lies.
	var incoming: bool = not b.in_play or (signf(b.vel.y) == float(p.side) and not sim.is_serve)
	var hittable: bool = incoming and b.pos.distance_to(p.pos) <= CourtSim.REACH and b.height <= CourtSim.MAX_HIT_HEIGHT
	var color := REACH_OK_COLOR if hittable else REACH_WAIT_COLOR
	var pts := PackedVector2Array()
	var n := 32
	for i in n + 1:
		var a := TAU * i / n
		var court_pt: Vector2 = p.pos + Vector2(cos(a), sin(a)) * CourtSim.REACH
		pts.append(Proj.to_screen(court_pt))
	draw_polyline(pts, color, 2.0)

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

func _draw_player(p, idx: int, f: float) -> void:
	var pos: Vector2 = p.prev_pos.lerp(p.pos, f)
	var s := Proj.scale_at(pos.y)
	var screen := Proj.to_screen(pos)
	var facing := "near" if p.side < 0 else "far"
	var key := "idle"
	if _swing_timer[idx] > 0:
		key = "swing"
	elif p.charge > 0.0:
		key = "charge"
	elif p.prev_pos.distance_to(p.pos) > 0.001:
		key = "run" if int(_anim * 6.0) % 2 == 0 else "run2"
	var tex: Texture2D = _sprites[facing + "_" + key]
	var h := s * 2.4
	var w := tex.get_width() * h / tex.get_height()
	var dest := Rect2(screen.x - w / 2.0, screen.y - h, w, h)
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var src := Rect2(0, 0, tw, th)
	if p.move_vel.x < -0.5:
		src = Rect2(tw, 0, -tw, th)    # mirror when moving left
	draw_texture_rect_region(tex, dest, src)

func _draw_ball(f: float) -> void:
	var b = sim.ball
	var pos: Vector2 = b.prev_pos.lerp(b.pos, f)
	var h := lerpf(b.prev_height, b.height, f)
	var s := Proj.scale_at(pos.y)
	draw_circle(Proj.to_screen(pos), 0.25 * s, SHADOW_COLOR)
	draw_circle(Proj.to_screen(pos, h), 0.22 * s, BALL_COLOR)

func _draw_charge(p) -> void:
	if p.charge <= 0.0:
		return
	var center := Proj.to_screen(p.pos)
	var s := Proj.scale_at(p.pos.y)
	var r := 1.1 * s
	var col := Color(1.0, 0.85, 0.2) if p.charge >= 1.0 else Color(1.0, 1.0, 1.0, 0.8)
	draw_arc(center, r, -PI / 2.0, -PI / 2.0 + TAU * p.charge, 32, col, 4.0)
