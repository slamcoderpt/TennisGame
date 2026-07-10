# Milestone 2 "The Point" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the milestone-1 rally into real tennis: net collision, in/out judgment, double-bounce, serves with faults, 15/30/40/deuce/advantage scoring to 3 games, and a HUD — a complete match vs the wall AI.

**Architecture:** All rules live in the deterministic sim ([spec](../specs/2026-07-10-arcade-tennis-design.md)): a new `MatchScore` class holds tennis scoring; `CourtSim` gains point judgment on bounce events, net blocking, serve flow, and a short pause between points. The view gains a `Hud` that reads sim state (no signals). Match restart is handled in `match.gd` by replacing the sim.

**Tech Stack:** Godot 4.7, GDScript only, existing custom headless test harness.

---

## Context for the engineer

- **Working directory for every command:** `C:\1.projetos\godotgames\arcadetennis` (git repo). Execution should happen on a feature branch `milestone-2-the-point` created from `master`.
- **Godot binary:** NOT on PATH. Invoke the full path with the PowerShell call operator:
  `& "C:\Users\CarlosAlmeida\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe"`
  Godot writes results to **stderr** — pipe `2>&1` when using a bash shell.
- **Test runner:** `& "<godot>" --headless --path . -s res://tests/run_tests.gd`. Exit 0 = all pass. Baseline before this plan: **19 passed, 0 failed**.
- **GDScript uses TAB indentation.** All code blocks below are tab-indented — preserve exactly.
- **Court-space conventions:** `x` ∈ [-4, 4], `y` ∈ [-12, 12], human = player 0 on negative-y (bottom), AI = player 1 on positive-y, net at `y = 0`, `height` ≥ 0. Players are clamped to their own half, which is why only the server can ever reach the hovering serve ball — no legality guard needed.
- **Do NOT modify milestone-1 tests.** They must keep passing unchanged. If one fails, stop and report the discrepancy — do not "fix" the test.
- **Scope notes (intentional, do not "improve"):** no service boxes, no serve power meter (milestone 3), no tiebreak (first to 3 games, spec), no let-cord replay, ball on the line counts as IN, a netted ball shows the generic "OUT!" message.

### The point-judgment rule (memorize — it unifies everything)

After player P hits, the ball's **first bounce** must be **in bounds AND on P's opponent's side**. If it is, the rally is live and a **second bounce** wins the point for P. If it isn't (own side, or out anywhere), P loses the point — unless it was a serve, where the first offense is a FAULT (replay) and the second a DOUBLE FAULT (point to receiver). The net needs no scoring logic: it physically blocks the ball, which then lands on the hitter's own side and the rule above does the rest.

---

### Task 1: MatchScore — tennis scoring

**Files:**
- Create: `src/sim/match_score.gd`
- Create: `tests/test_score.gd`
- Modify: `tests/run_tests.gd` (add to TEST_SCRIPTS)

- [ ] **Step 1: Write the failing tests**

`tests/test_score.gd`:

```gdscript
extends "res://tests/test_base.gd"

const MatchScore := preload("res://src/sim/match_score.gd")

func test_point_labels() -> void:
	var s := MatchScore.new()
	check(s.score_text(0) == "0", "no points shows 0")
	s.point_won_by(0)
	check(s.score_text(0) == "15", "first point shows 15")
	s.point_won_by(0)
	check(s.score_text(0) == "30", "second point shows 30")
	s.point_won_by(0)
	check(s.score_text(0) == "40", "third point shows 40")

func test_four_straight_points_win_game() -> void:
	var s := MatchScore.new()
	for i in 4:
		s.point_won_by(0)
	check(s.games[0] == 1, "four straight points must win the game")
	check(s.points[0] == 0 and s.points[1] == 0, "points must reset after a game")

func test_deuce_shows_forty_forty() -> void:
	var s := MatchScore.new()
	for i in 3:
		s.point_won_by(0)
		s.point_won_by(1)
	check(s.score_text(0) == "40" and s.score_text(1) == "40", "deuce shows 40-40")
	check(s.games[0] == 0 and s.games[1] == 0, "deuce must not end the game")

func test_advantage_and_back_to_deuce() -> void:
	var s := MatchScore.new()
	for i in 3:
		s.point_won_by(0)
		s.point_won_by(1)
	s.point_won_by(0)
	check(s.score_text(0) == "Ad" and s.score_text(1) == "40", "leader at deuce has advantage")
	s.point_won_by(1)
	check(s.score_text(0) == "40" and s.score_text(1) == "40", "losing the advantage returns to deuce")

func test_advantage_converts_game() -> void:
	var s := MatchScore.new()
	for i in 3:
		s.point_won_by(0)
		s.point_won_by(1)
	s.point_won_by(0)
	s.point_won_by(0)
	check(s.games[0] == 1, "winning the advantage point must win the game")

func test_three_games_win_match() -> void:
	var s := MatchScore.new()
	for g in 3:
		for p in 4:
			s.point_won_by(0)
	check(s.match_winner == 0, "three games must win the match")
	s.point_won_by(1)
	check(s.points[1] == 0, "no scoring after the match is over")
```

