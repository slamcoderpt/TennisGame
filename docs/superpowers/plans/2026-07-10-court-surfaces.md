# Court Surfaces (Data-Driven) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The sim carries four surface parameters (neutral by default = today's behavior exactly) so clay slows/raises the bounce, grass lowers it, and ice makes players faster but slow to change direction; the 4 launch courts are data applied to a match.

**Architecture:** `CourtSim` gains `bounce_speed`/`bounce_height`/`move_response`/`move_speed` floats (all 1.0 default). Movement becomes velocity-based (`PlayerState.move_vel` converging to the input target via `lerp(…, move_response)`) — at 1.0 it is bit-identical to today's instant movement. The bounce multiplies restitution by `bounce_height` and horizontal velocity by `bounce_speed`. `src/data/courts.gd` (same pattern as `roster.gd`) holds the 4 courts; `Match` applies the chosen court (default `"hard"` = neutral) via a seam for the future ladder.

**Tech Stack:** Godot 4.7, GDScript only, existing custom headless test harness.

---

## Context for the engineer

- **Working directory:** `C:\1.projetos\godotgames\arcadetennis` (git repo). Execute on a branch `court-surfaces` from `master`.
- **Godot binary:** NOT on PATH. In the Bash tool run the exe path directly (POSIX form), with `2>&1` (Godot writes to stderr):
  `"/c/Users/CarlosAlmeida/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7-stable_win64.exe" --headless --path . -s res://tests/run_tests.gd 2>&1`
- **Test baseline:** currently **64 passed, 0 failed**.
- **Harness caveat (verify every run):** the harness reports a GDScript COMPILE error as a false "pass". After each run, ALSO scan output for `SCRIPT ERROR` / `Parse Error` (e.g. `... 2>&1 | grep -ciE "SCRIPT ERROR|Parse Error"`) — a truly-green run has ZERO such lines. Also `:=` type inference FAILS on members of the untyped `players`/`inputs` arrays (they are Variant); use `=` or an explicit type annotation (`var x: float = ...`), never `var x := players[...].member`.
- **GDScript uses TAB indentation.** Reproduce code blocks exactly.
- **Why neutral is bit-identical:** `Vector2.lerp(target, 1.0)` returns `target` exactly, and `* 1.0` is an exact float identity — so with all params at 1.0 the movement and bounce math produce the same bits as today. This is what keeps the strict existing tests (`test_diagonal_not_faster`, determinism canary) green.

---

### Task 1: Surface parameters in the sim (movement + bounce)

**Files:**
- Modify: `src/sim/player_state.gd` (add `move_vel`)
- Modify: `src/sim/court_sim.gd` (4 surface fields, `_move_player` rewrite, bounce lines)
- Create: `tests/test_surface.gd`
- Modify: `tests/run_tests.gd` (register the new test file)

- [ ] **Step 1: Create `tests/test_surface.gd`:**

