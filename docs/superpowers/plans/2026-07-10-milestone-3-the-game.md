# Milestone 3 "The Game" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add depth to the point: hold-to-charge shots with a movement lock, lob/drop via stick direction, a super meter that fires a swerving special, game-feel juice (charge ring, hit-pause, screen shake), and the first character sprite (rendering pipeline with a code-generated placeholder).

**Architecture:** Charge and shot-shaping stay in the deterministic sim ([spec](../specs/2026-07-10-arcade-tennis-design.md)); the input layer gains a held/released model that is backward-compatible with the existing `hit_pressed` swing edge. Feel effects (charge ring, hit-pause, shake) live in the view/controller and read tiny transient sim fields — the sim stays pure and deterministic. Sprites render through a billboarded, depth-scaled texture path fed by a placeholder texture generated in code.

**Tech Stack:** Godot 4.7, GDScript only, existing custom headless test harness.

---

## Context for the engineer

- **Working directory for every command:** `C:\1.projetos\godotgames\arcadetennis` (git repo). Execution should happen on a feature branch `milestone-3-the-game` created from `master`.
- **Godot binary:** NOT on PATH. Invoke the full path with the PowerShell call operator:
  `& "C:\Users\CarlosAlmeida\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe"`
  Godot writes results to **stderr** — pipe `2>&1` when using a bash shell.
- **Test runner:** `& "<godot>" --headless --path . -s res://tests/run_tests.gd`. Exit 0 = all pass. Baseline before this plan: **34 passed, 0 failed**.
- **GDScript uses TAB indentation.** All code blocks below are tab-indented — preserve exactly.
- **Do NOT modify existing tests** (`test_sim.gd`, `test_score.gd`, `test_rules.gd`, `test_ai.gd`, `test_projection.gd`, `test_smoke.gd`). They must keep passing unchanged. The whole charge design is backward-compatible specifically so they don't need touching. If one fails, stop and report — don't "fix" the test.
- **Court-space conventions:** `x` ∈ [-4,4], `y` ∈ [-12,12]; player 0 (human) side=-1 (bottom), player 1 (AI) side=+1 (top); net at y=0; `InputFrame.move.y = +1` = toward the far side. So for player P, "stick toward my own baseline" means `signf(move.y) == P.side`, and "stick toward the net" means `signf(move.y) == -P.side`.

### The charge input model (memorize)

`InputFrame` carries both `hit_held` (bool, true every tick the button is down) and `hit_pressed` (bool, true on the single tick the swing should fire). Real input holds the button (building charge, movement locked) and sets `hit_pressed` on the *release* edge. Tests inject `hit_pressed = true` directly with no hold → charge 0 → a plain quick shot, exactly like milestone 2. The sim never assumes how the flags were produced.

### Scope deferred (do not build): serve power-timing meter, service boxes, per-character unique specials (one shared swerving special this milestone), real pixel-art assets (placeholder only).

---

### Task 1: Charge shots and the movement lock

**Files:**
- Modify: `src/sim/input_frame.gd` (add `hit_held`)
- Modify: `src/sim/player_state.gd` (add `charge`)
- Modify: `src/sim/court_sim.gd` (charge accrual, movement lock, charge-scaled speed)
- Modify: `src/input/player_input.gd` (produce `hit_held` + release-edge `hit_pressed`)
- Create: `tests/test_charge.gd`
- Modify: `tests/run_tests.gd` (add to TEST_SCRIPTS)

- [ ] **Step 1: Write the failing tests** — create `tests/test_charge.gd`:

```gdscript
extends "res://tests/test_base.gd"

const CourtSim := preload("res://src/sim/court_sim.gd")
const InputFrame := preload("res://src/sim/input_frame.gd")

func _held() -> InputFrame:
	var f := InputFrame.new()
	f.hit_held = true
	return f

func test_charge_builds_while_held() -> void:
	var sim := CourtSim.new()
	for i in 20:
		sim.tick([_held(), InputFrame.new()])
	check(sim.players[0].charge > 0.0, "charge must build while the hit is held")

func test_charge_locks_movement() -> void:
	var sim := CourtSim.new()
	var f := _held()
	f.move = Vector2(1, 0)
	var start: Vector2 = sim.players[0].pos
	for i in 10:
		sim.tick([f, InputFrame.new()])
	check(sim.players[0].pos == start, "holding charge must lock movement")

func test_charged_shot_faster_than_tap() -> void:
	var tap := CourtSim.new()
	var t := InputFrame.new()
	t.hit_pressed = true
	tap.tick([t, InputFrame.new()])
	var tap_speed: float = tap.ball.vel.length()

	var chg := CourtSim.new()
	for i in 45:
		chg.tick([_held(), InputFrame.new()])   # hold to full charge, no fire
	var rel := InputFrame.new()
	rel.hit_pressed = true                        # release edge fires the swing
	chg.tick([rel, InputFrame.new()])
	var chg_speed: float = chg.ball.vel.length()

	check(chg_speed > tap_speed + 1.0, "a charged shot must leave faster than a tap")

func test_charge_resets_after_shot() -> void:
	var sim := CourtSim.new()
	for i in 20:
		sim.tick([_held(), InputFrame.new()])
	check(sim.players[0].charge > 0.0, "charge should have built")
	var rel := InputFrame.new()
	rel.hit_pressed = true
	sim.tick([rel, InputFrame.new()])
	check(sim.players[0].charge == 0.0, "charge must reset after the swing")
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
	"res://tests/test_charge.gd",
]
```