Update `tests/run_tests.gd` TEST_SCRIPTS to:

```gdscript
const TEST_SCRIPTS := [
	"res://tests/test_smoke.gd",
	"res://tests/test_sim.gd",
	"res://tests/test_projection.gd",
	"res://tests/test_ai.gd",
	"res://tests/test_score.gd",
]
```

- [ ] **Step 2: Run tests to verify they fail**

Run the harness. Expected: `FAIL could not load res://tests/test_score.gd` (or parse errors for the missing preload), exit 1.

- [ ] **Step 3: Write the implementation**

`src/sim/match_score.gd`:

```gdscript
extends RefCounted

const POINT_LABELS := ["0", "15", "30", "40"]
const GAMES_TO_WIN := 3

var points := [0, 0]        # raw point counts within the current game
var games := [0, 0]
var match_winner := -1      # -1 = match ongoing, else winning player index

func point_won_by(i: int) -> void:
	if match_winner != -1:
		return
	points[i] += 1
	if points[i] >= 4 and points[i] - points[1 - i] >= 2:
		points = [0, 0]
		games[i] += 1
		if games[i] >= GAMES_TO_WIN:
			match_winner = i

func score_text(i: int) -> String:
	if points[0] >= 3 and points[1] >= 3:
		return "Ad" if points[i] > points[1 - i] else "40"
	return POINT_LABELS[mini(points[i], 3)]
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: `25 passed, 0 failed` (19 baseline + 6), exit 0.

- [ ] **Step 5: Commit**

```bash
git add src/sim/match_score.gd tests/
git commit -m "feat: tennis scoring with deuce, advantage, games and match win"
```

---

### Task 2: Point judgment, serve flow, and pause

This is the heart of the milestone: `court_sim.gd` is rewritten to its final milestone-2 form **except net collision** (Task 3). The full file content is given below — replace `src/sim/court_sim.gd` entirely.

**Files:**
- Modify: `src/sim/court_sim.gd` (full replacement, listing below)
- Create: `tests/test_rules.gd`
- Modify: `tests/run_tests.gd` (add to TEST_SCRIPTS)

- [ ] **Step 1: Write the failing tests**

`tests/test_rules.gd`:

```gdscript
extends "res://tests/test_base.gd"

const CourtSim := preload("res://src/sim/court_sim.gd")
const InputFrame := preload("res://src/sim/input_frame.gd")

func _idle() -> Array:
	return [InputFrame.new(), InputFrame.new()]

func _tick_n(sim, n: int) -> void:
	for i in n:
		sim.tick(_idle())

func _rally_ball(sim, pos: Vector2, vel: Vector2, height: float, v_height := 0.0) -> void:
	# put the sim into a mid-rally state as if player 0 just hit the ball
	sim.last_hitter = 0
	sim.is_serve = false
	sim.ball.in_play = true
	sim.ball.pos = pos
	sim.ball.vel = vel
	sim.ball.height = height
	sim.ball.v_height = v_height

func test_double_bounce_wins_point() -> void:
	var sim := CourtSim.new()
	_rally_ball(sim, Vector2(0, 5), Vector2(0, 2), 1.0)
	_tick_n(sim, 90)
	check(sim.score.points[0] == 1, "double bounce on receiver side must score for the hitter")

