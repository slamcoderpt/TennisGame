extends RefCounted

var pos := Vector2.ZERO
var prev_pos := Vector2.ZERO
var side := -1                 # -1 = bottom (near camera, human), +1 = top
var hit_buffer := 0            # ticks the swing stays armed after a hit press
var charge := 0.0              # 0..1 wind-up while the hit is held