```gdscript
extends "res://tests/test_base.gd"

const CourtSim := preload("res://src/sim/court_sim.gd")
const InputFrame := preload("res://src/sim/input_frame.gd")

# A legal mid-rally ball (hit by player 1 toward player 0's side) flying
# horizontally so its first bounce continues the rally instead of ending it.
func _flying_ball(sim) -> void:
	sim.last_hitter = 1
	sim.is_serve = false
	sim.ball.in_play = true
	sim.ball.pos = Vector2(0, -5)
	sim.ball.vel = Vector2(8, 0)
	sim.ball.height = 1.0
	sim.ball.v_height = 0.0

func _tick_until_bounce(sim) -> void:
	for i in 120:
		sim.tick([InputFrame.new(), InputFrame.new()])
		if sim.ball.bounce_count >= 1:
			return

func test_surface_defaults_are_neutral() -> void:
	var sim := CourtSim.new()
	check(sim.bounce_speed == 1.0 and sim.bounce_height == 1.0, "bounce params default neutral")
	check(sim.move_response == 1.0 and sim.move_speed == 1.0, "movement params default neutral")

func test_clay_slows_and_raises_the_bounce() -> void:
	var hard := CourtSim.new()
	_flying_ball(hard)
	_tick_until_bounce(hard)
	var clay := CourtSim.new()
	clay.bounce_speed = 0.85
	clay.bounce_height = 1.2
	_flying_ball(clay)
	_tick_until_bounce(clay)
	check(clay.ball.vel.length() < hard.ball.vel.length(), "clay keeps less horizontal speed across the bounce")
	check(clay.ball.v_height > hard.ball.v_height, "clay bounces higher")

func test_grass_bounces_lower() -> void:
	var hard := CourtSim.new()
	_flying_ball(hard)
	_tick_until_bounce(hard)
	var grass := CourtSim.new()
	grass.bounce_height = 0.7
	_flying_ball(grass)
	_tick_until_bounce(grass)
	check(grass.ball.v_height < hard.ball.v_height, "grass bounces lower")

func test_ice_is_slow_to_accelerate() -> void:
	var hard := CourtSim.new()
	var ice := CourtSim.new()
	ice.move_response = 0.15
	ice.move_speed = 1.2
	var f := InputFrame.new()
	f.move = Vector2(1, 0)
	hard.tick([f, InputFrame.new()])
	ice.tick([f, InputFrame.new()])
	var v_hard: float = hard.players[0].move_vel.x
	var v_ice: float = ice.players[0].move_vel.x
	check(v_ice < v_hard, "on ice the first tick of movement is slower (slow to get going)")

func test_ice_is_slow_to_reverse() -> void:
	var hard := CourtSim.new()
	var ice := CourtSim.new()
	ice.move_response = 0.15
	ice.move_speed = 1.2
	var right := InputFrame.new()
	right.move = Vector2(1, 0)
	for i in 30:
		hard.tick([right, InputFrame.new()])
		ice.tick([right, InputFrame.new()])
	var left := InputFrame.new()
	left.move = Vector2(-1, 0)
	hard.tick([left, InputFrame.new()])
	ice.tick([left, InputFrame.new()])
	var v_hard: float = hard.players[0].move_vel.x
	var v_ice: float = ice.players[0].move_vel.x
	check(v_hard < 0.0, "on hard court the reversal is instant")
	check(v_ice > 0.0, "on ice the player keeps drifting the old way for a while")

func test_ice_top_speed_is_higher() -> void:
	var ice := CourtSim.new()
	ice.move_response = 0.15
	ice.move_speed = 1.2
	var f := InputFrame.new()
	f.move = Vector2(1, 0)
	for i in 90:
		ice.tick([f, InputFrame.new()])
	var v: float = ice.players[0].move_vel.x
	check(v > CourtSim.PLAYER_SPEED, "ice top speed exceeds the hard-court max")
```

Register it: append `"res://tests/test_surface.gd"` as the LAST entry in `tests/run_tests.gd` TEST_SCRIPTS (keep existing entries in order).

- [ ] **Step 2: Run the harness to verify the new tests FAIL** (no `bounce_speed`/`move_vel` fields). Exit 1. Paste output + error-line count.

- [ ] **Step 3a: Add `move_vel` to `src/sim/player_state.gd`.** Replace the whole file with:

```gdscript
extends RefCounted

var pos := Vector2.ZERO
var prev_pos := Vector2.ZERO
var move_vel := Vector2.ZERO   # current movement velocity (converges to the input target)
var side := -1                 # -1 = bottom (near camera, human), +1 = top
var hit_buffer := 0            # ticks the swing stays armed after a hit press
var charge := 0.0              # 0..1 wind-up while the hit is held
var speed := 1.0               # stat multipliers on the baseline (1.0 = baseline)
var power := 1.0
var charge_rate := 1.0
var reach := 1.0
```

