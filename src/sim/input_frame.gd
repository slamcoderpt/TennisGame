extends RefCounted

var move := Vector2.ZERO       # court-space direction, length <= 1, +y = toward far side
var hit_pressed := false       # true only on the tick the hit input fired
