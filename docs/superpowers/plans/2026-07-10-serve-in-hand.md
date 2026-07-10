# Serve "In Hand" + Stick Aim Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the serve ball sit "in the server's hand" and follow the player until the toss, remove the deuce/ad positioning and cross-court auto-aim, and aim the serve with the stick like a normal shot.

**Architecture:** All in the deterministic sim ([spec](../specs/2026-07-10-serve-in-hand-design.md)). `reset_for_serve` puts the ball at the server's position; a follow-the-hand step in `_update_toss` keeps it there until the toss starts; `_serve_contact` aims via the stick. The rally path and the toss/timing mechanic are unchanged.

**Tech Stack:** Godot 4.7, GDScript only, existing custom headless test harness.

---

## Context for the engineer

- **Working directory:** `C:\1.projetos\godotgames\arcadetennis` (git repo). Execute on a branch `serve-in-hand` from `master`.
- **Godot binary:** NOT on PATH. Full path with the PowerShell call operator:
  `& "C:\Users\CarlosAlmeida\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe"`
  Godot writes to **stderr** — pipe `2>&1` in bash.
- **Test runner:** `& "<godot>" --headless --path . -s res://tests/run_tests.gd`. Baseline before this plan: **57 passed, 0 failed**.
- **Harness caveat (verify every run):** this harness reports a GDScript COMPILE error as a false "pass". After each run, ALSO scan output for `SCRIPT ERROR` / `Parse Error` — a truly-green run has ZERO such lines. Also `:=` type inference fails on members of the untyped `players`/`inputs` arrays (Variant); use `=` or an explicit cast, never `var x := players[...].member`.
- **GDScript uses TAB indentation.** Reproduce code blocks exactly.
- **Court-space:** player 0 side=-1 (bottom, human), player 1 side=+1 (top). `players[server].pos` is the server's current position.

---

### Task 1: Repoint the out-of-reach test to a rally ball

`test_cannot_hit_out_of_reach` currently places the server far from the fixed serve spot to prove the reach gate. Once the serve ball is in the server's hand (Task 2) it is always reachable, so this test must exercise the reach gate on an in-play rally ball instead. This passes on the CURRENT code (behavior-preserving) and stays valid after Task 2.

**Files:**
- Modify: `tests/test_sim.gd` (replace `test_cannot_hit_out_of_reach`)

- [ ] **Step 1: Replace the whole `test_cannot_hit_out_of_reach` function in `tests/test_sim.gd` with:**

```gdscript
func test_cannot_hit_out_of_reach() -> void:
	var sim := CourtSim.new()
	# an in-play rally ball far from the player must not be returnable
	sim.last_hitter = 1
	sim.is_serve = false
	sim.ball.in_play = true
	sim.ball.pos = Vector2(3.5, 5.0)
	sim.ball.vel = Vector2(0, -6)
	sim.ball.height = 1.0
	sim.players[0].pos = Vector2(-3.5, -11.0)
	var frames := _idle()
	frames[0].hit_pressed = true
	sim.tick(frames)
	check(sim.ball.vel.y < 0.0, "an out-of-reach rally ball must not be returned")
```

- [ ] **Step 2: Run the harness — must still be green**

Run: `& "<godot>" --headless --path . -s res://tests/run_tests.gd 2>&1`
Expected: `57 passed, 0 failed`, exit 0, and ZERO `SCRIPT ERROR`/`Parse Error` lines. (The rally ball at `(3.5,5)` is incoming toward player 0 but far from `(-3.5,-11)`, so the reach gate rejects the hit and `vel.y` stays negative.) Paste output + your error-line count.

- [ ] **Step 3: Commit**

```bash
git add tests/test_sim.gd
git commit -m "test: check the out-of-reach gate on a rally ball, not the serve"
```

---

### Task 2: Serve in hand + stick aim

**Files:**
- Modify: `src/sim/court_sim.gd` (remove 2 constants, rewrite `reset_for_serve`, add follow-the-hand to `_update_toss`, change the aim line in `_serve_contact`)
- Modify: `tests/test_serve.gd` (full rewrite — replaces the deuce/ad + cross-court tests)

- [ ] **Step 1: Replace the ENTIRE contents of `tests/test_serve.gd` with:**

