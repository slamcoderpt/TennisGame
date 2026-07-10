# Arcade Tennis — Game Design & Architecture Spec

**Date:** 2026-07-10
**Status:** Approved design, pre-implementation
**Engine:** Godot 4.x
**Platforms:** Android + iOS (Android is the primary test device)
**Phase 1 scope:** Single-player arcade mode. Online multiplayer is phase 2; monetization model deferred (unlock hooks built in).

## 1. Concept

A retro pixel-art, Windjammers-paced arcade tennis game. The phone is held in **landscape**; the court runs **vertically** (player at the bottom, opponent at the top) framed by a **tilted 2.5D camera** — the court is drawn as a trapezoid receding toward the opponent, with sprite scaling and a ball shadow faking depth. Left thumb moves, right thumb charges and releases shots. Real tennis scoring. Matches are short sets: **first to 3 games**.

## 2. Core Gameplay

### Point loop

Serve → rally → point ends (double bounce, ball out, or net) → tennis score updates (15/30/40, deuce, advantage) → next point. First to 3 games wins the match. No tiebreaks.

### Movement

- Left virtual floating joystick, 8-directional free movement, confined to the player's half.
- Snappy arcade movement: near-instant acceleration, small skid on stop.
- `speed` is a per-character stat.

### Hitting

The player can strike when the ball is inside their **reach radius** (per-character stat).

- **Tap** hit → quick shot: fast release, medium power. Default aim is the far corner away from the player's position, nudged by the left stick at the moment of release.
- **Hold** hit → charge: character plants (cannot move while charging); a charge ring fills in ~0.6 s. Release → power shot: faster ball, sharper allowed angle. Charging trades mobility for power — the core tension.
- **Aim** always comes from the left stick at release. No stick input = safe center-deep shot.
- Late/stretched contact (ball at the edge of the reach radius) produces a weaker shot with reduced aim control.

### Shot types (context-dependent, same two inputs)

| Shot | Input | Behavior |
|---|---|---|
| Flat drive | tap or charged release | fast, low arc — the default |
| Lob | release with stick held toward own baseline | slow, high arc, lands deep; beats net-rushers, punished if short |
| Drop shot | tap with stick held toward the net | soft touch just over the net; beats baseline campers |

### Super meter

- Fills from: clean winners (large), each exchange in long rallies (small), full-charge shots (small).
- When full, the next **fully charged** release becomes the character's **Special Shot** (screen flash, unique ball behavior).
- Phase 1 ships one shared special template (a swerving power ball); the system is keyed per character from day one so unique specials are a phase-2 content drop, not a refactor.
- Meter persists across points and games within a match; resets between matches.

### Serving

- Toss is automatic; the player times a tap on a moving power meter (perfect window = faster serve) and aims left/right in the service box with the stick.
- Double faults are possible but rare by design; the serve is a small edge, not a weapon.

## 3. Content

### Characters — 6 at launch, data-driven

Stats: `speed`, `power`, `charge_rate`, `reach`, plus sprite set and `special_shot_id` (future).

| Archetype | Trade-off |
|---|---|
| All-rounder | baseline everything |
| Speedster | fast, weak shots |
| Power hitter | slow, cannon shots |
| Charger | fast charge, short reach |
| Defender | big reach, low power |
| Wildcard | fast + strong, tiny reach and slow charge |

**Pixel-art cost control:** two shared body rigs (light / heavy). All six characters animate from those two spritesheet skeletons using palette swaps plus unique heads/silhouette details. Future roster waves reuse the rigs.

### Courts — 4 at launch, one gameplay rule each

| Court | Rule |
|---|---|
| Hard court (stadium) | neutral baseline court, used for the tutorial |
| Clay | ball slows ~15% after bounce, bounces higher — longer rallies |
| Grass | ball keeps ~15% more speed after bounce, lower skid — fast points |
| Ice rink | players slide (movement momentum); ball behaves normally — late-ladder chaos |

### Arcade Mode (phase 1 spine)

- Pick a character → ladder of the other 5 + a final boss: a 7th non-playable "champion" with cheat-grade stats (unlockable later).
- Matches progress through the courts; difficulty rises via AI tier and personality.
- Between matches: results screen and continue. No meta-economy yet, but characters and courts carry an `unlocked` flag in their data files so any business model can hook in without refactoring.

