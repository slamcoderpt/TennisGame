extends RefCounted

var move := Vector2.ZERO       # court-space direction, length <= 1, +y = toward far side
var hit_held := false          # true every tick the hit button is down (builds charge, locks movement)
var hit_pressed := false       # true on the single tick the swing fires (release edge, or a tap in tests)