- [ ] **Step 2: Run tests to verify they fail**

Run the harness. Expected: failures in `test_charge.gd` (no `charge` field, charge never builds), exit 1. The other 34 must still pass.

- [ ] **Step 3a: Add `hit_held` to `src/sim/input_frame.gd`.** Replace the whole file with:

```gdscript
extends RefCounted

var move := Vector2.ZERO       # court-space direction, length <= 1, +y = toward far side
var hit_held := false          # true every tick the hit button is down (builds charge, locks movement)
var hit_pressed := false       # true on the single tick the swing fires (release edge, or a tap in tests)
```

- [ ] **Step 3b: Add `charge` to `src/sim/player_state.gd`.** Replace the whole file with:

```gdscript
extends RefCounted

var pos := Vector2.ZERO
var prev_pos := Vector2.ZERO
var side := -1                 # -1 = bottom (near camera, human), +1 = top
var hit_buffer := 0            # ticks the swing stays armed after a hit press
var charge := 0.0              # 0..1 wind-up while the hit is held
```

- [ ] **Step 3c: In `src/sim/court_sim.gd`, replace the shot-speed constant.** Find:

```gdscript
const SHOT_SPEED := 16.0
```

Replace with:

```gdscript
const SHOT_SPEED_MIN := 16.0    # tap speed (matches the old flat SHOT_SPEED)
const SHOT_SPEED_MAX := 26.0    # full-charge speed
const CHARGE_TIME := 0.6        # seconds of hold to reach full charge
```

- [ ] **Step 3d: Lock movement while charging.** In `src/sim/court_sim.gd`, find the start of `_move_player`:

```gdscript
func _move_player(p, input) -> void:
	var m: Vector2 = input.move
```

Replace with:

```gdscript
func _move_player(p, input) -> void:
	if input.hit_held:
		return                  # charging locks the player in place
	var m: Vector2 = input.move
```

- [ ] **Step 3e: Accrue and reset charge in `tick()`.** Find the hit-processing block:

```gdscript
	_update_ball()
	for i in 2:
		if inputs[i].hit_pressed:
			players[i].hit_buffer = HIT_BUFFER_TICKS
		if players[i].hit_buffer > 0:
			players[i].hit_buffer -= 1
			if _try_hit(i, inputs[i]):
				players[i].hit_buffer = 0
```

Replace with:

```gdscript
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
```

- [ ] **Step 3f: Scale shot speed by charge and reset it.** In `_try_hit`, find:

```gdscript
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

Replace with:

```gdscript
	var aim_x := clampf(input.move.x, -1.0, 1.0) * AIM_MAX_X
	var target := Vector2(aim_x, -p.side * TARGET_DEPTH)
	var speed := lerpf(SHOT_SPEED_MIN, SHOT_SPEED_MAX, p.charge)
	ball.vel = (target - ball.pos).normalized() * speed
	ball.v_height = SHOT_LAUNCH
	ball.height = maxf(ball.height, 0.3)
	ball.bounce_count = 0
	ball.in_play = true
	last_hitter = i
	p.charge = 0.0
	if serving:
		is_serve = true
		last_event = ""
	return true
```

- [ ] **Step 3g: Produce the held/release input.** Replace the whole `src/input/player_input.gd` with:

```gdscript
extends Node2D

const InputFrame := preload("res://src/sim/input_frame.gd")

const JOY_RADIUS := 110.0

var joy_id := -1
var joy_origin := Vector2.ZERO
var joy_current := Vector2.ZERO
var hit_touch := -1            # touch index held on the right half, -1 = none
var _was_down := false         # hit state last frame, to detect the release edge

