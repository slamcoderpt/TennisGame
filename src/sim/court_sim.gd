extends RefCounted

const BallState := preload("res://src/sim/ball_state.gd")
const PlayerState := preload("res://src/sim/player_state.gd")
const MatchScore := preload("res://src/sim/match_score.gd")

const TICK := 1.0 / 60.0
const HALF_WIDTH := 4.0
const HALF_LENGTH := 12.0
const OUT_MARGIN := 4.0
const NET_HEIGHT := 1.0
const NET_REBOUND := 0.25       # how much of vel.y survives a net hit, reversed
const GRAVITY := 22.0
const RESTITUTION := 0.75
const MAX_BOUNCES := 4
const PLAYER_SPEED := 9.0
const REACH := 2.0
const MAX_HIT_HEIGHT := 3.0
const HIT_BUFFER_TICKS := 8     # a press stays armed this many ticks (forgives early swings)
const SHOT_SPEED_MIN := 16.0    # tap speed (matches the old flat SHOT_SPEED)
const SHOT_SPEED_MAX := 26.0    # full-charge speed
const CHARGE_TIME := 0.6        # seconds of hold to reach full charge
const LOB_SPEED := 10.0          # slow, high, deep
const LOB_LAUNCH := 12.0
const LOB_DEPTH := HALF_LENGTH - 1.0
const DROP_SPEED := 7.0          # soft, low, just over the net
const DROP_LAUNCH := 3.0
const DROP_DEPTH := 2.0
const SHOT_STICK_DEADZONE := 0.5
const SHOT_LAUNCH := 7.0
const AIM_MAX_X := HALF_WIDTH - 1.0
const TARGET_DEPTH := HALF_LENGTH - 3.0
const SERVE_DEPTH := 8.0
const SERVE_HEIGHT := 0.4        # low "in-hand" rest height before the toss
const SERVE_X := 1.5             # deuce/ad offset; small enough that a center server still reaches it
const TOSS_VELOCITY := 9.0       # upward toss speed (~0.8s airtime, apex ~2.2 units above rest)
const IDEAL_CONTACT_HEIGHT := 2.2  # best timing sits at the toss apex
const CONTACT_WINDOW := 1.8      # generous timing window around the ideal contact height
const MIN_CONTACT_HEIGHT := 0.5  # releasing below this while tossing = whiffed serve = fault
const SERVE_SPEED_MIN := 14.0
const SERVE_SPEED_MAX := 22.0
const SERVE_LAUNCH := 7.0        # upward velocity imparted to the served ball
const SERVE_TAP_QUALITY := 0.5   # a no-toss tap serves at this default quality
const SERVE_AIM_NUDGE := 1.0     # how far the stick can shift the cross-court serve target
const POINT_PAUSE_TICKS := 45   # short freeze after a point so the result reads
const METER_PER_HIT := 0.12     # meter gained by the hitter each swing
const METER_PER_POINT := 0.25   # meter gained by the winner of a point
const SPECIAL_SPEED := 30.0     # special shot is faster than a normal full charge
const SPECIAL_SWERVE := 3.0     # radians/sec the special ball curves

var ball := BallState.new()
var players := [PlayerState.new(), PlayerState.new()]
var score := MatchScore.new()
var server := 0                 # player index serving the current game
var serve_faults := 0
var is_serve := false           # true from the serve hit until its first legal bounce
var is_tossing := false         # true while the served ball is airborne from the toss, pre-contact
var last_hitter := -1           # -1 = nobody has hit since the last reset
var pause_ticks := 0
var last_event := ""            # transient HUD message ("FAULT", "OUT!", ...)
var meter := [0.0, 0.0]         # 0..1 super meter per player; persists across points, not matches
var hit_count := 0              # monotonic swing counter; the view reads it to trigger juice
var hit_strength := 0.0         # power of the most recent swing (0..1, or >1 for a special)

func _init() -> void:
	players[0].side = -1
	players[0].pos = Vector2(0.0, -9.0)
	players[1].side = 1
	players[1].pos = Vector2(0.0, 9.0)
	for p in players:
		p.prev_pos = p.pos
	reset_for_serve()

