extends "res://tests/test_base.gd"

const SpriteSheet := preload("res://src/view/sprite_sheet.gd")

func test_placeholder_sheet_has_two_frames() -> void:
	var tex := SpriteSheet.build(Color(0.27, 0.48, 0.62))
	check(tex != null, "build must return a texture")
	check(tex.get_width() == SpriteSheet.FRAME_W * 2, "sheet is two frames wide")
	check(tex.get_height() == SpriteSheet.FRAME_H, "sheet is one frame tall")

func test_frame_rect_selects_by_index() -> void:
	var r0 := SpriteSheet.frame_rect(0)
	var r1 := SpriteSheet.frame_rect(1)
	check(r0.position.x == 0.0, "frame 0 starts at x=0")
	check(r1.position.x == float(SpriteSheet.FRAME_W), "frame 1 starts one frame over")