- [ ] **Step 3b: Add the surface fields to `src/sim/court_sim.gd`.** Find:

```gdscript
var hit_count := 0              # monotonic swing counter; the view reads it to trigger juice
var hit_strength := 0.0         # power of the most recent swing (0..1, or >1 for a special)
```

Add immediately after:

```gdscript
var bounce_speed := 1.0         # court surface: horizontal ball speed kept on a bounce
var bounce_height := 1.0        # court surface: restitution multiplier
var move_response := 1.0        # court surface: how fast player velocity follows input (1.0 = instant)
var move_speed := 1.0           # court surface: player max-speed multiplier
```

- [ ] **Step 3c: Rewrite `_move_player`.** Replace the whole method with:

```gdscript
func _move_player(p, input) -> void:
	if input.hit_held:
		p.move_vel = Vector2.ZERO
		return                  # charging locks the player in place
	var m: Vector2 = input.move
	if m.length() > 1.0:
		m = m.normalized()
	var target: Vector2 = m * PLAYER_SPEED * p.speed * move_speed
	p.move_vel = p.move_vel.lerp(target, move_response)
	p.pos += p.move_vel * TICK
	p.pos.x = clampf(p.pos.x, -HALF_WIDTH, HALF_WIDTH)
	if p.side < 0:
		p.pos.y = clampf(p.pos.y, -HALF_LENGTH, -0.5)
	else:
		p.pos.y = clampf(p.pos.y, 0.5, HALF_LENGTH)
```

- [ ] **Step 3d: Apply the surface to the bounce.** In `_update_ball`, find:

```gdscript
	if ball.height <= 0.0 and ball.v_height < 0.0:
		ball.height = 0.0
		ball.v_height = -ball.v_height * RESTITUTION
		ball.bounce_count += 1
		_judge_bounce()
```

Replace with:

```gdscript
	if ball.height <= 0.0 and ball.v_height < 0.0:
		ball.height = 0.0
		ball.v_height = -ball.v_height * RESTITUTION * bounce_height
		ball.vel *= bounce_speed
		ball.bounce_count += 1
		_judge_bounce()
```

- [ ] **Step 4: Run the harness.** Expected: `70 passed, 0 failed` (64 + 6), exit 0, ZERO `SCRIPT ERROR`/`Parse Error` lines. All 64 prior tests stay green (neutral defaults are bit-identical: `lerp(…, 1.0)` returns the target exactly and `* 1.0` is exact). If any prior test regresses, STOP and report the exact failing test + values. Paste output + error-line count.

- [ ] **Step 5: Commit**

```bash
git add src/sim/player_state.gd src/sim/court_sim.gd tests/
git commit -m "feat: court surface parameters - bounce and velocity-based movement"
```

---

### Task 2: Courts data + apply to the match

**Files:**
- Create: `src/data/courts.gd`
- Create: `tests/test_courts.gd`
- Modify: `tests/run_tests.gd` (register the new test file)
- Modify: `src/view/match.gd` (court seam)

- [ ] **Step 1: Create `tests/test_courts.gd`:**

```gdscript
extends "res://tests/test_base.gd"

const Courts := preload("res://src/data/courts.gd")
const CourtSim := preload("res://src/sim/court_sim.gd")

func test_courts_has_four() -> void:
	check(Courts.COURTS.size() == 4, "there are 4 launch courts")

func test_by_id_finds_and_falls_back() -> void:
	check(Courts.by_id("clay").bounce_speed == 0.85, "clay slows the bounce")
	check(Courts.by_id("nope").id == "hard", "unknown id falls back to hard")

func test_apply_to_copies_params() -> void:
	var sim := CourtSim.new()
	Courts.apply_to(sim, Courts.by_id("ice"))
	check(sim.move_response == 0.15, "ice move_response applied")
	check(sim.move_speed == 1.2, "ice move_speed applied")
	check(sim.bounce_speed == 1.0 and sim.bounce_height == 1.0, "ice ball params stay neutral")
```

