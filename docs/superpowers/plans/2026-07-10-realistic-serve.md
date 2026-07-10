# Realistic Serve Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the groundstroke-style serve with a tossed, timing-based serve (hold to toss, release near the apex for pace) served diagonally cross-court from alternating deuce/ad positions.

**Architecture:** All logic stays in the deterministic sim ([spec](../specs/2026-07-10-realistic-serve-design.md)). The serve becomes its own contact path (`_serve_contact`) separate from rally hits; a toss integrates the ball's height while it is not yet in play; `reset_for_serve` positions the ball on the current deuce/ad spot. The rally charge/lob/drop/special paths are untouched.

**Tech Stack:** Godot 4.7, GDScript only, existing custom headless test harness.

---

## Context for the engineer

- **Working directory:** `C:\1.projetos\godotgames\arcadetennis` (git repo). Execute on a feature branch `realistic-serve` created from `master`.
- **Godot binary:** NOT on PATH. Use the full path with the PowerShell call operator:
  `& "C:\Users\CarlosAlmeida\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe"`
  Godot writes results to **stderr** — pipe `2>&1` in a bash shell.
- **Test runner:** `& "<godot>" --headless --path . -s res://tests/run_tests.gd`. Baseline before this plan: **48 passed, 0 failed**.
- **GDScript uses TAB indentation.** Reproduce code blocks exactly.
- **Court-space:** `x`∈[-4,4], `y`∈[-12,12], net at y=0, player 0 side=-1 (bottom, human), player 1 side=+1 (top, AI). `InputFrame.move.y=+1` = toward far side. `InputFrame` has `move`, `hit_held`, `hit_pressed`. `PlayerState` has `pos/prev_pos/side/hit_buffer/charge`. `BallState` has `pos/prev_pos/height/prev_height/vel/v_height/bounce_count/in_play/swerve`.
- **Why Task 1 edits existing tests:** three tests exercise charge/special by *holding then releasing on a serve*. After this change the serve is toss-timed, not charge-powered, so those tests are repointed to an in-play rally ball (calling `_try_hit` directly with a preset charge) — the mechanic is unchanged, only the vehicle. This is a deliberate, green-preserving refactor. No other existing test changes.

---

### Task 1: Repoint charge/special tests to a rally ball

These three tests currently hold-then-release on the serve to test charge/special. Repoint them to an in-play rally ball via a direct `_try_hit` call with a preset `charge`. This passes on the CURRENT code (behavior-preserving) and stays valid after the serve changes.

**Files:**
- Modify: `tests/test_charge.gd` (replace `test_charged_shot_faster_than_tap`, add a `_rally_ball` helper)
- Modify: `tests/test_meter.gd` (replace `test_special_needs_full_meter_and_full_charge` and `test_special_ball_curves`, add a `_rally_ball` helper)

- [ ] **Step 1: In `tests/test_charge.gd`, add a helper and replace one test.**

Add this helper after the existing `_held()` function:

```gdscript
func _rally_ball(sim) -> void:
	sim.last_hitter = 1
	sim.is_serve = false
	sim.ball.in_play = true
	sim.ball.pos = Vector2(0, -9)
	sim.ball.vel = Vector2(0, -6)
	sim.ball.height = 1.0
	sim.players[0].pos = Vector2(0, -9)
```

Replace the whole `test_charged_shot_faster_than_tap` function with:

```gdscript
func test_charged_shot_faster_than_tap() -> void:
	var tap := CourtSim.new()
	_rally_ball(tap)
	tap.players[0].charge = 0.0
	tap._try_hit(0, InputFrame.new())
	var tap_speed: float = tap.ball.vel.length()

	var chg := CourtSim.new()
	_rally_ball(chg)
	chg.players[0].charge = 1.0
	chg._try_hit(0, InputFrame.new())
	var chg_speed: float = chg.ball.vel.length()

	check(chg_speed > tap_speed + 1.0, "a full-charge rally shot must leave faster than a tap")
```

- [ ] **Step 2: In `tests/test_meter.gd`, add a helper and replace two tests.**

Add this helper after the existing `_serve_tap()` function:

