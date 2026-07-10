extends RefCounted

var pos := Vector2.ZERO        # court-space xy
var prev_pos := Vector2.ZERO   # previous tick, for render interpolation
var height := 1.2              # units above the court
var prev_height := 1.2
var vel := Vector2.ZERO        # horizontal velocity, units/sec
var v_height := 0.0            # vertical velocity, units/sec
var bounce_count := 0
var in_play := false           # false = hovering, waiting for the serve hit
var swerve := 0.0              # radians/sec the velocity rotates (special shot); 0 = straight
