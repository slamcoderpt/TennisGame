# Milestone 1 "The Rally" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A playable rally: trapezoid 2.5D court on screen, player moves with keyboard/touch, taps to hit an arcing ball, a wall-AI opponent returns it — all driven by a deterministic, headless-testable simulation.

**Architecture:** Two layers per the spec ([docs/superpowers/specs/2026-07-10-arcade-tennis-design.md](../specs/2026-07-10-arcade-tennis-design.md)): a pure-logic `CourtSim` (court-space coordinates, fixed 60 Hz tick, no Nodes) and a presentation layer that projects court space to screen pixels. Input reaches the sim only as `InputFrame` objects — touch, keyboard, and AI all speak that shape.

**Tech Stack:** Godot 4.x, GDScript only, no addons. Tests run headless via a ~30-line custom runner (no GUT — one less dependency).

---

## Context for the engineer

- **Working directory for every command:** `C:\1.projetos\godotgames\arcadetennis` (the git repo root; `project.godot` lives here after Task 1).
- **Godot binary:** `godot` is NOT on this machine's PATH (winget installed it without admin, so the command alias was not created). Wherever a command below shows `godot`, invoke the full path with the PowerShell call operator instead:
  `& "C:\Users\CarlosAlmeida\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe"`
  Installed version is 4.7-stable (verified). Example: `& "C:\Users\...\Godot_v4.7-stable_win64.exe" --headless --path . -s res://tests/run_tests.gd`.
- **GDScript uses TAB indentation.** Mixed tabs/spaces is a parse error. All `.gd` code blocks in this plan are tab-indented — preserve that.
- **Court-space conventions (memorize):** `x` ∈ [-4, 4] left/right, `y` ∈ [-12, 12] with the human player on the **negative-y** (bottom/near-camera) side, net at `y = 0`, `height` ≥ 0 above the court. `InputFrame.move.y = +1` means "toward the far side" for either player.
- **Test runner:** `godot --headless --path . -s res://tests/run_tests.gd`. Exit code 0 = all pass. If a test script has a parse error the runner prints `SCRIPT ERROR` lines and/or `FAIL could not load ...` — that counts as the expected "failing" state in TDD steps.
- All simulation constants (speeds, gravity, shot power) are **tuning values** — tests assert behavior (ball goes up, ball crosses net), never exact trajectories, so Task 11's feel pass can retune freely.

---

### Task 1: Project scaffold

**Files:**
- Create: `project.godot`
- Create: `src/view/match.tscn`
- Create: `src/view/match.gd`
- Modify: `.gitignore`

- [ ] **Step 1: Verify Godot is available**

Run: `godot --version`
Expected: a `4.x` version string. If the major version is not 4.3, edit the `config/features` line in Step 2 to match (e.g. `"4.4"`).

- [ ] **Step 2: Write `project.godot`**

```ini
config_version=5

[application]

config/name="Arcade Tennis"
run/main_scene="res://src/view/match.tscn"
config/features=PackedStringArray("4.3")

[display]

window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/handheld/orientation=4

[input_devices]

pointing/emulate_touch_from_mouse=true

[rendering]

renderer/rendering_method="mobile"
```

(`orientation=4` = sensor landscape; `emulate_touch_from_mouse` lets us test touch controls on desktop.)

- [ ] **Step 3: Write the placeholder main scene**

`src/view/match.gd`:

```gdscript
extends Node2D

func _ready() -> void:
	print("arcade tennis boots")
```

`src/view/match.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/view/match.gd" id="1"]

[node name="Match" type="Node2D"]
script = ExtResource("1")
```

- [ ] **Step 4: Ignore the Godot cache**

Append to `.gitignore`:

```
.godot/
```

- [ ] **Step 5: Import and boot headless**

Run: `godot --headless --path . --import`
Expected: exits without errors (warnings about a missing icon are fine).

Run: `godot --headless --path . --quit`
Expected output contains: `arcade tennis boots`

- [ ] **Step 6: Commit**