func _input(event: InputEvent) -> void:
	var half := get_viewport_rect().size.x / 2.0
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < half and joy_id == -1:
				joy_id = event.index
				joy_origin = event.position
				joy_current = event.position
				queue_redraw()
			elif event.position.x >= half and hit_touch == -1:
				hit_touch = event.index
		else:
			if event.index == joy_id:
				joy_id = -1
				queue_redraw()
			elif event.index == hit_touch:
				hit_touch = -1
	elif event is InputEventScreenDrag and event.index == joy_id:
		joy_current = event.position
		queue_redraw()

func consume_frame():
	var f := InputFrame.new()
	var kb := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	f.move = Vector2(kb.x, -kb.y)
	if joy_id != -1:
		var v := (joy_current - joy_origin) / JOY_RADIUS
		if v.length() > 1.0:
			v = v.normalized()
		f.move = Vector2(v.x, -v.y)
	var down := Input.is_action_pressed("ui_accept") or hit_touch != -1
	f.hit_held = down
	f.hit_pressed = _was_down and not down    # fire on release
	_was_down = down
	return f

func _draw() -> void:
	if joy_id == -1:
		return
	draw_circle(joy_origin, JOY_RADIUS, Color(1, 1, 1, 0.08))
	draw_arc(joy_origin, JOY_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.25), 2.0)
	var knob := joy_origin + (joy_current - joy_origin).limit_length(JOY_RADIUS)
	draw_circle(knob, 28.0, Color(1, 1, 1, 0.3))
```

(`wall_ai.gd` needs NO change — it already sets `hit_pressed`, which still fires; the AI simply doesn't charge this milestone.)

- [ ] **Step 4: Run tests to verify they pass**

Expected: `38 passed, 0 failed` (34 + 4), exit 0. **All 34 prior tests must remain green** — they never set `hit_held`, so charge stays 0 and shots fire exactly as before. If any regress, stop and report.

- [ ] **Step 5: Commit**

```bash
git add src/sim/input_frame.gd src/sim/player_state.gd src/sim/court_sim.gd src/input/player_input.gd tests/
git commit -m "feat: hold-to-charge shots with movement lock and charge-scaled power"
```

---

### Task 2: Lob and drop shots

**Files:**
- Modify: `src/sim/court_sim.gd` (shot-shape branch in `_try_hit` + constants)
- Create: `tests/test_shots.gd`
- Modify: `tests/run_tests.gd` (add to TEST_SCRIPTS)

- [ ] **Step 1: Write the failing tests** — create `tests/test_shots.gd`:

```gdscript
extends "res://tests/test_base.gd"

const CourtSim := preload("res://src/sim/court_sim.gd")
const InputFrame := preload("res://src/sim/input_frame.gd")

# Put a returnable ball right on player 0 and fire once with the given stick.
func _hit_with_stick(stick: Vector2) -> CourtSim:
	var sim := CourtSim.new()
	sim.last_hitter = 1
	sim.is_serve = false
	sim.ball.in_play = true
	sim.ball.pos = Vector2(0, -2)       # near the net, so a drop can clear it onto the far side
	sim.ball.vel = Vector2(0, -6)
	sim.ball.height = 1.0
	sim.ball.v_height = 0.0
	sim.players[0].pos = Vector2(0, -2)
	var f := InputFrame.new()
	f.hit_pressed = true
	f.move = stick
	sim.tick([f, InputFrame.new()])
	return sim

func test_lob_launches_higher_than_flat() -> void:
	var flat := _hit_with_stick(Vector2.ZERO)
	var lob := _hit_with_stick(Vector2(0, -1))   # player 0 side=-1: stick toward own baseline
	check(lob.ball.v_height > flat.ball.v_height, "a lob must launch higher than a flat drive")

func test_drop_slower_than_flat() -> void:
	var flat := _hit_with_stick(Vector2.ZERO)
	var drop := _hit_with_stick(Vector2(0, 1))    # stick toward the net
	check(drop.ball.vel.length() < flat.ball.vel.length(), "a drop shot must be slower than a flat drive")

func test_drop_lands_shorter_than_flat() -> void:
	var flat := _hit_with_stick(Vector2.ZERO)
	var drop := _hit_with_stick(Vector2(0, 1))
	for i in 180:
		flat.tick([InputFrame.new(), InputFrame.new()])
		drop.tick([InputFrame.new(), InputFrame.new()])
		if flat.ball.bounce_count >= 1 and drop.ball.bounce_count >= 1:
			break
	# both should have bounced on the far side; the drop bounce is nearer the net
	check(drop.ball.pos.y < flat.ball.pos.y, "a drop shot must land nearer the net than a flat drive")