```gdscript
extends "res://tests/test_base.gd"

const CourtSim := preload("res://src/sim/court_sim.gd")
const InputFrame := preload("res://src/sim/input_frame.gd")

func _held() -> InputFrame:
	var f := InputFrame.new()
	f.hit_held = true
	return f

func test_serve_starts_in_hand_at_the_server() -> void:
	var sim := CourtSim.new()
	check(sim.ball.pos == sim.players[sim.server].pos, "the serve ball starts in the server's hand")
	check(sim.ball.height == CourtSim.SERVE_HEIGHT, "serve ball rests at the in-hand height")
	check(not sim.ball.in_play, "serve ball is not in play until struck")

func test_serve_ball_follows_the_hand() -> void:
	var sim := CourtSim.new()
	var move := InputFrame.new()
	move.move = Vector2(-1, 0)          # walk left while the ball is in hand (not holding hit)
	for i in 20:
		sim.tick([move, InputFrame.new()])
	check(sim.players[0].pos.x < 0.0, "the server moved left")
	check(sim.ball.pos == sim.players[0].pos, "the in-hand ball follows the server")

func test_toss_rises_then_falls() -> void:
	var sim := CourtSim.new()
	var start: float = sim.ball.height
	var peak := start
	for i in 60:
		sim.tick([_held(), InputFrame.new()])
		peak = maxf(peak, sim.ball.height)
	check(peak > start + 0.5, "the toss must rise well above the rest height")
	check(sim.ball.height < peak, "the toss must come back down from its peak")

func test_missed_toss_is_a_fault() -> void:
	var sim := CourtSim.new()
	for i in 120:
		sim.tick([_held(), InputFrame.new()])
	check(sim.serve_faults >= 1, "a toss that lands untouched must be a serve fault")

func _toss_and_release_at(sim, hold_ticks: int, stick := Vector2.ZERO) -> void:
	for i in hold_ticks:
		var h := _held()
		h.move = stick
		sim.tick([h, InputFrame.new()])
	var rel := InputFrame.new()
	rel.move = stick
	rel.hit_pressed = true
	sim.tick([rel, InputFrame.new()])

func test_timing_near_apex_serves_faster() -> void:
	var good := CourtSim.new()
	_toss_and_release_at(good, 24)
	var good_speed: float = good.ball.vel.length()
	var early := CourtSim.new()
	_toss_and_release_at(early, 3)
	var early_speed: float = early.ball.vel.length()
	check(good.ball.in_play, "a well-timed toss must produce a live serve")
	check(good_speed > early_speed + 1.0, "releasing near the apex must serve faster than an early release")

func test_serve_speed_follows_toss_timing_not_hold_time() -> void:
	var apex := CourtSim.new()
	_toss_and_release_at(apex, 24)
	var late := CourtSim.new()
	_toss_and_release_at(late, 44)
	check(apex.ball.in_play and late.ball.in_play, "both serves should be live")
	check(apex.ball.vel.length() > late.ball.vel.length() + 1.0, "apex timing must serve faster than a late (longer-held) release")

func test_serve_aims_by_stick() -> void:
	var left := CourtSim.new()
	_toss_and_release_at(left, 24, Vector2(-1, 0))
	check(left.ball.in_play and left.ball.vel.x < 0.0, "stick left must serve to the left")
	var right := CourtSim.new()
	_toss_and_release_at(right, 24, Vector2(1, 0))
	check(right.ball.in_play and right.ball.vel.x > 0.0, "stick right must serve to the right")

func test_tap_serve_still_works() -> void:
	var sim := CourtSim.new()
	var f := InputFrame.new()
	f.hit_pressed = true
	sim.tick([f, InputFrame.new()])
	check(sim.ball.in_play, "a plain tap must still serve the ball")
	check(sim.ball.vel.y > 0.0, "the tap serve travels to the far side")
	check(sim.is_serve, "the tap serve is flagged as a serve")
```

- [ ] **Step 2: Run the harness to verify the new tests FAIL**

Run: `& "<godot>" --headless --path . -s res://tests/run_tests.gd 2>&1`
Expected: real assertion FAILs — `test_serve_starts_in_hand_at_the_server` (ball starts at the deuce spot, not the server's pos) and `test_serve_ball_follows_the_hand` (ball doesn't follow yet), exit 1. Paste output. (Not just SCRIPT ERROR — genuine FAIL lines.)

- [ ] **Step 3a: Delete two now-unused constants in `src/sim/court_sim.gd`.** Delete this line:

```gdscript
const SERVE_X := 1.5             # deuce/ad offset; small enough that a center server still reaches it
```

and this line:

