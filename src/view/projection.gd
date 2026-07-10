extends RefCounted

const CourtSim := preload("res://src/sim/court_sim.gd")

const SCREEN_W := 1280.0
const NEAR_Y := 660.0      # screen y of the near baseline
const FAR_Y := 120.0       # screen y of the far baseline
const NEAR_SCALE := 60.0   # pixels per court unit at the near baseline
const FAR_SCALE := 33.0    # pixels per court unit at the far baseline
const HEIGHT_SCALE := 0.8  # how strongly ball height offsets up-screen

static func depth_t(court_y: float) -> float:
	return (court_y + CourtSim.HALF_LENGTH) / (2.0 * CourtSim.HALF_LENGTH)

static func scale_at(court_y: float) -> float:
	return lerpf(NEAR_SCALE, FAR_SCALE, depth_t(court_y))

static func to_screen(court_pos: Vector2, height := 0.0) -> Vector2:
	var s := scale_at(court_pos.y)
	var x := SCREEN_W / 2.0 + court_pos.x * s
	var y := lerpf(NEAR_Y, FAR_Y, depth_t(court_pos.y)) - height * s * HEIGHT_SCALE
	return Vector2(x, y)