```gdscript
func _rally_ball(sim) -> void:
	sim.last_hitter = 1
	sim.is_serve = false
	sim.ball.in_play = true
	sim.ball.pos = Vector2(0, -9)
	sim.ball.vel = Vector2(0, -6)
	sim.ball.height = 1.0
	sim.players[0].pos = Vector2(0, -9)
```

Replace the whole `test_special_needs_full_meter_and_full_charge` function with:

```gdscript
func test_special_needs_full_meter_and_full_charge() -> void:
	var weak := CourtSim.new()
	_rally_ball(weak)
	weak.meter[0] = 1.0
	weak.players[0].charge = 0.0
	weak._try_hit(0, InputFrame.new())
	check(weak.ball.swerve == 0.0, "an uncharged shot must not fire the special even with a full meter")
	check(weak.meter[0] == 1.0, "meter must not drain without a special")

	var strong := CourtSim.new()
	_rally_ball(strong)
	strong.meter[0] = 1.0
	strong.players[0].charge = 1.0
	strong._try_hit(0, InputFrame.new())
	check(strong.ball.swerve != 0.0, "a full-charge shot on a full meter must fire a swerving special")
	check(strong.meter[0] == 0.0, "the special must drain the meter")
```

Replace the whole `test_special_ball_curves` function with:

```gdscript
func test_special_ball_curves() -> void:
	var sim := CourtSim.new()
	_rally_ball(sim)
	sim.meter[0] = 1.0
	sim.players[0].charge = 1.0
	sim._try_hit(0, InputFrame.new())
	var vx0: float = sim.ball.vel.x
	for i in 10:
		sim.tick([InputFrame.new(), InputFrame.new()])
	check(sim.ball.vel.x != vx0, "a special ball's horizontal velocity must curve over time")
```

- [ ] **Step 3: Run the harness — must still be green (behavior-preserving refactor)**

Run: `& "<godot>" --headless --path . -s res://tests/run_tests.gd`
Expected: `48 passed, 0 failed`, exit 0. (These repointed tests exercise the unchanged rally `_try_hit`, so they pass on the current sim.)

- [ ] **Step 4: Commit**

```bash
git add tests/test_charge.gd tests/test_meter.gd
git commit -m "test: exercise charge and special on a rally ball, not the serve"
```

---

### Task 2: Diagonal serve position + low rest height

**Files:**
- Modify: `src/sim/court_sim.gd` (constants, `is_tossing` field, `reset_for_serve`)
- Create: `tests/test_serve.gd`
- Modify: `tests/run_tests.gd` (add to TEST_SCRIPTS)

- [ ] **Step 1: Write the failing tests** — create `tests/test_serve.gd`:

```gdscript
extends "res://tests/test_base.gd"

const CourtSim := preload("res://src/sim/court_sim.gd")
const InputFrame := preload("res://src/sim/input_frame.gd")

func _held() -> InputFrame:
	var f := InputFrame.new()
	f.hit_held = true
	return f

func test_serve_starts_on_a_deuce_or_ad_spot() -> void:
	var sim := CourtSim.new()
	check(absf(sim.ball.pos.x) == CourtSim.SERVE_X, "serve ball must start offset to a deuce/ad spot")
	check(sim.ball.height == CourtSim.SERVE_HEIGHT, "serve ball rests at the in-hand height")

func test_serve_side_alternates_each_point() -> void:
	var sim := CourtSim.new()
	var first_x: float = sim.ball.pos.x
	sim.score.points = [1, 0]        # one point played -> next serve is the other court
	sim.reset_for_serve()
	check(sim.ball.pos.x == -first_x, "the serve spot must switch sides after a point")

func test_center_server_can_still_reach_the_serve() -> void:
	# a player at the center baseline must be within REACH of the offset serve ball,
	# so the existing tap-serve tests keep working
	var sim := CourtSim.new()
	var dist: float = sim.ball.pos.distance_to(sim.players[0].pos)
	check(dist <= CourtSim.REACH, "center server must reach the offset serve spot (dist=%s)" % dist)
```