## 4. Architecture

**Golden rule: the simulation never touches a Node.** Two layers, one-way data flow.

```
[ Sim layer — pure GDScript classes (RefCounted) ]
  CourtSim: fixed-tick update (60 Hz), owns all rules
   ├─ entities in court space: (x, y, height) floats
   ├─ BallState: position, velocity, spin, bounce count
   ├─ PlayerState ×2: position, charge, meter, reach
   ├─ RulesJudge: in/out, net, double bounce → point events
   └─ MatchScore: points/games, deuce logic
        │  emits events: BallHit, PointWon, GameWon...
        ▼
[ Presentation layer — Godot scenes ]
  CourtView: projects court space → screen pixels
   ├─ trapezoid court sprite, net, lines
   ├─ entity sprites scaled by depth (y), ball shadow blob
   ├─ VFX/SFX reacting to sim events
   └─ HUD: score, charge ring, super meter
```

Key decisions:

- **Court-space simulation + 2D projection.** Game logic lives in abstract court coordinates `(x, y, height)`; ball flight is custom deterministic math (no physics engine). A projection layer converts court space to screen pixels (trapezoid skew, depth scaling, height → vertical offset + shadow). Arcade ball physics are tuned, not simulated.
- **Fixed-tick sim** in `_physics_process` (60 Hz); presentation interpolates in `_process`. Deterministic — the prerequisite for phase-2 rollback/lockstep netcode.
- **Input as an interface.** The sim consumes `InputFrame` objects (move vector, hit pressed/released). Touch controls, AI, and future network peers all produce the same shape. The AI cannot bypass the rules — it plays through the same interface.
- **AI** = state machine (`POSITION` → predicted landing spot, `STRIKE` → tap/charge + aim, `RECOVER`). Difficulty tier = reaction delay + prediction error + aim error. Personality = shot-choice weights (aggressive / defensive / tricky). Ladder opponents combine one tier with one personality.
- **Data-driven content.** `data/characters/*.tres` and `data/courts/*.tres` resources hold stats, palettes, rig ids, court rule params, and `unlocked` flags. New character = new resource + head sprites, zero code.
- **Scenes.** `Main` → `TitleScreen`, `CharacterSelect`, `Match` (CourtSim + CourtView + HUD), `ResultsScreen`. A thin `GameFlow` autoload handles transitions and ladder progress.
- **Project layout:** `src/sim/` (pure logic, unit-testable headless), `src/view/`, `src/input/`, `src/ai/`, `data/`, `assets/sprites/`.

## 5. UI/UX and Game Feel

### Touch UX

- Left half of screen: floating joystick (base appears where the thumb lands).
- Right half of screen: the entire region is the hit button — no small target to miss at speed.
- Charge ring renders around the character, not the thumb, so eyes stay on the court.
- Small corner pause button; safe-area aware for notches.

### Game feel checklist

Hit-pause (2–3 frames) on power shots; screen shake scaled to shot power; speed lines above a velocity threshold; chunky bounce/hit SFX; crowd roar on winners and break points; retro announcer voice for score calls ("Deuce!").

## 6. Testing

- Unit tests (GUT) on the sim layer: scoring edge cases (deuce/advantage), in/out judgment, ball trajectory math, meter accrual, AI input validity.
- The sim runs headless — tests execute without rendering.
- Touch feel is validated by on-device playtesting on Android from milestone 1 onward.

## 7. Milestones (each playable)

1. **The Rally** — court rendered, one moving square vs a wall-AI, ball sim, tap-to-hit. *Goal: hitting feels good.*
2. **The Point** — scoring, serves, in/out, full match vs basic AI, HUD.
3. **The Game** — charge shots, lob/drop, super meter, game-feel pass, one finished character sprite set.
4. **The Ladder** — 6 characters, 4 courts, AI personalities, arcade mode flow, menus.
5. **The Ship** — polish, audio, onboarding tutorial, Android build → iOS build, store prep.

## 8. Explicitly Deferred (phase 2+)

- Online multiplayer (enters at the `InputFrame` boundary; sim determinism is the enabler).
- Per-character unique special shots (system is keyed per character already).
- Monetization model (enters at the `unlocked` data flag).
- Additional characters/courts (data-driven waves on shared rigs).
- Local multiplayer.