```

Update `tests/run_tests.gd` TEST_SCRIPTS to append `"res://tests/test_shots.gd"` as the last entry:

```gdscript
const TEST_SCRIPTS := [
	"res://tests/test_smoke.gd",
	"res://tests/test_sim.gd",
	"res://tests/test_projection.gd",
	"res://tests/test_ai.gd",
	"res://tests/test_score.gd",
	"res://tests/test_rules.gd",
	"res://tests/test_charge.gd",
	"res://tests/test_shots.gd",
]
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: `test_shots.gd` failures (lob/drop behave identically to flat today), exit 1.

- [ ] **Step 3: Add the shot-shape constants and branch.** In `src/sim/court_sim.gd`, find:

```gdscript
const CHARGE_TIME := 0.6        # seconds of hold to reach full charge
```

Add immediately after it:

```gdscript
const LOB_SPEED := 10.0          # slow, high, deep
const LOB_LAUNCH := 12.0
const LOB_DEPTH := HALF_LENGTH - 1.0
const DROP_SPEED := 7.0          # soft, low, just over the net
const DROP_LAUNCH := 3.0
const DROP_DEPTH := 2.0
const SHOT_STICK_DEADZONE := 0.5
```

Then find the shot-launch block in `_try_hit` (from Task 1):

```gdscript
	var aim_x := clampf(input.move.x, -1.0, 1.0) * AIM_MAX_X
	var target := Vector2(aim_x, -p.side * TARGET_DEPTH)
	var speed := lerpf(SHOT_SPEED_MIN, SHOT_SPEED_MAX, p.charge)
	ball.vel = (target - ball.pos).normalized() * speed
	ball.v_height = SHOT_LAUNCH
```

Replace it with:

```gdscript
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
	var target := Vector2(aim_x, -p.side * depth)
	ball.vel = (target - ball.pos).normalized() * speed
	ball.v_height = launch
```

Leave the rest of `_try_hit` (height clamp, bounce reset, `in_play`, `last_hitter`, charge reset, serve flag) unchanged.

- [ ] **Step 4: Run tests to verify they pass**

Expected: `41 passed, 0 failed` (38 + 3), exit 0. Existing tests still green — `test_aim_follows_stick` uses `move=(-1,0)` (no y component past the deadzone) so it still produces a flat drive.

- [ ] **Step 5: Commit**

```bash
git add src/sim/court_sim.gd tests/
git commit -m "feat: lob and drop shots selected by stick direction"
```

---

### Task 3: Super meter and the special shot

**Files:**
- Modify: `src/sim/court_sim.gd` (meter state, accrual, special branch, swerve)
- Modify: `src/sim/ball_state.gd` (add `swerve`)
- Create: `tests/test_meter.gd`
- Modify: `tests/run_tests.gd` (add to TEST_SCRIPTS)

- [ ] **Step 1: Write the failing tests** — create `tests/test_meter.gd`:

```gdscript
extends "res://tests/test_base.gd"

const CourtSim := preload("res://src/sim/court_sim.gd")
const InputFrame := preload("res://src/sim/input_frame.gd")

func _serve_tap(sim) -> void:
	var f := InputFrame.new()
	f.hit_pressed = true
	sim.tick([f, InputFrame.new()])

func test_meter_fills_on_hit() -> void:
	var sim := CourtSim.new()
	_serve_tap(sim)
	check(sim.meter[0] > 0.0, "hitting the ball must add to the hitter's meter")

func test_meter_persists_across_points() -> void:
	var sim := CourtSim.new()
	sim.meter[0] = 0.5
	sim._end_point(0, "")
	check(sim.meter[0] >= 0.5, "the meter must persist across points (and gain on a won point)")

func test_special_needs_full_meter_and_full_charge() -> void:
	# full meter but weak charge -> ordinary shot, no swerve, meter kept
	var weak := CourtSim.new()
	weak.meter[0] = 1.0
	var tap := InputFrame.new()
	tap.hit_pressed = true
	weak.tick([tap, InputFrame.new()])
	check(weak.ball.swerve == 0.0, "a tap must not spend the special even with a full meter")
	check(weak.meter[0] == 1.0, "meter must not drain without a special")

	# full meter and full charge -> special: swerve set, meter drained
	var strong := CourtSim.new()
	strong.meter[0] = 1.0
	for i in 45:
		var h := InputFrame.new()
		h.hit_held = true
		strong.tick([h, InputFrame.new()])
	var rel := InputFrame.new()
	rel.hit_pressed = true
	strong.tick([rel, InputFrame.new()])
	check(strong.ball.swerve != 0.0, "a full-charge swing on a full meter must fire a swerving special")
	check(strong.meter[0] == 0.0, "the special must drain the meter")

func test_special_ball_curves() -> void:
	var sim := CourtSim.new()
	sim.meter[0] = 1.0
	for i in 45:
		var h := InputFrame.new()
		h.hit_held = true
		sim.tick([h, InputFrame.new()])
	var rel := InputFrame.new()
	rel.hit_pressed = true
	sim.tick([rel, InputFrame.new()])
	var vx0: float = sim.ball.vel.x
	for i in 10:
		sim.tick([InputFrame.new(), InputFrame.new()])
	check(sim.ball.vel.x != vx0, "a special ball's horizontal velocity must curve over time")
```