Register it: append `"res://tests/test_courts.gd"` as the LAST entry in `tests/run_tests.gd` TEST_SCRIPTS.

- [ ] **Step 2: Run the harness to verify it fails** (no `src/data/courts.gd`). Exit 1. Paste output.

- [ ] **Step 3a: Create `src/data/courts.gd`:**

```gdscript
extends RefCounted

# The 4 launch courts as plain data. Params are multipliers on the sim's
# neutral surface (1.0 = neutral). `color` is a placeholder court colour hex
# for later visual differentiation (applied by the view in a later sub-project).

const COURTS := [
	{ "id": "hard", "name": "Hard Court", "color": "2d6a4f", "bounce_speed": 1.0, "bounce_height": 1.0, "move_response": 1.0, "move_speed": 1.0 },
	{ "id": "clay", "name": "Clay", "color": "b5651d", "bounce_speed": 0.85, "bounce_height": 1.2, "move_response": 1.0, "move_speed": 1.0 },
	{ "id": "grass", "name": "Grass", "color": "3a7d44", "bounce_speed": 1.0, "bounce_height": 0.7, "move_response": 1.0, "move_speed": 1.0 },
	{ "id": "ice", "name": "Ice Rink", "color": "a8dadc", "bounce_speed": 1.0, "bounce_height": 1.0, "move_response": 0.15, "move_speed": 1.2 },
]

static func by_id(id: String) -> Dictionary:
	for c in COURTS:
		if c.id == id:
			return c
	return COURTS[0]

static func apply_to(sim, court: Dictionary) -> void:
	sim.bounce_speed = court.bounce_speed
	sim.bounce_height = court.bounce_height
	sim.move_response = court.move_response
	sim.move_speed = court.move_speed
```

- [ ] **Step 3b: Run the harness.** Expected: `73 passed, 0 failed` (70 + 3), exit 0, ZERO error lines. Paste output + error-line count.

- [ ] **Step 3c: Wire the court into `src/view/match.gd`.**
Add the preload right after the existing `const Roster := preload("res://src/data/roster.gd")` line:

```gdscript
const Courts := preload("res://src/data/courts.gd")
```

Add this member var right after the `var opponent_character := "allrounder"` line:

```gdscript
var court := "hard"                      # the seam the ladder/court-select will feed
```

Add this method right after the `_apply_characters` method:

```gdscript
func _apply_court() -> void:
	Courts.apply_to(sim, Courts.by_id(court))
```

Call it right after BOTH existing `_apply_characters()` call sites (end of `_ready`, and in `_restart`):

```gdscript
	_apply_court()
```

- [ ] **Step 4: Verify suite + clean boot.**

Run the harness. Expected: `73 passed, 0 failed`, exit 0, zero error lines. (Default court "hard" = neutral, no behavior change.)

Run: `"/c/Users/CarlosAlmeida/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7-stable_win64.exe" --path . --quit-after 180 2>&1`
Expected: no `SCRIPT ERROR` / `Parse Error` / `Cannot call` lines. Paste both outputs + error scans.

- [ ] **Step 5: Commit**

```bash
git add src/data/courts.gd src/view/match.gd tests/
git commit -m "feat: court data applied to the match (default hard court)"
```

---

## Self-review notes / deferred

- **Court colour deferred:** `courts.gd` carries a `color`, but the view does not repaint the court in this sub-project — there is no court choice to display until the ladder/menus (sub-project 4), matching the character-tint decision.
- **Ice + charging:** `hit_held` zeroes `move_vel`, so after charging on ice the player restarts from rest — consistent with "charging plants you", and the simplest rule.

## Out of scope (later sub-projects)

Court selection UI / ladder court sequence; per-court view colours; AI adjustments per surface; real art.
