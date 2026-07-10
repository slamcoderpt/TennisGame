# Arcade Tennis

Retro pixel-art arcade tennis (Windjammers pace) for Android/iOS. Godot 4.x.

- Spec: docs/superpowers/specs/2026-07-10-arcade-tennis-design.md
- Plan (milestone 1): docs/superpowers/plans/2026-07-10-milestone-1-the-rally.md
- Run the game: `godot --path .`
- Run tests: `godot --headless --path . -s res://tests/run_tests.gd`

Desktop controls (dev): arrows move, Space hits. Touch: left half = floating
joystick, right half = hit. Mouse emulates touch.

Layout: `src/sim/` pure deterministic game logic (never touches Nodes),
`src/view/` projection + rendering, `src/input/` InputFrame producers,
`src/ai/` AI opponents (also InputFrame producers), `tests/` headless tests.

## Milestone 1 status: The Rally

Playable rally — move to the ball and hit it back and forth against a wall AI,
on a tilted 2.5D court. No scoring or net collision yet (the ball passes through
the net by design); those arrive in milestone 2.
