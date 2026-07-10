# Court Surfaces (Data-Driven) — Design Spec

**Date:** 2026-07-10
**Status:** Approved design, pre-implementation
**Context:** Sub-project 2 of Milestone 4 "The Ladder". Makes the simulation apply per-court surface rules, following the same data-driven pattern as character stats (sub-project 1). Court selection UI and the ladder come in sub-project 4.

## Goal

Courts play differently: the sim carries four surface parameters (neutral by default = today's behavior), and the 4 launch courts are defined as data. Clay slows the ball and bounces higher; grass bounces low and skiddy; ice makes players faster but slow to change direction.

## Surface parameters

All default to the neutral value, which reproduces today's behavior exactly.

| Param | Neutral | Effect |
|---|---|---|
| `bounce_speed` | 1.0 | fraction of horizontal ball velocity kept on a bounce |
| `bounce_height` | 1.0 | multiplier on bounce restitution (vertical energy kept) |
| `move_response` | 1.0 | how fast player velocity converges to the input target per tick (1.0 = instant, low = slow to turn/stop) |
| `move_speed` | 1.0 | multiplier on player max movement speed |

### The 4 launch courts (starting values — tuned by feel later)

| Court | id | bounce_speed | bounce_height | move_response | move_speed | Feel |
|---|---|---|---|---|---|---|
| Hard Court | hard | 1.0 | 1.0 | 1.0 | 1.0 | neutral (identical to today) |
| Clay | clay | 0.85 | 1.2 | 1.0 | 1.0 | slow ball, high bounce, long rallies |
| Grass | grass | 1.0 | 0.7 | 1.0 | 1.0 | low skidding bounce, fast points |
| Ice Rink | ice | 1.0 | 1.0 | 0.15 | 1.2 | faster movement, hard to change direction |

Each court also carries a `name` and a placeholder court colour for later visual differentiation (applied by the view in sub-project 4).

**Ice design decision (user choice):** ice = more speed but harder to change direction (low `move_response`), NOT free-sliding inertia. The player still decelerates toward zero when input stops — just slowly.

## Movement model (what makes ice work)

`PlayerState` gains `move_vel := Vector2.ZERO`. Each tick in `_move_player`:

- If `hit_held`: `move_vel = Vector2.ZERO` and return (charging still locks in place, as today).
- Else: `target = normalized_input * PLAYER_SPEED * p.speed * move_speed`; `p.move_vel = p.move_vel.lerp(target, move_response)`; `p.pos += p.move_vel * TICK`; existing half-court clamps unchanged.

With `move_response = 1.0`, `move_vel` equals the target instantly — bit-identical to today's movement, so all existing movement tests stay green. Only ice (0.15) turns and stops slowly.

## Bounce model (clay/grass)

At the bounce point in `_update_ball`:
- vertical: `ball.v_height = -ball.v_height * RESTITUTION * bounce_height`
- horizontal: `ball.vel *= bounce_speed`

With 1.0/1.0 this is identical to today.

## Architecture

- **Sim stays pure.** `CourtSim` gains the four surface fields as plain floats (defaults neutral). No Resource/Node loading in the sim.
- **Court data above the sim:** `src/data/courts.gd` (same pattern as `roster.gd`) — the 4 courts as plain dictionaries (`id`, `name`, `color` hex, the 4 params), `by_id(id)` with fallback to hard, and `apply_to(sim, court)` copying the 4 params onto the sim.
- **Match wiring (until sub-project 4):** `Match` gains a `court := "hard"` seam and calls `Courts.apply_to(sim, Courts.by_id(court))` when constructing the sim (`_ready` and `_restart`). Default hard = neutral = no behavior change. The ladder/menus feed this seam later.
- **View court colour deferred to sub-project 4**, same as character tints (no court choice exists yet to display).

## Testing (headless, deterministic)

- **Baseline preserved:** a neutral sim behaves exactly as before — the existing 64 tests stay green unchanged.
- **Clay:** the ball keeps less horizontal speed across a bounce than on hard, and bounces higher.
- **Grass:** the ball bounces lower than on hard.
- **Ice:** starting from rest with a held input, the player takes more ticks to approach max speed than on hard; top speed is higher (move_speed 1.2); and reversing input direction takes longer to actually reverse velocity.
- **courts.gd:** has 4 courts; `by_id` falls back to hard; `apply_to` copies the 4 params.
- **Determinism canary** stays green (`lerp` on floats is deterministic).

## Out of scope (later sub-projects)

Court selection UI / ladder court sequence (sub-project 4); court visuals (background colour per court — data is carried, view applies it in 4); AI adjustments per surface; real art.
