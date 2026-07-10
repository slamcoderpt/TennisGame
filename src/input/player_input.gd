extends Node2D

const InputFrame := preload("res://src/sim/input_frame.gd")

const JOY_RADIUS := 110.0

var joy_id := -1
var joy_origin := Vector2.ZERO
var joy_current := Vector2.ZERO
var hit_latched := false       # set on the press event, consumed once by the sim tick

func _input(event: InputEvent) -> void:
	var half := get_viewport_rect().size.x / 2.0
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < half and joy_id == -1:
				joy_id = event.index
				joy_origin = event.position
				joy_current = event.position
				queue_redraw()
			elif event.position.x >= half:
				hit_latched = true
		elif event.index == joy_id:
			joy_id = -1
			queue_redraw()
	elif event is InputEventScreenDrag and event.index == joy_id:
		joy_current = event.position
		queue_redraw()
	elif event.is_action_pressed("ui_accept"):
		hit_latched = true

func consume_frame():
	var f := InputFrame.new()
	var kb := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	f.move = Vector2(kb.x, -kb.y)
	if joy_id != -1:
		var v := (joy_current - joy_origin) / JOY_RADIUS
		if v.length() > 1.0:
			v = v.normalized()
		f.move = Vector2(v.x, -v.y)
	f.hit_pressed = hit_latched
	hit_latched = false
	return f

func _draw() -> void:
	if joy_id == -1:
		return
	draw_circle(joy_origin, JOY_RADIUS, Color(1, 1, 1, 0.08))
	draw_arc(joy_origin, JOY_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.25), 2.0)
	var knob := joy_origin + (joy_current - joy_origin).limit_length(JOY_RADIUS)
	draw_circle(knob, 28.0, Color(1, 1, 1, 0.3))
