extends RefCounted

# Placeholder character sheet generated in code: two frames (idle, run) side by
# side, each FRAME_W x FRAME_H. Swap build() for a loaded PNG when real art exists.

const FRAME_W := 24
const FRAME_H := 40

static func frame_rect(index: int) -> Rect2:
	return Rect2(index * FRAME_W, 0, FRAME_W, FRAME_H)

static func build(tint: Color) -> ImageTexture:
	var img := Image.create(FRAME_W * 2, FRAME_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for frame in 2:
		var ox := frame * FRAME_W
		var spread := 3 if frame == 1 else 1
		_rect(img, ox + 8 - spread, 30, 4, 10, tint.darkened(0.3))
		_rect(img, ox + 12 + spread, 30, 4, 10, tint.darkened(0.3))
		_rect(img, ox + 8, 14, 8, 18, tint)
		_rect(img, ox + 9, 4, 6, 8, tint.lightened(0.2))
	return ImageTexture.create_from_image(img)

static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for iy in range(y, y + h):
		for ix in range(x, x + w):
			img.set_pixel(ix, iy, c)
