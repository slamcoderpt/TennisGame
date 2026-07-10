extends RefCounted

var pos := Vector2.ZERO
var prev_pos := Vector2.ZERO
var move_vel := Vector2.ZERO   # current movement velocity (converges to the input target)
var side := -1                 # -1 = bottom (near camera, human), +1 = top
var hit_buffer := 0            # ticks the swing stays armed after a hit press
var charge := 0.0              # 0..1 wind-up while the hit is held
var speed := 1.0               # stat multipliers on the baseline (1.0 = baseline)
var power := 1.0
var charge_rate := 1.0
var reach := 1.0
