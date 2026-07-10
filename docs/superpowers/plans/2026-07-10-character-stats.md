# Character Stats (Data-Driven) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the simulation read per-player stat multipliers (`speed`, `power`, `charge_rate`, `reach`) off the tuned baseline, and define the 6-character roster as data applied to a match.

**Architecture:** `PlayerState` gains four multiplier fields (default `1.0`, so all-1.0 reproduces today's behavior). The sim multiplies its baseline constants by the acting player's stat at each of six sites. A small `src/data/roster.gd` module holds the 6 archetypes as plain dictionaries plus `apply_to`/`by_id`; `Match` applies chosen characters to the sim (defaulting both to All-Rounder) through a single seam the future select screen will feed. Sim stays pure/deterministic.

**Tech Stack:** Godot 4.7, GDScript only, existing custom headless test harness.

---

## Context for the engineer

- **Working directory:** `C:\1.projetos\godotgames\arcadetennis` (git repo). Execute on a branch `character-stats` from `master`.
- **Godot binary:** NOT on PATH. In the Bash tool run the exe path directly (POSIX form), with `2>&1` (Godot writes to stderr):
  `"/c/Users/CarlosAlmeida/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7-stable_win64.exe" --headless --path . -s res://tests/run_tests.gd 2>&1`
- **Test runner baseline:** currently **56 passed, 0 failed**.
- **Harness caveat (verify every run):** the harness reports a GDScript COMPILE error as a false "pass". After each run, ALSO scan output for `SCRIPT ERROR` / `Parse Error` (e.g. `... 2>&1 | grep -ciE "SCRIPT ERROR|Parse Error"`) — a truly-green run has ZERO such lines. Also `:=` type inference fails on members of the untyped `players`/`inputs` arrays (Variant); use `=` or an explicit cast.
- **GDScript uses TAB indentation.** Reproduce code blocks exactly.
- The sim's acting player is `p` in `_move_player`/`_try_hit`/`_serve_contact`, and `players[i]` in the `tick` charge line.

---

### Task 1: Per-player stat multipliers in the sim

**Files:**
- Modify: `src/sim/player_state.gd` (add 4 fields)
- Modify: `src/sim/court_sim.gd` (6 read sites)
- Create: `tests/test_stats.gd`
- Modify: `tests/run_tests.gd` (register the new test file)

- [ ] **Step 1: Create `tests/test_stats.gd`:**

```gdscript
extends "res://tests/test_base.gd"

const CourtSim := preload("res://src/sim/court_sim.gd")
const InputFrame := preload("res://src/sim/input_frame.gd")

# An in-play rally ball `dist` units in front of player 0, incoming and reachable.
func _rally_ball(sim, dist: float) -> void:
	sim.last_hitter = 1
	sim.is_serve = false
	sim.ball.in_play = true
	sim.ball.pos = Vector2(0, -9.0 + dist)
	sim.ball.vel = Vector2(0, -6)
	sim.ball.height = 1.0
	sim.players[0].pos = Vector2(0, -9.0)

func test_default_multipliers_are_one() -> void:
	var sim := CourtSim.new()
	var p = sim.players[0]
	check(p.speed == 1.0 and p.power == 1.0 and p.charge_rate == 1.0 and p.reach == 1.0, "stats default to 1.0")

func test_speed_multiplier_moves_faster() -> void:
	var slow := CourtSim.new()
	var fast := CourtSim.new()
	fast.players[0].speed = 1.5
	var f := InputFrame.new()
	f.move = Vector2(1, 0)
	slow.tick([f, InputFrame.new()])
	fast.tick([f, InputFrame.new()])
	var d_slow: float = slow.players[0].pos.distance_to(Vector2(0, -9))
	var d_fast: float = fast.players[0].pos.distance_to(Vector2(0, -9))
	check(d_fast > d_slow, "higher speed moves farther per tick")

func test_power_multiplier_hits_harder() -> void:
	var weak := CourtSim.new()
	_rally_ball(weak, 0.0)
	weak.players[0].power = 1.0
	weak._try_hit(0, InputFrame.new())
	var s1: float = weak.ball.vel.length()
	var strong := CourtSim.new()
	_rally_ball(strong, 0.0)
	strong.players[0].power = 1.3
	strong._try_hit(0, InputFrame.new())
	var s2: float = strong.ball.vel.length()
	check(s2 > s1 + 1.0, "higher power sends the ball faster")

func test_reach_multiplier_extends_reach() -> void:
	var base := CourtSim.new()
	_rally_ball(base, 2.3)                 # 2.3 units away: outside baseline REACH 2.0
	base.players[0].reach = 1.0
	check(not base._try_hit(0, InputFrame.new()), "baseline reach cannot hit a ball 2.3 away")
	var reachy := CourtSim.new()
	_rally_ball(reachy, 2.3)
	reachy.players[0].reach = 1.3          # REACH * 1.3 = 2.6 > 2.3
	check(reachy._try_hit(0, InputFrame.new()), "extended reach hits the 2.3-away ball")

func test_charge_rate_fills_faster() -> void:
	var base := CourtSim.new()
	var fast := CourtSim.new()
	fast.players[0].charge_rate = 2.0
	var h := InputFrame.new()
	h.hit_held = true
	for i in 5:
		base.tick([h, InputFrame.new()])
		fast.tick([h, InputFrame.new()])
	check(fast.players[0].charge > base.players[0].charge, "higher charge_rate fills the meter faster")
```

Register it: update `tests/run_tests.gd` TEST_SCRIPTS to append `"res://tests/test_stats.gd"` as the last entry (keep all existing entries in order).

- [ ] **Step 2: Run the harness to verify the new tests FAIL** (no `speed`/`power`/`charge_rate`/`reach` fields). Real assertion FAILs / access errors, exit 1. Paste output.

- [ ] **Step 3a: Add the four fields to `src/sim/player_state.gd`.** Replace the whole file with:

```gdscript
extends RefCounted

var pos := Vector2.ZERO
var prev_pos := Vector2.ZERO
var side := -1                 # -1 = bottom (near camera, human), +1 = top
var hit_buffer := 0            # ticks the swing stays armed after a hit press
var charge := 0.0              # 0..1 wind-up while the hit is held
var speed := 1.0               # stat multipliers on the baseline (1.0 = baseline)
var power := 1.0
var charge_rate := 1.0
var reach := 1.0
```

- [ ] **Step 3b: Movement uses `speed`.** In `src/sim/court_sim.gd`, find:

```gdscript
	p.pos += m * PLAYER_SPEED * TICK
```

Replace with:

```gdscript
	p.pos += m * PLAYER_SPEED * p.speed * TICK
```

- [ ] **Step 3c: Charge accrual uses `charge_rate`.** Find:

```gdscript
			players[i].charge = minf(1.0, players[i].charge + TICK / CHARGE_TIME)
```

Replace with:

```gdscript
			players[i].charge = minf(1.0, players[i].charge + TICK / CHARGE_TIME * players[i].charge_rate)
```

- [ ] **Step 3d: Rally reach + power.** Find (in `_try_hit`):

```gdscript
	if ball.pos.distance_to(p.pos) > REACH or ball.height > MAX_HIT_HEIGHT:
		return false
```

Replace with:

```gdscript
	if ball.pos.distance_to(p.pos) > REACH * p.reach or ball.height > MAX_HIT_HEIGHT:
		return false
```

Then find (in `_try_hit`):

```gdscript
	var speed := lerpf(SHOT_SPEED_MIN, SHOT_SPEED_MAX, p.charge)
```

Replace with:

```gdscript
	var speed := lerpf(SHOT_SPEED_MIN, SHOT_SPEED_MAX, p.charge) * p.power
```

- [ ] **Step 3e: Serve reach + power.** Find (in `_serve_contact`):

```gdscript
	if ball.pos.distance_to(p.pos) > REACH:
		return false
```

Replace with:

```gdscript
	if ball.pos.distance_to(p.pos) > REACH * p.reach:
		return false
```

Then find (in `_serve_contact`):

```gdscript
	var speed := lerpf(SERVE_SPEED_MIN, SERVE_SPEED_MAX, quality)
```

Replace with:

```gdscript
	var speed := lerpf(SERVE_SPEED_MIN, SERVE_SPEED_MAX, quality) * p.power
```

- [ ] **Step 4: Run the harness to verify it passes**

Expected: `61 passed, 0 failed` (56 + 5), exit 0, ZERO `SCRIPT ERROR`/`Parse Error` lines. All 56 prior tests stay green because every player defaults to all-1.0 (identical to the baseline). Paste output + error-line count. If any prior test regresses, STOP and report.

- [ ] **Step 5: Commit**

```bash
git add src/sim/player_state.gd src/sim/court_sim.gd tests/
git commit -m "feat: per-player stat multipliers (speed/power/charge_rate/reach)"
```

---

### Task 2: Roster data + apply to the match

**Files:**
- Create: `src/data/roster.gd`
- Create: `tests/test_roster.gd`
- Modify: `tests/run_tests.gd` (register the new test file)
- Modify: `src/view/match.gd` (apply default characters through a single seam)

- [ ] **Step 1: Create `tests/test_roster.gd`:**

```gdscript
extends "res://tests/test_base.gd"

const Roster := preload("res://src/data/roster.gd")
const CourtSim := preload("res://src/sim/court_sim.gd")

func test_roster_has_six_characters() -> void:
	check(Roster.ROSTER.size() == 6, "roster has 6 characters")

func test_by_id_finds_the_character() -> void:
	check(Roster.by_id("speedster").speed == 1.25, "speedster has speed 1.25")
	check(Roster.by_id("nope").id == "allrounder", "unknown id falls back to all-rounder")

func test_apply_to_copies_multipliers() -> void:
	var sim := CourtSim.new()
	Roster.apply_to(sim.players[0], Roster.by_id("defender"))
	check(sim.players[0].reach == 1.3, "defender reach applied")
	check(sim.players[0].power == 0.8, "defender power applied")
	check(sim.players[0].speed == 0.95, "defender speed applied")
	check(sim.players[0].charge_rate == 1.0, "defender charge_rate applied")
```

Register it: append `"res://tests/test_roster.gd"` as the last TEST_SCRIPTS entry.

- [ ] **Step 2: Run the harness to verify it fails** (no `src/data/roster.gd`). Exit 1. Paste output.

- [ ] **Step 3a: Create `src/data/roster.gd`:**

```gdscript
extends RefCounted

# The 6 launch archetypes as plain data. Stats are multipliers on the sim's
# baseline (1.0 = baseline). `tint` is a placeholder colour hex for later visual
# differentiation (applied by the view in a later sub-project).

const ROSTER := [
	{ "id": "allrounder", "name": "All-Rounder", "tint": "457b9d", "speed": 1.0, "power": 1.0, "charge_rate": 1.0, "reach": 1.0 },
	{ "id": "speedster", "name": "Speedster", "tint": "2a9d8f", "speed": 1.25, "power": 0.8, "charge_rate": 1.0, "reach": 0.95 },
	{ "id": "power", "name": "Power Hitter", "tint": "e63946", "speed": 0.85, "power": 1.3, "charge_rate": 0.9, "reach": 1.0 },
	{ "id": "charger", "name": "Charger", "tint": "f4a261", "speed": 1.0, "power": 1.0, "charge_rate": 1.4, "reach": 0.85 },
	{ "id": "defender", "name": "Defender", "tint": "8ecae6", "speed": 0.95, "power": 0.8, "charge_rate": 1.0, "reach": 1.3 },
	{ "id": "wildcard", "name": "Wildcard", "tint": "b5179e", "speed": 1.25, "power": 1.25, "charge_rate": 0.7, "reach": 0.75 },
]

static func by_id(id: String) -> Dictionary:
	for c in ROSTER:
		if c.id == id:
			return c
	return ROSTER[0]

static func apply_to(player, character: Dictionary) -> void:
	player.speed = character.speed
	player.power = character.power
	player.charge_rate = character.charge_rate
	player.reach = character.reach
```

- [ ] **Step 3b: Run the harness to verify the roster tests pass**

Expected: `64 passed, 0 failed` (61 + 3), exit 0, ZERO error lines. Paste output + error-line count.

- [ ] **Step 3c: Apply characters in `src/view/match.gd`.** Add the preload after the existing `const WallAI := ...` line:

```gdscript
const Roster := preload("res://src/data/roster.gd")
```

Add these member vars right after the `var ai := WallAI.new()` line:

```gdscript
var player_character := "allrounder"     # the single seam the character-select screen will feed
var opponent_character := "allrounder"
```

Add this method (place it right before `_process`):

```gdscript
func _apply_characters() -> void:
	Roster.apply_to(sim.players[0], Roster.by_id(player_character))
	Roster.apply_to(sim.players[1], Roster.by_id(opponent_character))
```

Call it at the end of `_ready` (after the input node is added):

```gdscript
	_apply_characters()
```

And in `_restart`, right after `sim = CourtSim.new()`, add:

```gdscript
	_apply_characters()
```

- [ ] **Step 4: Verify suite + clean boot**

Run the harness. Expected: `64 passed, 0 failed`, exit 0, zero error lines. (Defaults are both All-Rounder = all-1.0, so no behavior change.)

Run: `"/c/Users/.../Godot_v4.7-stable_win64.exe" --path . --quit-after 180 2>&1`
Expected: no `SCRIPT ERROR` / `Parse Error` / `Cannot call` lines.

- [ ] **Step 5: Commit**

```bash
git add src/data/roster.gd src/view/match.gd tests/
git commit -m "feat: character roster data applied to the match (default all-rounder)"
```

---

## Self-review notes / deferred

- **View tint deferred:** the roster carries a `tint`, but the view is NOT tinted per character in this sub-project. With both players defaulting to All-Rounder and no character-select screen, tinting both by character would make them the same colour and lose the near/far (you/opponent) distinction the current `P1_COLOR`/`P2_COLOR` gives. Tint application is part of the character-select sub-project (#4), which is where distinct characters are actually chosen and shown.
- **Roster as dictionaries** (not a `class_name` resource): simplest form that works, matches the codebase's preload style, avoids GDScript static-construction friction. The `.tres` resources mentioned in the milestone design are only needed once the select screen loads them (sub-project #4); the sim only ever sees floats.

## Out of scope (later sub-projects)

Character-select UI + `.tres`; court surfaces; AI tiers/personalities; ladder flow; real pixel-art sprites; per-character unique specials.
