extends RefCounted

const BallState := preload("res://src/sim/ball_state.gd")
const PlayerState := preload("res://src/sim/player_state.gd")
const MatchScore := preload("res://src/sim/match_score.gd")

const TICK := 1.0 / 60.0
const HALF_WIDTH := 4.0
const HALF_LENGTH := 12.0
const OUT_MARGIN := 4.0
const NET_HEIGHT := 1.0
const GRAVITY := 22.0
const RESTITUTION := 0.75
const MAX_BOUNCES := 4
const PLAYER_SPEED := 9.0
const REACH := 2.0
const MAX_HIT_HEIGHT := 3.0
const HIT_BUFFER_TICKS := 8     # a press stays armed this many ticks (forgives early swings)
const SHOT_SPEED := 16.0
const SHOT_LAUNCH := 7.0
const AIM_MAX_X := HALF_WIDTH - 1.0
const TARGET_DEPTH := HALF_LENGTH - 3.0
const SERVE_DEPTH := 8.0
const SERVE_HEIGHT := 1.2
const POINT_PAUSE_TICKS := 45   # short freeze after a point so the result reads

var ball := BallState.new()
var players := [PlayerState.new(), PlayerState.new()]
var score := MatchScore.new()
var server := 0                 # player index serving the current game
var serve_faults := 0
var is_serve := false           # true from the serve hit until its first legal bounce
var last_hitter := -1           # -1 = nobody has hit since the last reset
var pause_ticks := 0
var last_event := ""            # transient HUD message ("FAULT", "OUT!", ...)

func _init() -> void:
	players[0].side = -1
	players[0].pos = Vector2(0.0, -9.0)
	players[1].side = 1
	players[1].pos = Vector2(0.0, 9.0)
	for p in players:
		p.prev_pos = p.pos
	reset_for_serve()

func reset_for_serve() -> void:
	ball.pos = Vector2(0.0, SERVE_DEPTH * float(players[server].side))
	ball.prev_pos = ball.pos
	ball.height = SERVE_HEIGHT
	ball.prev_height = SERVE_HEIGHT
	ball.vel = Vector2.ZERO
	ball.v_height = 0.0
	ball.bounce_count = 0
	ball.in_play = false
	last_hitter = -1
	is_serve = false
	for p in players:
		p.hit_buffer = 0

func tick(inputs: Array) -> void:
	if score.match_winner != -1:
		return
	ball.prev_pos = ball.pos
	ball.prev_height = ball.height
	for i in 2:
		players[i].prev_pos = players[i].pos
		_move_player(players[i], inputs[i])
	if pause_ticks > 0:
		pause_ticks -= 1
		if pause_ticks == 0:
			reset_for_serve()
		return
	_update_ball()
	for i in 2:
		if inputs[i].hit_pressed:
			players[i].hit_buffer = HIT_BUFFER_TICKS
		if players[i].hit_buffer > 0:
			players[i].hit_buffer -= 1
			if _try_hit(i, inputs[i]):
				players[i].hit_buffer = 0

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
		_judge_bounce()
	var out_x := absf(ball.pos.x) > HALF_WIDTH + OUT_MARGIN
	var out_y := absf(ball.pos.y) > HALF_LENGTH + OUT_MARGIN
	if ball.in_play and (out_x or out_y or ball.bounce_count >= MAX_BOUNCES):
		_ball_flew_out()

func _judge_bounce() -> void:
	if last_hitter == -1:
		return
	if ball.bounce_count == 1:
		var in_bounds: bool = absf(ball.pos.x) <= HALF_WIDTH and absf(ball.pos.y) <= HALF_LENGTH
		var on_opponent_side: bool = signf(ball.pos.y) == -float(players[last_hitter].side)
		if in_bounds and on_opponent_side:
			is_serve = false
			return
		if is_serve:
			_serve_fault()
		else:
			_end_point(1 - last_hitter, "OUT!")
	elif ball.bounce_count >= 2:
		_end_point(last_hitter, "")

func _ball_flew_out() -> void:
	if last_hitter == -1:
		reset_for_serve()
	elif is_serve:
		_serve_fault()
	else:
		_end_point(1 - last_hitter, "OUT!")

func _serve_fault() -> void:
	serve_faults += 1
	if serve_faults >= 2:
		_end_point(1 - server, "DOUBLE FAULT")
	else:
		last_event = "FAULT"
		pause_ticks = POINT_PAUSE_TICKS
		_freeze_ball()

func _end_point(winner: int, event: String) -> void:
	var games_before: int = score.games[0] + score.games[1]
	score.point_won_by(winner)
	if score.games[0] + score.games[1] > games_before:
		server = 1 - server
	serve_faults = 0
	last_event = event
	pause_ticks = POINT_PAUSE_TICKS
	_freeze_ball()

func _freeze_ball() -> void:
	ball.vel = Vector2.ZERO
	ball.v_height = 0.0
	ball.in_play = false

func _try_hit(i: int, input) -> bool:
	var p = players[i]
	if ball.in_play and is_serve:
		return false               # the serve must bounce before it can be returned
	var incoming: bool = not ball.in_play or signf(ball.vel.y) == float(p.side)
	if not incoming:
		return false
	if ball.pos.distance_to(p.pos) > REACH or ball.height > MAX_HIT_HEIGHT:
		return false
	var serving: bool = not ball.in_play
	var aim_x := clampf(input.move.x, -1.0, 1.0) * AIM_MAX_X
	var target := Vector2(aim_x, -p.side * TARGET_DEPTH)
	ball.vel = (target - ball.pos).normalized() * SHOT_SPEED
	ball.v_height = SHOT_LAUNCH
	ball.height = maxf(ball.height, 0.3)
	ball.bounce_count = 0
	ball.in_play = true
	last_hitter = i
	if serving:
		is_serve = true
		last_event = ""
	return true
