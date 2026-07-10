# Character Stats (Data-Driven) — Design Spec

**Date:** 2026-07-10
**Status:** Approved design, pre-implementation
**Context:** Sub-project 1 of Milestone 4 "The Ladder" for the Arcade Tennis game. Makes the simulation read per-character stats instead of one hardcoded stat set, and defines the 6-character roster's stat data. Character-select UI, courts, AI personalities, and the ladder are separate sub-projects.

## Goal

Each character plays differently: the sim reads per-player stat multipliers (`speed`, `power`, `charge_rate`, `reach`) layered on the existing tuned baseline, and the 6 roster archetypes are defined as data.

## Stats model

Stats are **multipliers around 1.0** applied to the current global baseline constants. All-1.0 reproduces today's behavior exactly.

| Stat | Scales | Effect |
|---|---|---|
| `speed` | `PLAYER_SPEED` | movement units/sec |
| `power` | rally + serve shot speed | how hard the ball leaves |
| `charge_rate` | charge accrual per tick | how fast the wind-up fills (higher = faster) |
| `reach` | `REACH` | hit radius |

The global constants remain the baseline; multipliers only deviate from it. Tuning the baseline still happens in one place.

### Roster archetypes (starting values — tuned by feel later)

| Character | id | speed | power | charge_rate | reach |
|---|---|---|---|---|---|
| All-Rounder | allrounder | 1.00 | 1.00 | 1.00 | 1.00 |
| Speedster | speedster | 1.25 | 0.80 | 1.00 | 0.95 |
| Power Hitter | power | 0.85 | 1.30 | 0.90 | 1.00 |
| Charger | charger | 1.00 | 1.00 | 1.40 | 0.85 |
| Defender | defender | 0.95 | 0.80 | 1.00 | 1.30 |
| Wildcard | wildcard | 1.25 | 1.25 | 0.70 | 0.75 |

Each character also carries a distinct `tint` (Color) for placeholder visual differentiation until real pixel art exists, and a `name` for menus.

## Architecture

**Sim stays pure** (`RefCounted`, no Node/Resource loading, deterministic, headless-testable).

- **`PlayerState`** gains four multiplier fields — `speed`, `power`, `charge_rate`, `reach` — each defaulting to `1.0`. The sim reads `players[i].<stat>` where it currently reads the global constant:
  - `_move_player`: `PLAYER_SPEED * p.speed`
  - charge accrual in `tick`: `... + TICK / CHARGE_TIME * p.charge_rate`
  - hit reach check: `REACH * p.reach`
  - shot/serve speed in `_try_hit` / `_serve_contact`: multiply the computed speed by `p.power`
- With every multiplier at `1.0`, behavior is identical to today, so existing tests stay green unchanged.

**Character data lives above the sim.** A small `src/data/character_data.gd` (`RefCounted`) holds the fields (`id`, `name`, `tint`, `speed`, `power`, `charge_rate`, `reach`) and:
- a static roster (the 6 archetypes above), addressable by id and as an ordered list;
- `apply_to(player_state)` that copies the four multipliers onto a `PlayerState`.

The sim never imports this — it only ever sees floats on `PlayerState`. The `.tres` resource files for the select screen are deferred to the arcade-menus sub-project; here the roster is plain in-code data.

**Match wiring (until the select screen exists):** `Match` (or a thin seam it calls) applies two `CharacterData` to the sim's players when constructing a match, defaulting to both All-Rounder, with a single assignment point that the future character-select screen will feed. The placeholder sprite tint uses the character's `tint`.

## Testing (headless, deterministic)

- **Baseline preserved:** a sim with default (all-1.0) players behaves exactly as before — the full existing suite stays green unchanged.
- **`apply_to` copies stats:** applying an archetype sets the four multipliers on the `PlayerState`.
- **Speed:** a Speedster player advances more per tick than an All-Rounder given the same move input.
- **Power:** a Power Hitter's struck ball leaves faster than an All-Rounder's at the same charge.
- **Reach:** a Defender returns a ball that is out of the baseline reach (and the All-Rounder cannot).
- **Charge rate:** a Charger reaches full charge in fewer ticks than an All-Rounder.
- **Determinism canary** stays green (multipliers are plain deterministic floats).

## Out of scope (later sub-projects)

Character-select UI and `.tres` resources (arcade-menus sub-project); court surfaces; AI tiers/personalities; the ladder flow; real pixel-art sprites (tint-only differentiation for now); per-character unique special shots (the special stays the shared swerving template).
