extends RefCounted

const BallState := preload("res://src/sim/ball_state.gd")
const PlayerState := preload("res://src/sim/player_state.gd")

const TICK := 1.0 / 60.0
const HALF_WIDTH := 4.0
const HALF_LENGTH := 12.0
const OUT_MARGIN := 4.0
const NET_HEIGHT := 1.0        # visual only in milestone 1
const GRAVITY := 22.0
const RESTITUTION := 0.75
const MAX_BOUNCES := 4
const PLAYER_SPEED := 9.0
const REACH := 1.6
const MAX_HIT_HEIGHT := 3.0
const SHOT_SPEED := 16.0
const SHOT_LAUNCH := 7.0
const AIM_MAX_X := HALF_WIDTH - 1.0
const TARGET_DEPTH := HALF_LENGTH - 3.0
const SERVE_POS := Vector2(0.0, -8.0)
const SERVE_HEIGHT := 1.2

var ball := BallState.new()
var players := [PlayerState.new(), PlayerState.new()]

func _init() -> void:
	players[0].side = -1
	players[0].pos = Vector2(0.0, -9.0)
	players[1].side = 1
	players[1].pos = Vector2(0.0, 9.0)
	for p in players:
		p.prev_pos = p.pos
	reset_ball()

func reset_ball() -> void:
	ball.pos = SERVE_POS
	ball.prev_pos = SERVE_POS
	ball.height = SERVE_HEIGHT
	ball.prev_height = SERVE_HEIGHT
	ball.vel = Vector2.ZERO
	ball.v_height = 0.0
	ball.bounce_count = 0
	ball.in_play = false

func tick(inputs: Array) -> void:
	ball.prev_pos = ball.pos
	ball.prev_height = ball.height
	for i in 2:
		players[i].prev_pos = players[i].pos
		_move_player(players[i], inputs[i])
	_update_ball()
	for i in 2:
		if inputs[i].hit_pressed:
			_try_hit(players[i], inputs[i])

func _move_player(p, input) -> void:
	var m: Vector2 = input.move
	if m.length() > 1.0:
		m = m.normalized()
	p.pos += m * PLAYER_SPEED * TICK
	p.pos.x = clampf(p.pos.x, -HALF_WIDTH, HALF_WIDTH)
	if p.side < 0:
		p.pos.y = clampf(p.pos.y, -HALF_LENGTH, -0.5)
	else:
		p.pos.y = clampf(p.pos.y, 0.5, HALF_LENGTH)

func _update_ball() -> void:
	if not ball.in_play:
		return
	ball.pos += ball.vel * TICK
	ball.v_height -= GRAVITY * TICK
	ball.height += ball.v_height * TICK
	if ball.height <= 0.0 and ball.v_height < 0.0:
		ball.height = 0.0
		ball.v_height = -ball.v_height * RESTITUTION
		ball.bounce_count += 1
	var out_x := absf(ball.pos.x) > HALF_WIDTH + OUT_MARGIN
	var out_y := absf(ball.pos.y) > HALF_LENGTH + OUT_MARGIN
	if out_x or out_y or ball.bounce_count >= MAX_BOUNCES:
		reset_ball()

func _try_hit(p, input) -> void:
	var incoming: bool = not ball.in_play or signf(ball.vel.y) == float(p.side)
	if not incoming:
		return
	if ball.pos.distance_to(p.pos) > REACH or ball.height > MAX_HIT_HEIGHT:
		return
	var aim_x := clampf(input.move.x, -1.0, 1.0) * AIM_MAX_X
	var target := Vector2(aim_x, -p.side * TARGET_DEPTH)
	ball.vel = (target - ball.pos).normalized() * SHOT_SPEED
	ball.v_height = SHOT_LAUNCH
	ball.height = maxf(ball.height, 0.3)
	ball.bounce_count = 0
	ball.in_play = true
