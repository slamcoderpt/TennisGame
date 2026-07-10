extends RefCounted

var pos := Vector2.ZERO
var prev_pos := Vector2.ZERO
var side := -1                 # -1 = bottom (near camera, human), +1 = top
var hit_buffer := 0            # ticks the swing stays armed after a hit press