Update `tests/run_tests.gd` to append `"res://tests/test_meter.gd"` as the last TEST_SCRIPTS entry.

- [ ] **Step 2: Run tests to verify they fail**

Expected: `test_meter.gd` failures (no `meter`, no `ball.swerve`), exit 1.

- [ ] **Step 3a: Add `swerve` to `src/sim/ball_state.gd`.** Replace the whole file with:

```gdscript
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
```

- [ ] **Step 3b: Add meter state and constants to `src/sim/court_sim.gd`.** Find:

```gdscript
const POINT_PAUSE_TICKS := 45   # short freeze after a point so the result reads
```

Add immediately after it:

```gdscript
const METER_PER_HIT := 0.12     # meter gained by the hitter each swing
const METER_PER_POINT := 0.25   # meter gained by the winner of a point
const SPECIAL_SPEED := 30.0     # special shot is faster than a normal full charge
const SPECIAL_SWERVE := 3.0     # radians/sec the special ball curves
```

Then find the state block:

```gdscript
var pause_ticks := 0
var last_event := ""            # transient HUD message ("FAULT", "OUT!", ...)
```

Replace it with:

```gdscript
var pause_ticks := 0
var last_event := ""            # transient HUD message ("FAULT", "OUT!", ...)
var meter := [0.0, 0.0]         # 0..1 super meter per player; persists across points, not matches
```

- [ ] **Step 3c: Apply swerve while the ball flies.** In `_update_ball`, find:

```gdscript
	var prev_y := ball.pos.y
	ball.pos += ball.vel * TICK
	_check_net(prev_y)
```

Replace with:

```gdscript
	if ball.swerve != 0.0:
		ball.vel = ball.vel.rotated(ball.swerve * TICK)
	var prev_y := ball.pos.y
	ball.pos += ball.vel * TICK
	_check_net(prev_y)
```

- [ ] **Step 3d: Award meter on a won point.** In `_end_point`, find:

```gdscript
	var games_before: int = score.games[0] + score.games[1]
	score.point_won_by(winner)
```

Replace with:

```gdscript
	meter[winner] = minf(1.0, meter[winner] + METER_PER_POINT)
	var games_before: int = score.games[0] + score.games[1]
	score.point_won_by(winner)
```

- [ ] **Step 3e: Meter accrual and the special branch in `_try_hit`.** Find the tail of `_try_hit` (from Task 2), which now reads:

```gdscript
	var target := Vector2(aim_x, -p.side * depth)
	ball.vel = (target - ball.pos).normalized() * speed
	ball.v_height = launch
	ball.height = maxf(ball.height, 0.3)
	ball.bounce_count = 0
	ball.in_play = true
	last_hitter = i
	p.charge = 0.0
	if serving:
		is_serve = true
		last_event = ""
	return true
```

Replace it with:

```gdscript
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
	p.charge = 0.0
	if serving and not special:
		is_serve = true
		last_event = ""
	return true
```

(Note: `p.charge` is read for the `special` test before it is reset at the end — order matters, keep it.)

- [ ] **Step 3f: Clear swerve when the ball resets.** In `reset_for_serve`, find:

```gdscript
	ball.bounce_count = 0
	ball.in_play = false
```

Replace with:

```gdscript
	ball.bounce_count = 0
	ball.in_play = false
	ball.swerve = 0.0
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: `45 passed, 0 failed` (41 + 4), exit 0. Existing tests still green (meter starts at 0, no special fires from a plain tap).

- [ ] **Step 5: Commit**

```bash
git add src/sim/court_sim.gd src/sim/ball_state.gd tests/
git commit -m "feat: super meter and a swerving special shot"
```

---

### Task 4: Game feel — charge ring, hit-pause, screen shake

**Files:**
- Modify: `src/sim/court_sim.gd` (two transient fields the view reads: `hit_count`, `hit_strength`)
- Modify: `src/view/court_view.gd` (charge ring around player 0)
- Modify: `src/view/match.gd` (hit-pause + screen shake driven by `hit_count`)
- Modify: `src/view/hud.gd` (super-meter bars)
- Create: `tests/test_feel.gd`
- Modify: `tests/run_tests.gd` (add to TEST_SCRIPTS)

- [ ] **Step 1: Write the failing test** — create `tests/test_feel.gd`:

```gdscript
extends "res://tests/test_base.gd"

