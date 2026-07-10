extends Node2D

const InputFrame := preload("res://src/sim/input_frame.gd")

func consume_frame():
	var f := InputFrame.new()
	var kb := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	f.move = Vector2(kb.x, -kb.y)
	f.hit_pressed = Input.is_action_just_pressed("ui_accept")
	return f