func reset_for_serve() -> void:
	var s := int(players[server].side)
	var ad: bool = (score.points[0] + score.points[1]) % 2 == 1
	var serve_x := SERVE_X * (float(s) if ad else -float(s))
	ball.pos = Vector2(serve_x, SERVE_DEPTH * float(s))
	ball.prev_pos = ball.pos
	ball.height = SERVE_HEIGHT
	ball.prev_height = SERVE_HEIGHT
	ball.vel = Vector2.ZERO
	ball.v_height = 0.0
	ball.bounce_count = 0
	ball.in_play = false
	ball.swerve = 0.0
	last_hitter = -1
	is_serve = false
	is_tossing = false
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
		var input = inputs[i]
		if input.hit_held:
			players[i].charge = minf(1.0, players[i].charge + TICK / CHARGE_TIME)
		if input.hit_pressed:
			players[i].hit_buffer = HIT_BUFFER_TICKS
		if players[i].hit_buffer > 0:
			players[i].hit_buffer -= 1
			if _try_hit(i, input):
				players[i].hit_buffer = 0
		if not input.hit_held and players[i].hit_buffer == 0:
			players[i].charge = 0.0

func _move_player(p, input) -> void:
	if input.hit_held:
		return                  # charging locks the player in place
	var m: Vector2 = input.move
	if m.length() > 1.0:
		m = m.normalized()
	p.pos += m * PLAYER_SPEED * TICK
	p.pos.x = clampf(p.pos.x, -HALF_WIDTH, HALF_WIDTH)
	if p.side < 0:
		p.pos.y = clampf(p.pos.y, -HALF_LENGTH, -0.5)
	else:
		p.pos.y = clampf(p.pos.y, 0.5, HALF_LENGTH)

func _check_net(prev_y: float) -> void:
	if ball.height >= NET_HEIGHT:
		return
	if signf(prev_y) == signf(ball.pos.y):
		return
	# blocked: stay on the incoming side and drop
	ball.pos.y = signf(prev_y) * 0.1
	ball.vel.y = -ball.vel.y * NET_REBOUND
	ball.vel.x *= 0.5

func _update_ball() -> void:
	if not ball.in_play:
		return
	if ball.swerve != 0.0:
		ball.vel = ball.vel.rotated(ball.swerve * TICK)
	var prev_y := ball.pos.y
	ball.pos += ball.vel * TICK
	_check_net(prev_y)
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
	meter[winner] = minf(1.0, meter[winner] + METER_PER_POINT)
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
	var depth := TARGET_DEPTH
	var speed := lerpf(SHOT_SPEED_MIN, SHOT_SPEED_MAX, p.charge)
	var launch := SHOT_LAUNCH
	var toward_own_baseline: bool = signf(input.move.y) == float(p.side) and absf(input.move.y) > SHOT_STICK_DEADZONE
	var toward_net: bool = signf(input.move.y) == -float(p.side) and absf(input.move.y) > SHOT_STICK_DEADZONE
	if toward_own_baseline:        # lob
		depth = LOB_DEPTH
		speed = LOB_SPEED
		launch = LOB_LAUNCH
	elif toward_net:               # drop shot
		depth = DROP_DEPTH
		speed = DROP_SPEED
		launch = DROP_LAUNCH
	var special: bool = meter[i] >= 1.0 and p.charge >= 0.9
	if special:
		speed = SPECIAL_SPEED
		meter[i] = 0.0
		last_event = "SPECIAL!"
	else:
		meter[i] = minf(1.0, meter[i] + METER_PER_HIT)
	var target := Vector2(aim_x, -p.side * depth)
	ball.vel = (target - ball.pos).normalized() * speed
	ball.v_height = launch
	ball.height = maxf(ball.height, 0.3)
	ball.swerve = SPECIAL_SWERVE if special else 0.0
	ball.bounce_count = 0
	ball.in_play = true
	last_hitter = i
	hit_count += 1
	hit_strength = 2.0 if special else p.charge
	p.charge = 0.0
	if serving and not special:
		is_serve = true
		last_event = ""
	return true