const CourtSim := preload("res://src/sim/court_sim.gd")
const InputFrame := preload("res://src/sim/input_frame.gd")

func test_hit_count_increments_on_each_swing() -> void:
	var sim := CourtSim.new()
	check(sim.hit_count == 0, "hit_count starts at zero")
	var held := InputFrame.new()
	held.hit_held = true
	for i in 10:
		sim.tick([held, InputFrame.new()])       # build some charge first
	var rel := InputFrame.new()
	rel.hit_pressed = true
	sim.tick([rel, InputFrame.new()])            # release fires the swing
	check(sim.hit_count == 1, "a swing must increment hit_count")
	check(sim.hit_strength > 0.0, "hit_strength must record the (charged) shot power")
```

Update `tests/run_tests.gd` to append `"res://tests/test_feel.gd"`.

- [ ] **Step 2: Run tests to verify it fails**

Expected: `test_feel.gd` fails (no `hit_count`), exit 1.

- [ ] **Step 3a: Add the transient hit fields to `src/sim/court_sim.gd`.** Find:

```gdscript
var meter := [0.0, 0.0]         # 0..1 super meter per player; persists across points, not matches
```

Add immediately after:

```gdscript
var hit_count := 0              # monotonic swing counter; the view reads it to trigger juice
var hit_strength := 0.0         # power of the most recent swing (0..1, or >1 for a special)
```

Then in `_try_hit`, find `last_hitter = i` (the second occurrence, inside the launch tail) and the line after which charge is reset. Change the block:

```gdscript
	ball.bounce_count = 0
	ball.in_play = true
	last_hitter = i
	p.charge = 0.0
```

to:

```gdscript
	ball.bounce_count = 0
	ball.in_play = true
	last_hitter = i
	hit_count += 1
	hit_strength = 2.0 if special else p.charge
	p.charge = 0.0
```

- [ ] **Step 3b: Charge ring in `src/view/court_view.gd`.** Find the `_draw` body's near-player line:

```gdscript
	if debug_reach:
		_draw_reach(sim.players[0])
	_draw_ball(f)
	_draw_player(sim.players[0], P1_COLOR, f)
```

Replace with:

```gdscript
	if debug_reach:
		_draw_reach(sim.players[0])
	_draw_ball(f)
	_draw_player(sim.players[0], P1_COLOR, f)
	_draw_charge(sim.players[0])
```

Add this method at the end of the file:

```gdscript
func _draw_charge(p) -> void:
	if p.charge <= 0.0:
		return
	var center := Proj.to_screen(p.pos)
	var s := Proj.scale_at(p.pos.y)
	var r := 1.1 * s
	var col := Color(1.0, 0.85, 0.2) if p.charge >= 1.0 else Color(1.0, 1.0, 1.0, 0.8)
	draw_arc(center, r, -PI / 2.0, -PI / 2.0 + TAU * p.charge, 32, col, 4.0)
```

- [ ] **Step 3c: Hit-pause and screen shake in `src/view/match.gd`.** Replace the whole file with:

```gdscript
extends Node2D

const CourtSim := preload("res://src/sim/court_sim.gd")
const CourtView := preload("res://src/view/court_view.gd")
const Hud := preload("res://src/view/hud.gd")
const PlayerInput := preload("res://src/input/player_input.gd")
const WallAI := preload("res://src/ai/wall_ai.gd")

const SHAKE_DECAY := 0.6         # shake magnitude removed per rendered frame

var sim := CourtSim.new()
var view: Node2D
var hud: Node2D
var player_input: Node2D
var ai := WallAI.new()

var _seen_hits := 0
var _pause_frames := 0
var _shake := 0.0

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
			_restart()
		return
	if _pause_frames > 0:
		_pause_frames -= 1
		return
	sim.tick([frame, ai.frame(sim)])
	if sim.hit_count != _seen_hits:
		_seen_hits = sim.hit_count
		_pause_frames = int(round(2.0 + 4.0 * sim.hit_strength))   # 2..6 frames
		_shake = 4.0 + 10.0 * sim.hit_strength