func test_bounce_out_loses_point() -> void:
	var sim := CourtSim.new()
	_rally_ball(sim, Vector2(0, 5), Vector2(16, 4), 1.0)
	_tick_n(sim, 60)
	check(sim.score.points[1] == 1, "landing out must score for the opponent")

func test_receiver_must_let_serve_bounce() -> void:
	var sim := CourtSim.new()
	sim.players[1].pos = Vector2(0.0, 3.5)
	var frames := _idle()
	frames[0].hit_pressed = true
	frames[1].hit_pressed = true
	sim.tick(frames)
	var pressing := _idle()
	pressing[1].hit_pressed = true
	for i in 200:
		sim.tick(pressing)
		if sim.ball.bounce_count >= 1:
			break
		check(sim.ball.vel.y > 0.0, "serve must not be returnable before it bounces")

func test_serve_fault_gives_second_serve() -> void:
	var sim := CourtSim.new()
	var frames := _idle()
	frames[0].hit_pressed = true
	sim.tick(frames)
	# force the serve to land on the server's own side -> fault
	sim.ball.pos = Vector2(0, -4)
	sim.ball.vel = Vector2.ZERO
	sim.ball.height = 0.5
	sim.ball.v_height = 0.0
	_tick_n(sim, 30)
	check(sim.serve_faults == 1, "own-side landing on the serve must be a fault")
	check(sim.score.points[0] == 0 and sim.score.points[1] == 0, "a first fault must not score")
	_tick_n(sim, CourtSim.POINT_PAUSE_TICKS + 2)
	check(not sim.ball.in_play and sim.ball.pos.y < 0.0, "ball must re-hover on the server side for the second serve")

func test_double_fault_scores_for_receiver() -> void:
	var sim := CourtSim.new()
	for attempt in 2:
		var frames := _idle()
		frames[0].hit_pressed = true
		sim.tick(frames)
		sim.ball.pos = Vector2(0, -4)
		sim.ball.vel = Vector2.ZERO
		sim.ball.height = 0.5
		sim.ball.v_height = 0.0
		_tick_n(sim, 30 + CourtSim.POINT_PAUSE_TICKS)
	check(sim.score.points[1] == 1, "double fault must score for the receiver")
	check(sim.serve_faults == 0, "faults must reset after the point")

func test_server_alternates_each_game() -> void:
	var sim := CourtSim.new()
	for i in 4:
		sim._end_point(0, "")
	check(sim.server == 1, "server must alternate after a game ends")
	_tick_n(sim, CourtSim.POINT_PAUSE_TICKS + 2)
	check(sim.ball.pos.y > 0.0, "ball must hover on the new server's side")

func test_match_over_freezes_sim() -> void:
	var sim := CourtSim.new()
	for i in 12:
		sim._end_point(0, "")
	check(sim.score.match_winner == 0, "12 straight points must win the match")
	var frames := _idle()
	frames[0].move = Vector2(1, 0)
	var before: Vector2 = sim.players[0].pos
	sim.tick(frames)
	check(sim.players[0].pos == before, "sim must freeze after the match ends")
```

Update `tests/run_tests.gd` TEST_SCRIPTS to:

```gdscript
const TEST_SCRIPTS := [
	"res://tests/test_smoke.gd",
	"res://tests/test_sim.gd",
	"res://tests/test_projection.gd",
	"res://tests/test_ai.gd",
	"res://tests/test_score.gd",
	"res://tests/test_rules.gd",
]
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: failures/errors in `test_rules.gd` (missing `score`, `last_hitter`, `_end_point`...), exit 1. Milestone-1 tests must still pass at this step.

- [ ] **Step 3: Replace `src/sim/court_sim.gd` entirely with:**

```gdscript
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
```

Key behaviors to preserve exactly:
- `reset_for_serve` (renamed from `reset_ball`) places the hover ball on the **server's** side and clears `hit_buffer`s so a stale buffered press can't auto-serve after the pause.
- The pause block in `tick()` runs after player movement (players can still walk) but skips ball physics and hits.
- `_ball_flew_out` with `last_hitter == -1` (test-poked dead balls) just resets — no scoring. This keeps every milestone-1 test passing.
- `_try_hit` now takes the player **index** (needed for `last_hitter`); the callers in `tick()` pass `i`.