Update `tests/run_tests.gd` TEST_SCRIPTS to append `"res://tests/test_serve.gd"` as the last entry (keep all existing entries).

- [ ] **Step 2: Run tests to verify they fail**

Expected: `test_serve.gd` failures (`SERVE_X` doesn't exist; ball currently starts at x=0), exit 1.

- [ ] **Step 3a: Replace the serve constants in `src/sim/court_sim.gd`.** Find:

```gdscript
const SERVE_DEPTH := 8.0
const SERVE_HEIGHT := 1.2
```

Replace with:

```gdscript
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
```

- [ ] **Step 3b: Add the `is_tossing` field.** Find:

```gdscript
var is_serve := false           # true from the serve hit until its first legal bounce
```

Add immediately after:

```gdscript
var is_tossing := false         # true while the served ball is airborne from the toss, pre-contact
```

- [ ] **Step 3c: Rewrite `reset_for_serve`.** Replace the whole method with:

```gdscript
func reset_for_serve() -> void:
	var s := players[server].side
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
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: `51 passed, 0 failed` (48 + 3), exit 0. **All 48 prior tests must remain green** — the serve ball is now at `(±1.5, ±8)`, still within `REACH` (1.8 < 2.0) of a center server, and the serve still fires through the unchanged `_try_hit` serve path (which still aims via `aim_x` and uses the launch/speed it did before). If any prior test regresses, stop and report.

- [ ] **Step 5: Commit**

```bash
git add src/sim/court_sim.gd tests/
git commit -m "feat: serve starts on an alternating deuce/ad spot at rest height"
```

---

### Task 3: Ball toss

**Files:**
- Modify: `src/sim/court_sim.gd` (`_update_toss`, call it in `tick`)
- Modify: `tests/test_serve.gd` (append tests)

- [ ] **Step 1: Append the failing tests to `tests/test_serve.gd`:**

```gdscript
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
	# hold and never release: the toss falls to the ground untouched -> fault
	for i in 120:
		sim.tick([_held(), InputFrame.new()])
	check(sim.serve_faults >= 1, "a toss that lands untouched must be a serve fault")
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: `test_toss_rises_then_falls` fails (holding does not move the resting ball yet), exit 1.

- [ ] **Step 3a: Add `_update_toss` to `src/sim/court_sim.gd`.** Add this method immediately after `_move_player`:

```gdscript
func _update_toss(inputs) -> void:
	if ball.in_play:
		return
	if inputs[server].hit_held and not is_tossing:
		is_tossing = true
		ball.v_height = TOSS_VELOCITY
	if is_tossing:
		ball.v_height -= GRAVITY * TICK
		ball.height += ball.v_height * TICK
		if ball.height <= 0.0:
			ball.height = 0.0
			is_tossing = false
			_serve_fault()
```

- [ ] **Step 3b: Call it in `tick`.** Find:

```gdscript
	_update_ball()
	for i in 2:
		var input = inputs[i]
```

Replace with:

```gdscript
	_update_toss(inputs)
	_update_ball()
	for i in 2:
		var input = inputs[i]
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: `53 passed, 0 failed` (51 + 2), exit 0. Prior tests stay green: a toss only starts when the server holds; idle serves (and tap serves) never toss. Holds in the charge tests still build charge and now also toss, but those tests only assert charge/movement (which are unaffected), and they release before the toss lands.

- [ ] **Step 5: Commit**

```bash
git add src/sim/court_sim.gd tests/test_serve.gd
git commit -m "feat: hold to toss the serve ball up under gravity"
```

---

### Task 4: Serve contact — timing and cross-court aim

**Files:**
- Modify: `src/sim/court_sim.gd` (split serve out of `_try_hit` into `_serve_contact`)
- Modify: `tests/test_serve.gd` (append tests)

- [ ] **Step 1: Append the failing tests to `tests/test_serve.gd`:**

```gdscript
func _toss_and_release_at(sim, hold_ticks: int) -> void:
	for i in hold_ticks:
		sim.tick([_held(), InputFrame.new()])
	var rel := InputFrame.new()
	rel.hit_pressed = true
	sim.tick([rel, InputFrame.new()])

func test_timing_near_apex_serves_faster() -> void:
	# apex is ~24 ticks in; releasing there should beat releasing very early
	var good := CourtSim.new()
	_toss_and_release_at(good, 24)
	var good_speed: float = good.ball.vel.length()

	var early := CourtSim.new()
	_toss_and_release_at(early, 3)
	var early_speed: float = early.ball.vel.length()

	check(good.ball.in_play, "a well-timed toss must produce a live serve")
	check(good_speed > early_speed + 1.0, "releasing near the apex must serve faster than an early release")

func test_serve_aims_cross_court() -> void:
	var sim := CourtSim.new()
	var serve_x: float = sim.ball.pos.x     # deuce/ad spot
	_toss_and_release_at(sim, 24)
	check(sim.ball.in_play, "serve should be live")
	check(signf(sim.ball.vel.x) == -signf(serve_x), "the serve must travel cross-court (toward the opposite side)")

func test_tap_serve_still_works() -> void:
	var sim := CourtSim.new()
	var f := InputFrame.new()
	f.hit_pressed = true
	sim.tick([f, InputFrame.new()])
	check(sim.ball.in_play, "a plain tap must still serve the ball")
	check(sim.ball.vel.y > 0.0, "the tap serve travels to the far side")
	check(sim.is_serve, "the tap serve is flagged as a serve")

func test_serve_speed_follows_toss_timing_not_hold_time() -> void:
	# Release at the apex (~24 ticks) vs a LATE release (~44 ticks) after the toss has
	# fallen. The late release was HELD LONGER (more charge, under the old serve it would
	# be faster) but is worse timing, so it must serve SLOWER. This proves serve speed
	# tracks toss height/timing, not hold duration.
	var apex := CourtSim.new()
	_toss_and_release_at(apex, 24)
	var late := CourtSim.new()
	_toss_and_release_at(late, 44)
	check(apex.ball.in_play and late.ball.in_play, "both serves should be live")
	check(apex.ball.vel.length() > late.ball.vel.length() + 1.0, "apex timing must serve faster than a late (longer-held) release")
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: `test_timing_near_apex_serves_faster` fails (serve speed currently comes from charge, not toss timing), and `test_serve_aims_cross_court` fails (current serve aims via `aim_x`, not cross-court), exit 1.

- [ ] **Step 3a: Delegate serving out of `_try_hit`.** Find:

```gdscript
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
```

Replace with:

```gdscript
func _try_hit(i: int, input) -> bool:
	var p = players[i]
	if ball.in_play and is_serve:
		return false               # the serve must bounce before it can be returned
	if not ball.in_play:
		return _serve_contact(i, input)
	if signf(ball.vel.y) != float(p.side):
		return false               # ball is not incoming toward this player
	if ball.pos.distance_to(p.pos) > REACH or ball.height > MAX_HIT_HEIGHT:
		return false
	var aim_x := clampf(input.move.x, -1.0, 1.0) * AIM_MAX_X
```

Then find, further down in the same method:

```gdscript
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
```

Replace with:

```gdscript
	ball.bounce_count = 0
	ball.in_play = true
	last_hitter = i
	hit_count += 1
	hit_strength = 2.0 if special else p.charge
	p.charge = 0.0
	return true
```

(The rally path can no longer be a serve — serving is handled by `_serve_contact` — so the `serving`/`is_serve` tail is removed here.)

- [ ] **Step 3b: Add `_serve_contact`.** Add this method immediately after `_try_hit`:

```gdscript
func _serve_contact(i: int, input) -> bool:
	var p = players[i]
	if ball.pos.distance_to(p.pos) > REACH:
		return false
	var quality := SERVE_TAP_QUALITY
	if is_tossing:
		if ball.height < MIN_CONTACT_HEIGHT:
			is_tossing = false
			_serve_fault()
			return false
		quality = clampf(1.0 - absf(ball.height - IDEAL_CONTACT_HEIGHT) / CONTACT_WINDOW, 0.0, 1.0)
	var speed := lerpf(SERVE_SPEED_MIN, SERVE_SPEED_MAX, quality)
	var aim_x := clampf(-ball.pos.x + clampf(input.move.x, -1.0, 1.0) * SERVE_AIM_NUDGE, -AIM_MAX_X, AIM_MAX_X)
	var target := Vector2(aim_x, -p.side * TARGET_DEPTH)
	ball.vel = (target - ball.pos).normalized() * speed
	ball.v_height = SERVE_LAUNCH
	ball.height = maxf(ball.height, 0.4)
	ball.swerve = 0.0
	ball.bounce_count = 0
	ball.in_play = true
	is_tossing = false
	is_serve = true
	last_hitter = i
	hit_count += 1
	hit_strength = quality
	meter[i] = minf(1.0, meter[i] + METER_PER_HIT)
	last_event = ""
	return true
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: `57 passed, 0 failed` (53 + 4), exit 0. Prior serve tests stay green: a tap serve (`is_tossing` false) uses `SERVE_TAP_QUALITY` and still clears the net and lands in; the receiver still cannot return before the bounce (`is_serve` set); own-side landings still fault; `test_aim_follows_stick` still gets a negative `vel.x` for a left stick (cross-court from the deuce spot is already negative, and the nudge only reinforces it). If any prior test regresses, stop and report.

- [ ] **Step 5: Commit**

```bash
git add src/sim/court_sim.gd tests/test_serve.gd
git commit -m "feat: toss-timed serve contact with cross-court aim"
```

---

### Task 5: Integration, spec note, README

**Files:**
- Modify: `docs/superpowers/specs/2026-07-10-realistic-serve-design.md` (correct the backward-compat note)
- Modify: `README.md` (serve controls line)

- [ ] **Step 1: Full suite + boot**

Run: `& "<godot>" --headless --path . -s res://tests/run_tests.gd`
Expected: `57 passed, 0 failed`, exit 0.

Run: `& "<godot>" --path . --quit-after 180 2>&1`
Expected: no `SCRIPT ERROR` / `Parse Error` / `Cannot call` lines.

- [ ] **Step 2: Manual check (controller/human)**

Play windowed (`& "<godot>" --path .`): at the start of a point the ball sits low on one side; hold Space and watch it toss up (the charge ring shows); release near the top of the toss for a fast serve, off-timing for a slow one; never releasing drops the toss and faults. The serve travels cross-court, and the starting side switches each point.

- [ ] **Step 3: Correct the spec's backward-compat note.** In `docs/superpowers/specs/2026-07-10-realistic-serve-design.md`, find the line in the Testing section:

```markdown
- **Backward compatibility:** all 48 existing tests pass unchanged (a `hit_pressed` tap still serves the ball to the far side; own-side poked landings still fault).
```

Replace with:

```markdown
- **Backward compatibility:** the tap-serve path is preserved (a `hit_pressed` tap still serves to the far side; own-side poked landings still fault). Three tests that exercised charge/special by holding on the serve are repointed to an in-play rally ball, since the serve is no longer charge-powered; the mechanics remain fully tested.
```

- [ ] **Step 4: Update `README.md`.** Find the controls line:

```markdown
Desktop controls (dev): arrows move, hold Space to charge then release to hit
(stick back = lob, forward = drop). Touch: left half = floating joystick, right
half = hold-to-charge hit. Mouse emulates touch. Press D to toggle the debug
reach ring.
```

Replace with:

```markdown
Desktop controls (dev): arrows move, hold Space to charge then release to hit
(stick back = lob, forward = drop). Serving, hold Space to toss the ball and
release near the top for a fast cross-court serve. Touch: left half = floating
joystick, right half = hold-to-charge hit. Mouse emulates touch. Press D to
toggle the debug reach ring.
```

- [ ] **Step 5: Commit**

```bash
git add README.md docs/superpowers/specs/2026-07-10-realistic-serve-design.md
git commit -m "feat: realistic toss-timed diagonal serve complete"
```

---

## Out of scope (deferred, per spec)

Service boxes and a diagonal fault zone; overhead/downward serve motion; a visible toss-timing meter; per-character serve traits. These can layer on later without reworking this design.