func _restart() -> void:
	sim = CourtSim.new()
	_seen_hits = 0
	_pause_frames = 0
	_shake = 0.0

func _process(_delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - SHAKE_DECAY)
	if _shake > 0.1:
		view.position = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	else:
		view.position = Vector2.ZERO
	view.render(sim)
	hud.render(sim)
```

(Hit-pause skips sim ticks for a few frames — a single-player juice choice; it does not touch sim state, so determinism within a tick is unchanged. Shake offsets only the court view node.)

- [ ] **Step 3d: Super-meter bars in `src/view/hud.gd`.** Find the end of `_draw` (after the serve-indicator block) and add these lines as the final statements of `_draw`:

```gdscript
	_draw_meter(20, sim.meter[0])
	_draw_meter(1140, sim.meter[1])
```

Then add this method at the end of the file:

```gdscript
func _draw_meter(x: float, value: float) -> void:
	var w := 120.0
	var h := 12.0
	var y := 60.0
	draw_rect(Rect2(x, y, w, h), Color(1, 1, 1, 0.15))
	draw_rect(Rect2(x, y, w * value, h), Color(1.0, 0.85, 0.2) if value >= 1.0 else Color(0.3, 0.8, 1.0))
```

- [ ] **Step 4: Run tests and clean boot**

Run the harness. Expected: `46 passed, 0 failed` (45 + 1), exit 0.

Run: `& "<godot>" --path . --quit-after 180 2>&1`
Expected: no `SCRIPT ERROR` / `Parse Error` / `Cannot call` lines.

- [ ] **Step 5: Commit**

```bash
git add src/sim/court_sim.gd src/view/ tests/
git commit -m "feat: charge ring, hit-pause, screen shake and meter bars"
```

---

### Task 5: First character sprite (pipeline + placeholder)

**Files:**
- Create: `src/view/sprite_sheet.gd` (generates a placeholder 2-frame texture in code)
- Modify: `src/view/court_view.gd` (draw players as billboarded, depth-scaled, frame-animated sprites)
- Create: `tests/test_sprite.gd`
- Modify: `tests/run_tests.gd` (add to TEST_SCRIPTS)

Real art later: replace `sprite_sheet.gd`'s `build()` with `load("res://assets/sprites/<name>.png")` and keep the same frame layout (two frames side by side, `FRAME_W` × `FRAME_H` each). No other code changes needed.

- [ ] **Step 1: Write the failing test** — create `tests/test_sprite.gd`:

```gdscript
extends "res://tests/test_base.gd"

const SpriteSheet := preload("res://src/view/sprite_sheet.gd")

func test_placeholder_sheet_has_two_frames() -> void:
	var tex := SpriteSheet.build(Color(0.27, 0.48, 0.62))
	check(tex != null, "build must return a texture")
	check(tex.get_width() == SpriteSheet.FRAME_W * 2, "sheet is two frames wide")
	check(tex.get_height() == SpriteSheet.FRAME_H, "sheet is one frame tall")

func test_frame_rect_selects_by_index() -> void:
	var r0 := SpriteSheet.frame_rect(0)
	var r1 := SpriteSheet.frame_rect(1)
	check(r0.position.x == 0.0, "frame 0 starts at x=0")
	check(r1.position.x == float(SpriteSheet.FRAME_W), "frame 1 starts one frame over")
```

Update `tests/run_tests.gd` to append `"res://tests/test_sprite.gd"`.

- [ ] **Step 2: Run tests to verify they fail**

Expected: `test_sprite.gd` fails to load (no `sprite_sheet.gd`), exit 1.

- [ ] **Step 3a: Create `src/view/sprite_sheet.gd`:**

```gdscript
extends RefCounted

# Placeholder character sheet generated in code: two frames (idle, run) side by
# side, each FRAME_W x FRAME_H. Swap build() for a loaded PNG when real art exists.

const FRAME_W := 24
const FRAME_H := 40

static func frame_rect(index: int) -> Rect2:
	return Rect2(index * FRAME_W, 0, FRAME_W, FRAME_H)

