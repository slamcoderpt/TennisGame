# Arcade Tennis

Retro pixel-art arcade tennis (Windjammers pace) for Android/iOS. Godot 4.x.

- Spec: docs/superpowers/specs/2026-07-10-arcade-tennis-design.md
- Plans: docs/superpowers/plans/
- Run the game: `godot --path .`
- Run tests: `godot --headless --path . -s res://tests/run_tests.gd`

Desktop controls (dev): arrows move, hold Space to charge then release to hit
(stick back = lob, forward = drop). Serving, move to position (the ball is in
your hand), then hold Space to toss and release near the top to hit; aim with
the stick. Touch: left half = floating joystick, right half = hold-to-charge
hit. Mouse emulates touch. Press D to toggle the debug reach ring.

Layout: `src/sim/` pure deterministic game logic (never touches Nodes),
`src/view/` projection + rendering, `src/input/` InputFrame producers,
`src/ai/` AI opponents (also InputFrame producers), `tests/` headless tests.

## Milestone 3 status: The Game

Hold to charge shots (movement locks while winding up); release with the stick
back for a lob or forward for a drop. A super meter fills through rallies and
points; a full-meter full-charge release fires a swerving special. Game feel:
charge ring, hit-pause, screen shake. Players render through a billboarded,
depth-scaled sprite pipeline (placeholder art — drop real PNGs into
src/view/sprite_sheet.gd's build()). Deferred: serve power-timing meter,
service boxes, per-character unique specials. Next: roster, courts with
gameplay rules, arcade ladder, menus, mobile builds.