- [ ] **Step 4: Run tests to verify they pass**

Expected: `32 passed, 0 failed` (25 + 7), exit 0. **All 19 milestone-1 tests must be among the passing** — if any old test fails, stop and report; do not modify it.

- [ ] **Step 5: Commit**

```bash
git add src/sim/court_sim.gd tests/
git commit -m "feat: point judgment, serve flow with faults, and post-point pause"
```

---

### Task 3: Net collision

**Files:**
- Modify: `src/sim/court_sim.gd` (add one const, one call site, one method)
- Modify: `tests/test_rules.gd` (append tests)

- [ ] **Step 1: Append the failing tests to `tests/test_rules.gd`**

```gdscript
func test_net_blocks_low_ball() -> void:
	var sim := CourtSim.new()
	_rally_ball(sim, Vector2(0, -1), Vector2(0, 20), 0.4, 2.0)
	_tick_n(sim, 6)
	check(sim.ball.pos.y < 0.0, "low ball must be blocked by the net")
	check(sim.ball.vel.y < 0.0, "blocked ball must rebound")
	_tick_n(sim, 120)
	check(sim.score.points[1] == 1, "netted ball must cost the hitter the point")

func test_high_ball_clears_net() -> void:
	var sim := CourtSim.new()
	_rally_ball(sim, Vector2(0, -1), Vector2(0, 20), 2.0)
	_tick_n(sim, 6)
	check(sim.ball.pos.y > 0.0, "high ball must pass over the net")
```

- [ ] **Step 2: Run tests to verify the new ones fail**

Expected: `FAIL test_rules.gd.test_net_blocks_low_ball ...` (the low ball sails through today), exit 1.

- [ ] **Step 3: Implement net blocking in `src/sim/court_sim.gd`**

Add the constant below `const NET_HEIGHT := 1.0`:

```gdscript
const NET_REBOUND := 0.25       # how much of vel.y survives a net hit, reversed
```

In `_update_ball`, capture the pre-move y and check the net right after the position update, so it reads:

```gdscript
func _update_ball() -> void:
	if not ball.in_play:
		return
	var prev_y := ball.pos.y
	ball.pos += ball.vel * TICK
	_check_net(prev_y)
	ball.v_height -= GRAVITY * TICK
	...rest unchanged...
```

Add the method after `_move_player`:

```gdscript
func _check_net(prev_y: float) -> void:
	if ball.height >= NET_HEIGHT:
		return
	if signf(prev_y) == signf(ball.pos.y):
		return
	# blocked: stay on the incoming side and drop
	ball.pos.y = signf(prev_y) * 0.1
	ball.vel.y = -ball.vel.y * NET_REBOUND
	ball.vel.x *= 0.5
```

No scoring code is needed: the blocked ball lands on the hitter's own side and `_judge_bounce` awards the point (or serve fault) automatically.

- [ ] **Step 4: Run tests to verify they pass**

Expected: `34 passed, 0 failed`, exit 0. (The milestone-1 serve/AI tests still pass because serves and returns cross the net at height ≈ 1.9–2.5.)

- [ ] **Step 5: Commit**

```bash
git add src/sim/court_sim.gd tests/test_rules.gd
git commit -m "feat: net physically blocks low balls"
```

---

### Task 4: HUD and match restart

**Files:**
- Create: `src/view/hud.gd`
- Modify: `src/view/match.gd` (full replacement, listing below)
- Modify: `src/view/court_view.gd` (one line in `_draw_reach`)

- [ ] **Step 1: Create `src/view/hud.gd`:**