static func build(tint: Color) -> ImageTexture:
	var img := Image.create(FRAME_W * 2, FRAME_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for frame in 2:
		var ox := frame * FRAME_W
		# legs stance differs between the two frames so motion reads
		var spread := 3 if frame == 1 else 1
		_rect(img, ox + 8 - spread, 30, 4, 10, tint.darkened(0.3))
		_rect(img, ox + 12 + spread, 30, 4, 10, tint.darkened(0.3))
		# torso
		_rect(img, ox + 8, 14, 8, 18, tint)
		# head
		_rect(img, ox + 9, 4, 6, 8, tint.lightened(0.2))
	return ImageTexture.create_from_image(img)

static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for iy in range(y, y + h):
		for ix in range(x, x + w):
			img.set_pixel(ix, iy, c)
```

- [ ] **Step 3b: Draw sprites in `src/view/court_view.gd`.** Add the preload near the top consts (after the existing `const CourtSim := ...` line):

```gdscript
const SpriteSheet := preload("res://src/view/sprite_sheet.gd")
```

Add these member vars right after `var debug_reach := true`:

```gdscript
var _tex := [SpriteSheet.build(P1_COLOR), SpriteSheet.build(P2_COLOR)]
var _anim := 0.0
```

Replace the whole `_draw_player` method:

```gdscript
func _draw_player(p, color: Color, f: float) -> void:
	var pos: Vector2 = p.prev_pos.lerp(p.pos, f)
	var s := Proj.scale_at(pos.y)
	var screen := Proj.to_screen(pos)
	var moving: bool = p.prev_pos.distance_to(p.pos) > 0.001
	var frame := 0
	if moving:
		frame = int(_anim * 8.0) % 2       # alternate the two frames while moving
	var idx := 0 if p.side < 0 else 1
	var w := SpriteSheet.FRAME_W * s * 0.06
	var h := SpriteSheet.FRAME_H * s * 0.06
	var dest := Rect2(screen.x - w / 2.0, screen.y - h, w, h)
	draw_texture_rect_region(_tex[idx], dest, SpriteSheet.frame_rect(frame))
```

The `color` parameter is now unused by drawing (tint is baked into the per-player texture) but is kept so the two existing call sites need no change. Advance the animation clock by finding, in `_draw`:

```gdscript
func _draw() -> void:
	if sim == null:
		return
	var f := Engine.get_physics_interpolation_fraction()
```

and replacing it with:

```gdscript
func _draw() -> void:
	if sim == null:
		return
	_anim += 0.05
	var f := Engine.get_physics_interpolation_fraction()
```

- [ ] **Step 4: Run tests and clean boot**

Run the harness. Expected: `48 passed, 0 failed` (46 + 2), exit 0.

Run: `& "<godot>" --path . --quit-after 180 2>&1`
Expected: no `SCRIPT ERROR` / `Parse Error` / `Cannot call`. A human check happens next.

- [ ] **Step 5: Commit**

```bash
git add src/view/ tests/
git commit -m "feat: billboarded character sprite pipeline with placeholder art"
```

---

### Task 6: Integration verification and README

**Files:**
- Modify: `README.md` (replace the milestone status section)

- [ ] **Step 1: Full suite + boot**

Run the harness. Expected: `48 passed, 0 failed`, exit 0.
Run: `& "<godot>" --path . --quit-after 180 2>&1` — clean, no script errors.

- [ ] **Step 2: Manual check (controller/human)**

Play windowed (`& "<godot>" --path .`): hold Space to see the charge ring fill and the player plant; release for a harder shot with a visible hit-pause and shake. Stick back on release = lob; stick forward = drop. Win rallies to fill the meter bar; a full-meter + full-charge release fires a curving "SPECIAL!". Players render as (placeholder) sprites that scale with depth.

- [ ] **Step 3: Update `README.md`** — replace the `## Milestone 2 status: The Point` section (title + paragraph) with:

```markdown
## Milestone 3 status: The Game

Hold to charge shots (movement locks while winding up); release with the stick
back for a lob or forward for a drop. A super meter fills through rallies and
points; a full-meter full-charge release fires a swerving special. Game feel:
charge ring, hit-pause, screen shake. Players render through a billboarded,
depth-scaled sprite pipeline (placeholder art — drop real PNGs into
src/view/sprite_sheet.gd's build()). Deferred: serve power-timing meter,
service boxes, per-character unique specials. Next: roster, courts with
gameplay rules, arcade ladder, menus, mobile builds.
```

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "feat: milestone 3 complete - charge, lob/drop, super meter, feel, sprites"
```

---

## Out of scope (later milestones)

Milestone 4 ("The Ladder"): the 6-character roster from shared rigs, the 4 courts with gameplay-affecting rules (clay/grass/ice), AI difficulty tiers + personalities, arcade-mode flow, character-select and menus. Milestone 5 ("The Ship"): audio, onboarding tutorial, Android then iOS builds, store prep. Also still pending from this milestone's deferrals: the serve power-timing meter and service boxes, and per-character unique special shots (the system already keys the special per player via `meter[i]`).
