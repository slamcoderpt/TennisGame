# Serve "In Hand" + Stick Aim — Design Spec

**Date:** 2026-07-10
**Status:** Approved design, pre-implementation
**Context:** Refinement of the realistic serve ([prior spec](2026-07-10-realistic-serve-design.md)) in the Arcade Tennis game. Supersedes that spec's diagonal deuce/ad positioning and cross-court auto-aim.

## Goal

Before the toss, the ball is "in the server's hand": it follows the server as they move, so the player positions freely, then holds to toss and releases to hit — aiming with the stick like a normal shot.

## What changes

- **Ball in hand (new):** while serving and not yet tossing, the ball sits at the server's position at rest height and follows the server every tick. The server moves freely within their own half (normal movement) to set up the serve.
- **Toss + timing (unchanged):** holding starts the toss (ball rises from the current spot, movement locks); releasing makes contact with height-based timing quality; a missed toss faults; a no-toss tap serves at the default quality.
- **Aim by stick (changed):** the served ball is aimed by the stick at release (`aim_x = clamp(input.move.x) * AIM_MAX_X`) toward the opponent's side (`-side * TARGET_DEPTH`), exactly like a rally shot. Neutral stick serves straight ahead.

## What is removed (from the prior serve spec)

- The fixed deuce/ad serve spot and its per-point side alternation.
- The cross-court auto-aim (`target.x = -ball.pos.x`) and the `SERVE_AIM_NUDGE` constant.
- The `SERVE_X` constant.

This is a net simplification: fewer constants and less positioning logic.

## Serve flow (end to end)

1. **Ready / in hand:** the ball rests at `SERVE_HEIGHT` on the server's current position; each tick while `not ball.in_play and not is_tossing`, `ball.pos` is set to the server's position. The player may move to reposition. HUD shows "SERVE".
2. **Hold → toss:** the server holds hit → `is_tossing = true`, `ball.v_height = TOSS_VELOCITY`; the ball rises/falls under gravity from the spot it was in when the toss began; movement locks. A toss that lands untouched → `_serve_fault`.
3. **Release → contact (`_serve_contact`):** speed from timing (`quality = clamp(1 - |height - IDEAL_CONTACT_HEIGHT| / CONTACT_WINDOW, 0, 1)`, `lerp(SERVE_SPEED_MIN, SERVE_SPEED_MAX, quality)`); releasing below `MIN_CONTACT_HEIGHT` while tossing → fault; a no-toss tap uses `SERVE_TAP_QUALITY`. Aim: `target = Vector2(clamp(input.move.x, -1, 1) * AIM_MAX_X, -p.side * TARGET_DEPTH)`.
4. **After contact:** normal in-play serve under existing net / in-out / double-bounce / "receiver must let the serve bounce" rules.

## Architecture

All in the deterministic sim (`src/sim/court_sim.gd`):

- **`reset_for_serve`:** drop the deuce/ad computation; set `ball.pos = players[server].pos` (in hand) at rest height; keep clearing state (`is_tossing`, `is_serve`, swerve, buffers).
- **Follow-the-hand:** in `tick`, after player movement and before the toss/hit handling, when `not ball.in_play and not is_tossing`, set `ball.pos = players[server].pos` (and keep `prev_pos` sensible so rendering is smooth).
- **`_serve_contact`:** replace the cross-court aim line with the stick-based `aim_x` used by rally shots. Everything else (timing quality, launch, fault-on-low-release, meter accrual, `is_serve`/`last_hitter`/`hit_count`) stays.
- **Remove** `SERVE_X` and `SERVE_AIM_NUDGE` constants.

The rally charge/lob/drop/special path is untouched.

## Testing (headless, deterministic)

Replace the prior serve-positioning tests:

- **Ball follows the hand:** while serving (not holding), moving the server moves the serve ball to the same position.
- **Serve aims by stick:** a serve released with the stick left produces `vel.x < 0`; with the stick right, `vel.x > 0`; neutral is ~straight (`vel.y > 0`, small `vel.x`).
- Keep the timing tests (`near-apex faster than early`, `speed follows toss timing not hold time`), the missed-toss fault, and the tap-serve-still-works test — all still valid.
- **Repoint `test_cannot_hit_out_of_reach`** (in `tests/test_sim.gd`) to an in-play rally ball: the serve ball is now always in the server's hand, so it can no longer exercise the out-of-reach gate; the rally reach gate is what that test should cover.
- Determinism canary stays green; the full suite stays green otherwise.

## Deferred / Future (unchanged)

Service boxes and a diagonal fault zone; overhead serve motion; a visible toss-timing meter; per-character serve traits.