```gdscript
const SERVE_AIM_NUDGE := 1.0     # how far the stick can shift the cross-court serve target
```

- [ ] **Step 3b: Rewrite `reset_for_serve`.** Replace the whole method with:

```gdscript
func reset_for_serve() -> void:
	ball.pos = players[server].pos
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
```

- [ ] **Step 3c: Add follow-the-hand to `_update_toss`.** Find:

```gdscript
func _update_toss(inputs) -> void:
	if ball.in_play:
		return
	if inputs[server].hit_held and not is_tossing:
		is_tossing = true
		ball.v_height = TOSS_VELOCITY
```

Replace with:

```gdscript
func _update_toss(inputs) -> void:
	if ball.in_play:
		return
	if not is_tossing:
		ball.pos = players[server].pos      # the ball stays in the server's hand until the toss
	if inputs[server].hit_held and not is_tossing:
		is_tossing = true
		ball.v_height = TOSS_VELOCITY
```

- [ ] **Step 3d: Aim the serve by the stick in `_serve_contact`.** Find:

```gdscript
	var aim_x := clampf(-ball.pos.x + clampf(input.move.x, -1.0, 1.0) * SERVE_AIM_NUDGE, -AIM_MAX_X, AIM_MAX_X)
	var target := Vector2(aim_x, -p.side * TARGET_DEPTH)
```

Replace with:

```gdscript
	var aim_x := clampf(input.move.x, -1.0, 1.0) * AIM_MAX_X
	var target := Vector2(aim_x, -p.side * TARGET_DEPTH)
```

- [ ] **Step 4: Run the harness to verify it passes**

Run: `& "<godot>" --headless --path . -s res://tests/run_tests.gd 2>&1`
Expected: `56 passed, 0 failed`, exit 0, ZERO `SCRIPT ERROR`/`Parse Error` lines. (Total drops from 57: `test_serve.gd` went from 9 tests to 8 — the deuce/ad, side-alternation, and cross-court tests are replaced by follow-the-hand and aim-by-stick.) Existing serve tests in `test_sim.gd`/`test_rules.gd` stay green: a tap serve now fires from the server's own position `(0,-9)` straight to the far side (clears the net, lands in), the receiver still can't return before the bounce, own-side landings still fault, and `test_aim_follows_stick` now gets `vel.x < 0` from the stick directly. If any prior test regresses, STOP and report the exact failing test + values. Paste output + error-line count.

- [ ] **Step 5: Commit**

```bash
git add src/sim/court_sim.gd tests/test_serve.gd
git commit -m "feat: serve ball follows the server's hand; aim by stick"
```

---

### Task 3: Integration, manual check, README

**Files:**
- Modify: `README.md` (serve controls line)

- [ ] **Step 1: Full suite + boot + error scan**

Run: `& "<godot>" --headless --path . -s res://tests/run_tests.gd 2>&1`
Expected: `56 passed, 0 failed`, exit 0, zero `SCRIPT ERROR`/`Parse Error` lines.

Run: `& "<godot>" --path . --quit-after 180 2>&1`
Expected: no `SCRIPT ERROR` / `Parse Error` / `Cannot call` lines.

- [ ] **Step 2: Manual check (controller/human)**

Play windowed (`& "<godot>" --path .`): at the start of a point the ball sits in your player's hand and moves with you as you walk left/right; hold Space to toss it up from where you're standing (you stop moving), release near the top for a fast serve; the serve goes where the stick points (left/right), toward the far side. A dropped toss faults.

- [ ] **Step 3: Update `README.md`.** Find:

```markdown
Desktop controls (dev): arrows move, hold Space to charge then release to hit
(stick back = lob, forward = drop). Serving, hold Space to toss the ball and
release near the top for a fast cross-court serve. Touch: left half = floating
joystick, right half = hold-to-charge hit. Mouse emulates touch. Press D to
toggle the debug reach ring.
```

Replace with:

```markdown
Desktop controls (dev): arrows move, hold Space to charge then release to hit
(stick back = lob, forward = drop). Serving, move to position (the ball is in
your hand), then hold Space to toss and release near the top to hit; aim with
the stick. Touch: left half = floating joystick, right half = hold-to-charge
hit. Mouse emulates touch. Press D to toggle the debug reach ring.
```

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "feat: serve in hand with stick aim complete"
```

---

## Out of scope (deferred, unchanged)

Service boxes and a diagonal fault zone; overhead serve motion; a visible toss-timing meter; per-character serve traits.