```bash
git add project.godot src/view/match.tscn src/view/match.gd .gitignore
git commit -m "feat: godot project scaffold with landscape mobile settings"
```

---

### Task 2: Headless test harness

**Files:**
- Create: `tests/test_base.gd`
- Create: `tests/run_tests.gd`
- Create: `tests/test_smoke.gd`

- [ ] **Step 1: Write the base class and runner**

`tests/test_base.gd`:

```gdscript
extends RefCounted

var failures: Array[String] = []

func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
```

`tests/run_tests.gd`:

```gdscript
extends SceneTree

const TEST_SCRIPTS := [
	"res://tests/test_smoke.gd",
]

func _init() -> void:
	var passed := 0
	var failed := 0
	for path in TEST_SCRIPTS:
		var script = load(path)
		if script == null:
			print("FAIL could not load %s" % path)
			failed += 1
			continue
		var test = script.new()
		for m in test.get_method_list():
			if not m.name.begins_with("test_"):
				continue
			test.failures.clear()
			test.call(m.name)
			if test.failures.is_empty():
				passed += 1
			else:
				failed += 1
				for msg in test.failures:
					print("FAIL %s.%s: %s" % [path.get_file(), m.name, msg])
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
```

- [ ] **Step 2: Write a smoke test**

`tests/test_smoke.gd`:

```gdscript
extends "res://tests/test_base.gd"

func test_harness_runs() -> void:
	check(1 + 1 == 2, "math is broken")
```

- [ ] **Step 3: Run the harness**

Run: `godot --headless --path . -s res://tests/run_tests.gd`
Expected output contains: `1 passed, 0 failed` (exit code 0).

- [ ] **Step 4: Commit**

```bash
git add tests/
git commit -m "test: minimal headless test harness"
```

---

### Task 3: Sim data classes + ball physics

**Files:**
- Create: `src/sim/input_frame.gd`
- Create: `src/sim/ball_state.gd`
- Create: `src/sim/player_state.gd`
- Create: `src/sim/court_sim.gd`
- Create: `tests/test_sim.gd`
- Modify: `tests/run_tests.gd` (add test script to list)

- [ ] **Step 1: Write the failing tests**

`tests/test_sim.gd`:

```gdscript
extends "res://tests/test_base.gd"

const CourtSim := preload("res://src/sim/court_sim.gd")
const InputFrame := preload("res://src/sim/input_frame.gd")

func _idle() -> Array:
	return [InputFrame.new(), InputFrame.new()]

func _tick_n(sim, n: int) -> void:
	for i in n:
		sim.tick(_idle())

func test_ball_waits_for_serve() -> void:
	var sim := CourtSim.new()
	_tick_n(sim, 60)
	check(sim.ball.height == CourtSim.SERVE_HEIGHT, "ball should hover until first hit")
	check(not sim.ball.in_play, "ball should not be in play before serve")

func test_ball_falls_and_bounces() -> void:
	var sim := CourtSim.new()
	sim.ball.in_play = true
	sim.ball.height = 2.0
	var start := sim.ball.height
	_tick_n(sim, 10)
	check(sim.ball.height < start, "gravity should pull the ball down")
	_tick_n(sim, 40)
	check(sim.ball.bounce_count >= 1, "ball should have bounced")

func test_bounce_loses_energy() -> void:
	var sim := CourtSim.new()
	sim.ball.in_play = true
	sim.ball.height = 2.0
	var v_after := 0.0
	for i in 300:
		sim.tick(_idle())
		if sim.ball.bounce_count == 1:
			v_after = sim.ball.v_height
			break
	check(v_after > 0.0, "ball should move up after a bounce")
	check(v_after < sqrt(2.0 * CourtSim.GRAVITY * 2.0), "bounce should lose energy")

func test_dead_ball_resets() -> void:
	var sim := CourtSim.new()
	sim.ball.in_play = true
	sim.ball.height = 2.0
	_tick_n(sim, 600)
	check(not sim.ball.in_play, "ball should reset to serve state after bouncing out")
```

