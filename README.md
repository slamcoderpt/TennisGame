# Arcade Tennis

Retro pixel-art arcade tennis (Windjammers pace) for Android/iOS. Godot 4.x.

- Spec: docs/superpowers/specs/2026-07-10-arcade-tennis-design.md
- Plans: docs/superpowers/plans/
- Run the game: `godot --path .`
- Run tests: `godot --headless --path . -s res://tests/run_tests.gd`

Desktop controls (dev): arrows move, Space hits. Touch: left half = floating
joystick, right half = hit. Mouse emulates touch.

Layout: `src/sim/` pure deterministic game logic (never touches Nodes),
`src/view/` projection + rendering, `src/input/` InputFrame producers,
`src/ai/` AI opponents (also InputFrame producers), `tests/` headless tests.

## Milestone 2 status: The Point

Full tennis points: serves with faults and double faults, net collision,
in/out judgment, double-bounce rule, 15/30/40/deuce/advantage scoring,
first to 3 games, HUD with score and messages. Hit after match point to
restart. Milestone 3 adds charge shots, lob/drop, the super meter, sprites
and the game-feel pass.
