# Realistic Serve — Design Spec

**Date:** 2026-07-10
**Status:** Approved design, pre-implementation
**Context:** Enhancement to the existing serve in the Arcade Tennis game (milestones 1–3 complete). Builds on the deterministic sim and the hold-to-charge input model.

## Goal

Replace the current "ball hovers, hit like a groundstroke, lands deep" serve with a real-tennis feel: a **tossed ball hit on timing** (hold to toss, release to make contact) served **diagonally cross-court**, with the server alternating deuce/ad sides each point.

## Scope

**In scope:** ball toss + release timing, diagonal serve positioning and cross-court aim, backward-compatible tap-serve for existing tests.

**Explicitly out of scope (user decision):** service boxes (the landing rule stays "opponent's half, in bounds"), overhead/downward serve motion, per-character serve traits. No new fault zone is introduced.

## Serve Flow (toss + timing)

1. **Ready:** at the start of each point the ball rests low ("in hand") on the server's side at the current deuce/ad spot, at a low height (`SERVE_HEIGHT ≈ 0.4`). `is_tossing` is false; `in_play` is false. The HUD "SERVE" prompt shows.
2. **Hold → toss:** while the server holds hit and the ball is not yet in play, the ball is tossed: it receives an upward velocity (`TOSS_VELOCITY`) once, then rises and falls under gravity. Height integrates every tick even though the ball is not "in play". Player movement is locked (same as charging). `is_tossing` becomes true.
3. **Release → contact:** on the release edge while serving, contact is attempted. Serve quality is a function of the ball's **height at release** relative to an ideal contact height near the toss apex (`IDEAL_CONTACT_HEIGHT`), over a generous window (`CONTACT_WINDOW`):
   - Release with the ball airborne at/near ideal → clean serve at up to `SERVE_SPEED_MAX`.
   - Release off-timing (ball low — released early before it rose, or late after it fell, but still above `MIN_CONTACT_HEIGHT`) → a slower serve down toward `SERVE_SPEED_MIN`; still legal if it clears the net and lands in.
   - Ball below `MIN_CONTACT_HEIGHT` at release, or the toss falls back to the ground untouched → **failed serve = fault** via the existing `_serve_fault` (first → second serve, second → double fault).
4. **After contact** the ball is a normal in-play serve: existing net collision, in/out, double-bounce judgment, and the "receiver must let the serve bounce" rule all apply unchanged.

**Speed mapping:** `serve_speed = lerp(SERVE_SPEED_MIN, SERVE_SPEED_MAX, quality)` where `quality = clamp(1 - abs(height - IDEAL_CONTACT_HEIGHT) / CONTACT_WINDOW, 0, 1)`.

**Backward-compatible tap serve:** a plain `hit_pressed` with no preceding hold (as existing tests inject) makes contact immediately at a default quality (a "quick serve"), so all current tests and their assertions (ball goes to the far side, faults on a poked own-side landing, etc.) keep passing. Concretely: if a release/contact happens while `is_tossing` is false, treat it as a default-quality serve rather than a whiff.

## Diagonal Positioning

- **Sides alternate each point within a game.** Total points played in the current game = `score.points[0] + score.points[1]`. Even → **deuce court** (server's right), odd → **ad court** (server's left). The server still swaps each game (existing behavior).
- **Server x position:** for a server with `side = s` (-1 bottom, +1 top), deuce-court x is `-s * SERVE_X`, ad-court x is `+s * SERVE_X`. `reset_for_serve` places the ball and does **not** move the player; the player may walk to the ball as today.
- **`SERVE_X = 1.5` (chosen deliberately):** a player at the center baseline `(0, ±9)` is `sqrt(1.5² + 1²) ≈ 1.8` from the serve spot at `(±1.5, ±8)`, which is inside `REACH` (2.0). This keeps the existing tap-serve tests — which serve from the default center position — within reach so they pass unchanged, while still giving a visible ~3-unit cross-court diagonal. (If `REACH` is later tuned below ~1.8, revisit this.)
- **Cross-court aim:** the serve auto-aims to the diagonally opposite side, `target.x = -server_x` (mirrored across center), at the existing far-side serve depth. The stick still nudges aim within `AIM_MAX_X`.
- No service-box fault: the serve only needs to clear the net and land in the opponent's half (existing rule).

## Architecture

All logic stays in the deterministic sim (`src/sim/court_sim.gd`), preserving purity and determinism (no RNG/time/Node). Changes:

- **New state:** `is_tossing: bool` on `CourtSim`.
- **New constants:** `TOSS_VELOCITY`, `IDEAL_CONTACT_HEIGHT`, `CONTACT_WINDOW`, `MIN_CONTACT_HEIGHT`, `SERVE_SPEED_MIN`, `SERVE_SPEED_MAX`, `SERVE_X`. `SERVE_HEIGHT` lowered to the in-hand rest height.
- **`reset_for_serve`:** compute deuce/ad from points parity, place the ball at `(deuce_or_ad_x, SERVE_DEPTH*side)` at rest height, clear `is_tossing`.
- **Toss physics:** in `tick()` (or a small `_update_toss`), when serving (not `in_play`) and the server holds hit, start/continue the toss — integrate `v_height`/`height` under gravity. If the tossed ball reaches the ground untouched, trigger `_serve_fault`.
- **`_try_hit` serve branch:** when serving, compute quality from release height, set `serve_speed`, aim cross-court; a no-toss tap uses default quality. Rally hits are unchanged.
- **View:** the ball naturally renders through the existing projection (its height already drives the sprite/shadow). No new view code is required for the toss, though the HUD "SERVE" prompt remains. (A toss-timing indicator is optional polish, not in this spec.)

The rally charge path (`hit_held` builds `charge`, release fires a charged groundstroke) is untouched and only applies once the ball is in play.

## Testing (headless, deterministic)

- **Toss rises then falls:** holding during serve makes `ball.height` increase then decrease.
- **Timing → speed:** a serve released near `IDEAL_CONTACT_HEIGHT` leaves faster than one released well off it.
- **Missed toss faults:** holding then never releasing until the ball lands increments `serve_faults` (and a second missed toss scores for the receiver).
- **Deuce/ad alternation:** across successive points in a game, the served ball's x alternates between the deuce and ad spots.
- **Cross-court aim:** a serve from the deuce spot travels toward the opposite-x half.
- **Backward compatibility:** the tap-serve path is preserved (a `hit_pressed` tap still serves to the far side; own-side poked landings still fault). Three tests that exercised charge/special by holding on the serve are repointed to an in-play rally ball, since the serve is no longer charge-powered; the mechanics remain fully tested.
- **Determinism canary** stays green.

## Deferred / Future

Service boxes and a proper diagonal fault zone; overhead serve motion; a visible toss-timing meter; per-character serve traits. These can layer on later without reworking this design.