```gdscript
extends Node2D

const NAMES := ["YOU", "CPU"]

var sim = null

func render(s) -> void:
	sim = s
	queue_redraw()

func _draw() -> void:
	if sim == null:
		return
	var font := ThemeDB.fallback_font
	var games := "%s %d - %d %s" % [NAMES[0], sim.score.games[0], sim.score.games[1], NAMES[1]]
	draw_string(font, Vector2(20, 40), games, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	var points := "%s - %s" % [sim.score.score_text(0), sim.score.score_text(1)]
	draw_string(font, Vector2(540, 40), points, HORIZONTAL_ALIGNMENT_CENTER, 200, 28, Color.WHITE)
	if sim.score.match_winner != -1:
		var msg := "%s WINS! (hit to restart)" % NAMES[sim.score.match_winner]
		draw_string(font, Vector2(340, 300), msg, HORIZONTAL_ALIGNMENT_CENTER, 600, 40, Color.YELLOW)
	elif sim.last_event != "":
		draw_string(font, Vector2(340, 300), sim.last_event, HORIZONTAL_ALIGNMENT_CENTER, 600, 36, Color.ORANGE)
	elif not sim.ball.in_play and sim.pause_ticks == 0:
		draw_string(font, Vector2(490, 640), "%s SERVE" % NAMES[sim.server], HORIZONTAL_ALIGNMENT_CENTER, 300, 22, Color(1, 1, 1, 0.6))
```

- [ ] **Step 2: Replace `src/view/match.gd` entirely with:**

```gdscript
extends Node2D

const CourtSim := preload("res://src/sim/court_sim.gd")
const CourtView := preload("res://src/view/court_view.gd")
const Hud := preload("res://src/view/hud.gd")
const PlayerInput := preload("res://src/input/player_input.gd")
const WallAI := preload("res://src/ai/wall_ai.gd")

var sim := CourtSim.new()
var view: Node2D
var hud: Node2D
var player_input: Node2D
var ai := WallAI.new()

func _ready() -> void:
	view = CourtView.new()
	add_child(view)
	hud = Hud.new()
	add_child(hud)
	player_input = PlayerInput.new()
	add_child(player_input)

func _physics_process(_delta: float) -> void:
	var frame = player_input.consume_frame()
	if sim.score.match_winner != -1:
		if frame.hit_pressed:
			sim = CourtSim.new()
		return
	sim.tick([frame, ai.frame(sim)])

func _process(_delta: float) -> void:
	view.render(sim)
	hud.render(sim)
```

- [ ] **Step 3: Keep the debug reach ring honest about serves**

In `src/view/court_view.gd`, `_draw_reach`, replace the `incoming` line with:

```gdscript
	var incoming: bool = not b.in_play or (signf(b.vel.y) == float(p.side) and not sim.is_serve)
```

(The sim now refuses to return a serve before it bounces; the green ring must not claim otherwise.)

- [ ] **Step 4: Verify tests and clean boot**

Run the harness. Expected: `34 passed, 0 failed`.

Run: `& "<godot>" --path . --quit-after 180 2>&1`
Expected: no `SCRIPT ERROR` / `Parse Error` / `Cannot call` lines. (A human visual check happens in Task 5.)

- [ ] **Step 5: Commit**

```bash
git add src/view/
git commit -m "feat: score HUD, event messages and match restart"
```

---

### Task 5: Integration verification and README

**Files:**
- Modify: `README.md` (replace the milestone status section)

- [ ] **Step 1: Full suite + boot**

Run the harness. Expected: `34 passed, 0 failed`, exit 0.
Run: `& "<godot>" --path . --quit-after 180 2>&1` — clean, no script errors.

- [ ] **Step 2: Manual match check (controller/human)**

Play a few points windowed (`& "<godot>" --path .`): serve lands in and rallies; a netted shot drops back and shows a point/fault; score line updates through 15/30/40; after a game the CPU serves (ball hovers on its side and it serves by itself); winning 3 games shows the banner and hit restarts.

- [ ] **Step 3: Update `README.md`** — replace the `## Milestone 1 status: The Rally` section (title and paragraph) with:

```markdown
## Milestone 2 status: The Point

Full tennis points: serves with faults and double faults, net collision,
in/out judgment, double-bounce rule, 15/30/40/deuce/advantage scoring,
first to 3 games, HUD with score and messages. Hit after match point to
restart. Milestone 3 adds charge shots, lob/drop, the super meter, sprites
and the game-feel pass.
```

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "feat: milestone 2 complete - full points and tennis scoring"
```

---

## Out of scope (later milestones)

Milestone 3 ("The Game"): charge shots (hold-to-charge with the movement lock), lob/drop via stick position, super meter, serve power-timing meter, service boxes, hit-pause/screen-shake feel pass, first real character sprites. Milestones 4–5: roster, courts with gameplay rules, arcade ladder, menus, mobile builds.