Add the script to `tests/run_tests.gd`:

```gdscript
const TEST_SCRIPTS := [
	"res://tests/test_smoke.gd",
	"res://tests/test_sim.gd",
]
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `godot --headless --path . -s res://tests/run_tests.gd`
Expected: `FAIL could not load res://tests/test_sim.gd` (the preloaded sim scripts don't exist yet); exit code 1.

- [ ] **Step 3: Write the sim classes**

`src/sim/input_frame.gd`:

```gdscript
extends RefCounted

var move := Vector2.ZERO       # court-space direction, length <= 1, +y = toward far side
var hit_pressed := false       # true only on the tick the hit input fired
```

`src/sim/ball_state.gd`:

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
```

`src/sim/player_state.gd`:

```gdscript
extends RefCounted

var pos := Vector2.ZERO
var prev_pos := Vector2.ZERO
var side := -1                 # -1 = bottom (near camera, human), +1 = top
```

`src/sim/court_sim.gd`:

```gdscript
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
```

Notes on the two rules inside `_try_hit`:
- `incoming` prevents double-hitting your own outgoing ball without any cooldown state: a ball you just hit has `signf(vel.y) == -side`.
- A not-in-play ball (`vel == ZERO`, `signf(0) == 0`) is hittable by anyone — that's the serve.

- [ ] **Step 4: Run tests to verify they pass**

Run: `godot --headless --path . -s res://tests/run_tests.gd`
Expected: `5 passed, 0 failed` (1 smoke + 4 sim), exit code 0.

- [ ] **Step 5: Commit**

```bash
git add src/sim/ tests/
git commit -m "feat: court-space sim with ball flight, bounce and serve state"
```

---

### Task 4: Player movement

**Files:**
- Modify: `tests/test_sim.gd` (append tests)
- Modify: `src/sim/court_sim.gd` (only if tests fail — movement was implemented in Task 3)

- [ ] **Step 1: Append the movement tests to `tests/test_sim.gd`**

```gdscript
func test_player_moves_and_is_clamped() -> void:
	var sim := CourtSim.new()
	var frames := _idle()
	frames[0].move = Vector2(0, 1)
	for i in 600:
		sim.tick(frames)
	check(sim.players[0].pos.y == -0.5, "bottom player must stop before the net")
	frames[0].move = Vector2(-1, 0)
	for i in 600:
		sim.tick(frames)
	check(sim.players[0].pos.x == -CourtSim.HALF_WIDTH, "player must stop at the side line")

func test_diagonal_not_faster() -> void:
	var sim := CourtSim.new()
	var frames := _idle()
	frames[0].move = Vector2(1, 1)
	sim.tick(frames)
	var moved: float = sim.players[0].pos.distance_to(Vector2(0, -9))
	check(absf(moved - CourtSim.PLAYER_SPEED * CourtSim.TICK) < 0.001, "diagonal speed must equal straight speed")
```

- [ ] **Step 2: Run tests**

Run: `godot --headless --path . -s res://tests/run_tests.gd`
Expected: `7 passed, 0 failed`. (Movement shipped inside Task 3's `_move_player`; these tests lock the behavior. If anything fails, fix `_move_player` until green.)

- [ ] **Step 3: Commit**

```bash
git add tests/test_sim.gd
git commit -m "test: lock player movement clamping and speed normalization"
```

---

### Task 5: Hitting

**Files:**
- Modify: `tests/test_sim.gd` (append tests)
- Modify: `src/sim/court_sim.gd` (only if tests fail — hitting was implemented in Task 3)

- [ ] **Step 1: Append the hitting tests to `tests/test_sim.gd`**

```gdscript
func test_serve_hit_sends_ball_to_far_side() -> void:
	var sim := CourtSim.new()
	var frames := _idle()
	frames[0].hit_pressed = true
	sim.tick(frames)
	check(sim.ball.in_play, "hit should put ball in play")
	check(sim.ball.vel.y > 0.0, "ball should travel toward the far side")
	check(sim.ball.v_height > 0.0, "shot should launch upward")
	_tick_n(sim, 90)
	check(sim.ball.pos.y > 0.0, "ball should cross the net line within 1.5s")

func test_cannot_hit_out_of_reach() -> void:
	var sim := CourtSim.new()
	sim.players[0].pos = Vector2(3.5, -11.0)
	var frames := _idle()
	frames[0].hit_pressed = true
	sim.tick(frames)
	check(not sim.ball.in_play, "out-of-reach hit must do nothing")

func test_cannot_hit_own_outgoing_ball() -> void:
	var sim := CourtSim.new()
	var frames := _idle()
	frames[0].hit_pressed = true
	sim.tick(frames)
	var vel_after_serve: Vector2 = sim.ball.vel
	sim.tick(frames)
	check(sim.ball.vel == vel_after_serve, "own outgoing ball must not be re-hit")

func test_aim_follows_stick() -> void:
	var sim := CourtSim.new()
	var frames := _idle()
	frames[0].hit_pressed = true
	frames[0].move = Vector2(-1, 0)
	sim.tick(frames)
	check(sim.ball.vel.x < 0.0, "stick held left should aim the shot left")
```

- [ ] **Step 2: Run tests**

Run: `godot --headless --path . -s res://tests/run_tests.gd`
Expected: `11 passed, 0 failed`. (Hitting shipped in Task 3's `_try_hit`; fix it if any of these fail.)

- [ ] **Step 3: Commit**

```bash
git add tests/test_sim.gd
git commit -m "test: lock hit rules - reach, serve, no double-hit, stick aim"
```

---

### Task 6: Determinism

**Files:**
- Modify: `tests/test_sim.gd` (append test)

- [ ] **Step 1: Append the determinism test to `tests/test_sim.gd`**

```gdscript
func _scripted(i: int) -> Array:
	var p0 := InputFrame.new()
	p0.move = Vector2(sin(i * 0.05), cos(i * 0.07))
	p0.hit_pressed = i % 30 == 0
	var p1 := InputFrame.new()
	p1.move = Vector2(cos(i * 0.03), 0.0)
	p1.hit_pressed = i % 45 == 0
	return [p0, p1]

func test_determinism() -> void:
	var a := CourtSim.new()
	var b := CourtSim.new()
	for i in 600:
		a.tick(_scripted(i))
		b.tick(_scripted(i))
	check(a.ball.pos == b.ball.pos and a.ball.height == b.ball.height, "ball state must match exactly")
	check(a.players[0].pos == b.players[0].pos and a.players[1].pos == b.players[1].pos, "player state must match exactly")
```

- [ ] **Step 2: Run tests**

Run: `godot --headless --path . -s res://tests/run_tests.gd`
Expected: `12 passed, 0 failed`. This test is the future-multiplayer canary: it must stay green forever. If it fails, someone introduced randomness or Node/time dependence into the sim.

- [ ] **Step 3: Commit**

```bash
git add tests/test_sim.gd
git commit -m "test: sim determinism canary for future rollback netcode"
```

---

### Task 7: Court-space → screen projection

**Files:**
- Create: `src/view/projection.gd`
- Create: `tests/test_projection.gd`
- Modify: `tests/run_tests.gd` (add test script to list)

- [ ] **Step 1: Write the failing tests**

`tests/test_projection.gd`:

```gdscript
extends "res://tests/test_base.gd"

const Proj := preload("res://src/view/projection.gd")
const CourtSim := preload("res://src/sim/court_sim.gd")

func test_near_baseline_center() -> void:
	var p := Proj.to_screen(Vector2(0, -CourtSim.HALF_LENGTH))
	check(p == Vector2(Proj.SCREEN_W / 2.0, Proj.NEAR_Y), "near baseline center mapped to %s" % p)

func test_far_baseline() -> void:
	var p := Proj.to_screen(Vector2(0, CourtSim.HALF_LENGTH))
	check(p.y == Proj.FAR_Y, "far baseline mapped to y=%s" % p.y)

func test_court_narrows_with_depth() -> void:
	var near := Proj.to_screen(Vector2(CourtSim.HALF_WIDTH, -CourtSim.HALF_LENGTH))
	var far := Proj.to_screen(Vector2(CourtSim.HALF_WIDTH, CourtSim.HALF_LENGTH))
	check(far.x < near.x, "side line should pull toward center with depth (trapezoid)")

func test_height_lifts_ball_up_screen() -> void:
	var ground := Proj.to_screen(Vector2(0, 0))
	var lifted := Proj.to_screen(Vector2(0, 0), 1.0)
	check(lifted.y < ground.y, "height must offset the ball upward on screen")
```

Add to `tests/run_tests.gd`:

```gdscript
const TEST_SCRIPTS := [
	"res://tests/test_smoke.gd",
	"res://tests/test_sim.gd",
	"res://tests/test_projection.gd",
]
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `godot --headless --path . -s res://tests/run_tests.gd`
Expected: `FAIL could not load res://tests/test_projection.gd`; exit code 1.

- [ ] **Step 3: Write the projection**

`src/view/projection.gd`:

```gdscript
extends RefCounted

const CourtSim := preload("res://src/sim/court_sim.gd")

const SCREEN_W := 1280.0
const NEAR_Y := 660.0      # screen y of the near baseline
const FAR_Y := 120.0       # screen y of the far baseline
const NEAR_SCALE := 60.0   # pixels per court unit at the near baseline
const FAR_SCALE := 33.0    # pixels per court unit at the far baseline
const HEIGHT_SCALE := 0.8  # how strongly ball height offsets up-screen

static func depth_t(court_y: float) -> float:
	return (court_y + CourtSim.HALF_LENGTH) / (2.0 * CourtSim.HALF_LENGTH)

static func scale_at(court_y: float) -> float:
	return lerpf(NEAR_SCALE, FAR_SCALE, depth_t(court_y))

static func to_screen(court_pos: Vector2, height := 0.0) -> Vector2:
	var s := scale_at(court_pos.y)
	var x := SCREEN_W / 2.0 + court_pos.x * s
	var y := lerpf(NEAR_Y, FAR_Y, depth_t(court_pos.y)) - height * s * HEIGHT_SCALE
	return Vector2(x, y)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `godot --headless --path . -s res://tests/run_tests.gd`
Expected: `16 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add src/view/projection.gd tests/
git commit -m "feat: trapezoid court-space to screen projection"
```

---

### Task 8: Rendering + keyboard play

**Files:**
- Create: `src/view/court_view.gd`
- Create: `src/input/player_input.gd`
- Modify: `src/view/match.gd` (replace placeholder entirely)

- [ ] **Step 1: Write the court renderer**

`src/view/court_view.gd`:

```gdscript
extends Node2D

const Proj := preload("res://src/view/projection.gd")
const CourtSim := preload("res://src/sim/court_sim.gd")

const COURT_COLOR := Color("2d6a4f")
const LINE_COLOR := Color.WHITE
const NET_COLOR := Color(1, 1, 1, 0.35)
const P1_COLOR := Color("457b9d")
const P2_COLOR := Color("e63946")
const BALL_COLOR := Color("ffd166")
const SHADOW_COLOR := Color(0, 0, 0, 0.35)

var sim = null

func render(s) -> void:
	sim = s
	queue_redraw()

func _draw() -> void:
	if sim == null:
		return
	var f := Engine.get_physics_interpolation_fraction()
	_draw_court()
	_draw_player(sim.players[1], P2_COLOR, f)
	_draw_net()
	_draw_ball(f)
	_draw_player(sim.players[0], P1_COLOR, f)

func _draw_court() -> void:
	var hw := CourtSim.HALF_WIDTH
	var hl := CourtSim.HALF_LENGTH
	var pts := PackedVector2Array([
		Proj.to_screen(Vector2(-hw, -hl)),
		Proj.to_screen(Vector2(hw, -hl)),
		Proj.to_screen(Vector2(hw, hl)),
		Proj.to_screen(Vector2(-hw, hl)),
	])
	draw_colored_polygon(pts, COURT_COLOR)
	draw_polyline(pts + PackedVector2Array([pts[0]]), LINE_COLOR, 3.0)

func _draw_net() -> void:
	var hw := CourtSim.HALF_WIDTH
	var h := CourtSim.NET_HEIGHT
	var quad := PackedVector2Array([
		Proj.to_screen(Vector2(-hw, 0.0)),
		Proj.to_screen(Vector2(hw, 0.0)),
		Proj.to_screen(Vector2(hw, 0.0), h),
		Proj.to_screen(Vector2(-hw, 0.0), h),
	])
	draw_colored_polygon(quad, NET_COLOR)
	draw_line(quad[3], quad[2], LINE_COLOR, 2.0)

func _draw_player(p, color: Color, f: float) -> void:
	var pos: Vector2 = p.prev_pos.lerp(p.pos, f)
	var s := Proj.scale_at(pos.y)
	var screen := Proj.to_screen(pos)
	var size := Vector2(0.9, 1.4) * s
	draw_rect(Rect2(screen - Vector2(size.x / 2.0, size.y), size), color)

func _draw_ball(f: float) -> void:
	var b = sim.ball
	var pos: Vector2 = b.prev_pos.lerp(b.pos, f)
	var h := lerpf(b.prev_height, b.height, f)
	var s := Proj.scale_at(pos.y)
	draw_circle(Proj.to_screen(pos), 0.25 * s, SHADOW_COLOR)
	draw_circle(Proj.to_screen(pos, h), 0.22 * s, BALL_COLOR)
```

(Draw order: court → far player → net → ball → near player, so the net overlaps the far player and the near player overlaps everything — a cheap but convincing depth cue.)

- [ ] **Step 2: Write the keyboard input source**

`src/input/player_input.gd` (touch is added in Task 10):

```gdscript
extends Node2D

const InputFrame := preload("res://src/sim/input_frame.gd")

func consume_frame():
	var f := InputFrame.new()
	var kb := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	f.move = Vector2(kb.x, -kb.y)
	f.hit_pressed = Input.is_action_just_pressed("ui_accept")
	return f
```

(`ui_*` actions ship with Godot: arrow keys + Space/Enter. Screen-up is `-y` in `get_vector`, court far-side is `+y`, hence the flip.)

- [ ] **Step 3: Wire the match scene**

Replace `src/view/match.gd` entirely:

```gdscript
extends Node2D

const CourtSim := preload("res://src/sim/court_sim.gd")
const CourtView := preload("res://src/view/court_view.gd")
const PlayerInput := preload("res://src/input/player_input.gd")
const InputFrame := preload("res://src/sim/input_frame.gd")

var sim := CourtSim.new()
var view: Node2D
var player_input: Node2D

func _ready() -> void:
	view = CourtView.new()
	add_child(view)
	player_input = PlayerInput.new()
	add_child(player_input)

func _physics_process(_delta: float) -> void:
	sim.tick([player_input.consume_frame(), InputFrame.new()])

func _process(_delta: float) -> void:
	view.render(sim)
```

- [ ] **Step 4: Verify headless tests still pass, then check visually**

Run: `godot --headless --path . -s res://tests/run_tests.gd`
Expected: `16 passed, 0 failed`.

Run (windowed): `godot --path .`
Expected: green trapezoid court, blue rectangle at the bottom, red rectangle at the top, yellow ball hovering near the blue player. Arrows move the blue player (clamped to the bottom half); walking to the ball and pressing Space launches it in an arc toward the far side with a moving shadow; the far player never moves (AI comes next). Ball resets near you after it dies.

- [ ] **Step 5: Commit**

```bash
git add src/view/ src/input/
git commit -m "feat: 2.5d court rendering with interpolation and keyboard play"
```

---

### Task 9: Wall AI

**Files:**
- Create: `src/ai/wall_ai.gd`
- Create: `tests/test_ai.gd`
- Modify: `tests/run_tests.gd` (add test script to list)
- Modify: `src/view/match.gd:4-18` (swap dummy frame for AI)

- [ ] **Step 1: Write the failing test**

`tests/test_ai.gd`:

```gdscript
extends "res://tests/test_base.gd"

const CourtSim := preload("res://src/sim/court_sim.gd")
const InputFrame := preload("res://src/sim/input_frame.gd")
const WallAI := preload("res://src/ai/wall_ai.gd")

func test_ai_returns_the_ball() -> void:
	var sim := CourtSim.new()
	var ai := WallAI.new()
	var serve := InputFrame.new()
	serve.hit_pressed = true
	sim.tick([serve, ai.frame(sim)])
	check(sim.ball.in_play, "serve should start the rally")
	var returned := false
	var idle := InputFrame.new()
	for i in 600:
		sim.tick([idle, ai.frame(sim)])
		if sim.ball.in_play and sim.ball.vel.y < 0.0:
			returned = true
			break
	check(returned, "AI should return the ball toward the player within 10s")
```

Add to `tests/run_tests.gd`:

```gdscript
const TEST_SCRIPTS := [
	"res://tests/test_smoke.gd",
	"res://tests/test_sim.gd",
	"res://tests/test_projection.gd",
	"res://tests/test_ai.gd",
]
```

- [ ] **Step 2: Run tests to verify it fails**

Run: `godot --headless --path . -s res://tests/run_tests.gd`
Expected: `FAIL could not load res://tests/test_ai.gd`; exit code 1.

- [ ] **Step 3: Write the AI**

`src/ai/wall_ai.gd`:

```gdscript
extends RefCounted

const InputFrame := preload("res://src/sim/input_frame.gd")
const CourtSim := preload("res://src/sim/court_sim.gd")

func frame(sim) -> InputFrame:
	var f := InputFrame.new()
	var me = sim.players[1]
	var dx: float = sim.ball.pos.x - me.pos.x
	if absf(dx) > 0.2:
		f.move.x = signf(dx)
	if sim.ball.pos.distance_to(me.pos) <= CourtSim.REACH:
		f.hit_pressed = true
	return f
```

(It shadows the ball's x and mashes hit whenever the ball is close — the sim's `incoming` rule makes the press legal only when the ball is actually returnable, so the AI can't cheat. It plays through the same `InputFrame` door as the human, per the spec.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `godot --headless --path . -s res://tests/run_tests.gd`
Expected: `17 passed, 0 failed`.

- [ ] **Step 5: Wire the AI into the match**

In `src/view/match.gd`, add the preload and replace the `_physics_process` dummy frame:

```gdscript
const WallAI := preload("res://src/ai/wall_ai.gd")

var ai := WallAI.new()

func _physics_process(_delta: float) -> void:
	sim.tick([player_input.consume_frame(), ai.frame(sim)])
```

(Remove the now-unused `const InputFrame := ...` line from match.gd.)

- [ ] **Step 6: Manual rally check**

Run: `godot --path .`
Expected: serve with Space — the red player slides to meet the ball and returns it. You can sustain a rally.

- [ ] **Step 7: Commit**

```bash
git add src/ai/ tests/ src/view/match.gd
git commit -m "feat: wall AI opponent playing through the InputFrame interface"
```

---

### Task 10: Touch controls

**Files:**
- Modify: `src/input/player_input.gd` (replace entirely)

- [ ] **Step 1: Replace `src/input/player_input.gd` with the touch-aware version**

```gdscript
extends Node2D

const InputFrame := preload("res://src/sim/input_frame.gd")

const JOY_RADIUS := 110.0

var joy_id := -1
var joy_origin := Vector2.ZERO
var joy_current := Vector2.ZERO
var touch_hit := false

func _input(event: InputEvent) -> void:
	var half := get_viewport_rect().size.x / 2.0
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < half and joy_id == -1:
				joy_id = event.index
				joy_origin = event.position
				joy_current = event.position
				queue_redraw()
			elif event.position.x >= half:
				touch_hit = true
		elif event.index == joy_id:
			joy_id = -1
			queue_redraw()
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
	f.hit_pressed = Input.is_action_just_pressed("ui_accept") or touch_hit
	touch_hit = false
	return f

func _draw() -> void:
	if joy_id == -1:
		return
	draw_circle(joy_origin, JOY_RADIUS, Color(1, 1, 1, 0.08))
	draw_arc(joy_origin, JOY_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.25), 2.0)
	var knob := joy_origin + (joy_current - joy_origin).limit_length(JOY_RADIUS)
	draw_circle(knob, 28.0, Color(1, 1, 1, 0.3))
```

(Floating joystick: the base appears where the left-half touch lands, per the spec. The whole right half is the hit button. Keyboard still works — the joystick overrides movement only while held.)

- [ ] **Step 2: Verify tests still pass**

Run: `godot --headless --path . -s res://tests/run_tests.gd`
Expected: `17 passed, 0 failed` (input layer is untested by design — it's thin and device-dependent).

- [ ] **Step 3: Manual check with mouse-as-touch**

Run: `godot --path .`
Expected (mouse emulates touch via the project setting): click-drag on the left half of the window → translucent joystick appears where you clicked and the player follows the drag; click on the right half → hit. Rally works end-to-end without the keyboard.

- [ ] **Step 4: Commit**

```bash
git add src/input/player_input.gd
git commit -m "feat: floating touch joystick and right-half hit zone"
```

---

### Task 11: Feel pass + README

**Files:**
- Modify: `src/sim/court_sim.gd:6-23` (constants only, if needed)
- Modify: `src/view/projection.gd:5-10` (constants only, if needed)
- Create: `README.md`

- [ ] **Step 1: Play and tune**

Run: `godot --path .` and play for a few minutes. The milestone goal is **"hitting feels good"**. Tune only constants (never logic): `PLAYER_SPEED` if movement feels sluggish, `SHOT_SPEED`/`SHOT_LAUNCH` if shots feel floaty or don't clear the net visually, `REACH` if hits feel unfair, projection `NEAR_SCALE`/`FAR_SCALE` if the court reads poorly. After any change:

Run: `godot --headless --path . -s res://tests/run_tests.gd`
Expected: `17 passed, 0 failed` — the tests assert behavior, not exact numbers, so reasonable tuning stays green.

- [ ] **Step 2: Write `README.md`**

```markdown
# Arcade Tennis

Retro pixel-art arcade tennis (Windjammers pace) for Android/iOS. Godot 4.x.

- Spec: docs/superpowers/specs/2026-07-10-arcade-tennis-design.md
- Run the game: `godot --path .`
- Run tests: `godot --headless --path . -s res://tests/run_tests.gd`

Desktop controls (dev): arrows move, Space hits. Touch: left half = floating
joystick, right half = hit. Mouse emulates touch.

Layout: `src/sim/` pure deterministic game logic (never touches Nodes),
`src/view/` projection + rendering, `src/input/` InputFrame producers,
`src/ai/` AI opponents (also InputFrame producers), `tests/` headless tests.
```

- [ ] **Step 3: Optional device check**

To try it on your Android phone: open the project in the Godot editor, install the Android export template when prompted, enable USB debugging on the phone, and use the editor's one-click remote deploy. Not required to complete this milestone.

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: milestone 1 complete - playable rally with tuned feel"
```

---

## Out of scope (next plans)

Milestone 2 ("The Point"): net collision, in/out judgment, double-bounce rule, tennis scoring, serve flow, HUD. Milestone 3: charge shots, lob/drop, super meter, sprites. This plan deliberately lets the ball pass through the net and never scores — the rally itself is the deliverable.
