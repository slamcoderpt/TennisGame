extends SceneTree

# Green-screen a generated sprite: chroma-key the green background to alpha,
# de-spill green fringes, autocrop, downscale to a target height, and save.
# Also writes a *_preview.png composited over grey so the cutout is easy to judge.
#
#   godot --headless --path . -s res://tools/process_sprite.gd -- \
#       <input.png> <output.png> <target_height>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("usage: process_sprite.gd -- <input> <output> <target_height>")
		quit(1)
		return
	var in_path: String = args[0]
	var out_path: String = args[1]
	var target_h: int = int(args[2])

	var img := Image.new()
	var err := img.load(in_path)
	if err != OK:
		push_error("could not load %s (err %d)" % [in_path, err])
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)

	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			# green-dominant pixel => background (also catches racket mesh)
			if c.g > 0.5 and c.g > c.r + 0.15 and c.g > c.b + 0.15:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif c.a > 0.0 and c.g > c.r and c.g > c.b:
				# de-spill: pull a green tint on kept edge pixels back down
				c.g = maxf(c.r, c.b)
				img.set_pixel(x, y, c)

	var used := img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		push_error("nothing left after chroma-key on %s" % in_path)
		quit(1)
		return
	var cropped := img.get_region(used)

	var target_w := int(round(float(cropped.get_width()) * float(target_h) / float(cropped.get_height())))
	cropped.resize(target_w, target_h, Image.INTERPOLATE_LANCZOS)
	cropped.save_png(out_path)

	# preview over grey
	var prev := Image.create(target_w, target_h, false, Image.FORMAT_RGBA8)
	prev.fill(Color(0.5, 0.5, 0.5))
	prev.blend_rect(cropped, Rect2i(0, 0, target_w, target_h), Vector2i(0, 0))
	var prev_path := out_path.get_basename() + "_preview.png"
	prev.save_png(prev_path)

	print("  %s -> %s (%dx%d)" % [in_path.get_file(), out_path.get_file(), target_w, target_h])
	quit(0)
