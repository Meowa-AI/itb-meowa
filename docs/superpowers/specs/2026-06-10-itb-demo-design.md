# Into the Breach Demo Clone — Design

**Date:** 2026-06-10
**Target:** Godot 4.6.1, GDScript
**Scope:** Playable demo run — 7 sequential missions, upgrades between battles, run ends when grid power reaches 0.

## Overview

A demo-scale clone of Into the Breach's core loop: deterministic, perfect-information tactical combat on an 8×8 isometric grid. The player controls 3 mechs defending buildings against vek (bugs). Enemies telegraph their attacks one turn ahead; the player wins by disrupting those attacks with displacement (push/pull), terrain kills, and positioning. A run is 7 fixed missions with an upgrade shop between them.

## Architecture

**Logic core + thin scene view, content as Resources.**

```
itb-demo/
├── project.godot
├── src/
│   ├── core/                 # Pure logic, no scene-tree deps (RefCounted)
│   │   ├── battle_state.gd   # Grid, units, buildings, grid power; snapshot/restore
│   │   ├── unit.gd           # Position, HP, team, weapon refs, status
│   │   ├── actions.gd        # Move/attack validation + execution → list of Events
│   │   ├── push.gd           # Displacement resolution: collisions, water, chasms
│   │   ├── telegraph.gd      # Enemy intents; redirection when units move
│   │   ├── enemy_ai.gd       # Target picking, spawn point selection
│   │   └── run_state.gd      # Mission sequence, grid HP carryover, reputation, owned weapons
│   ├── data/                 # Resource definitions (.gd scripts + .tres content)
│   │   ├── weapon_def.gd     # Damage, range pattern, push/pull effect, upgrade tiers
│   │   ├── unit_def.gd       # Mech/vek stats
│   │   └── mission_def.gd    # Map layout, objective, spawn schedule
│   └── view/                 # Scenes: rendering, animation, input
│       ├── battle/           # Iso grid renderer, unit sprites, telegraphs, highlights
│       ├── ui/               # HUD, end-turn, undo, objectives, grid power bar
│       └── screens/          # Title → Battle → Upgrade shop → Victory / Game over
├── assets/                   # Meowa-generated sprites, tiles, audio
└── tests/                    # GUT unit tests for src/core
```

**Core contract:** the view never mutates game state. Input produces an Action; `core` validates and executes it, returning an ordered list of Events (`unit_moved`, `unit_pushed`, `unit_damaged`, `building_damaged`, `unit_died`, `vek_spawned`, ...). The view plays Events back as animations.

- **Undo / turn reset:** snapshot `BattleState` at player-turn start; undo restores it. The core sim is RNG-free (AI tie-breaks use a state-derived hash), so restore is exact.
- **Outcome preview:** on hovering an attack, run the action on a cloned state and render the predicted events as ghost indicators.
- **Isometric:** `core` uses plain (x, y) grid coordinates. The view converts to iso screen space (64×32 diamond tiles) and depth-sorts with Y-sort.

## Combat Rules

**Turn loop:**
1. **Vek attack** — enemies execute the attacks telegraphed last turn (skipped on turn 1).
2. **Vek move & telegraph** — AI moves each vek, then displays its intended attack (tile + direction).
3. **Spawn resolution & telegraph** — first, tiles marked last turn resolve: if unoccupied, the vek emerges; if a unit stands there, the spawn is blocked (blocker takes 1 damage; the vek retries next turn from the same tile). Then new spawn tiles are marked per the mission's spawn schedule.
4. **Player turn** — each mech may move once and act once (any order across the squad). Undo available until End Turn. End Turn → step 1.

**Telegraphs target tiles, not units.** A vek aims at a tile. If the vek is pushed, its attack origin moves with it and the attack line shifts accordingly. If the intended victim moves or is pushed away, the attack hits the tile anyway — including whatever now occupies it (another vek, a mech, nothing).

**Displacement:** pushed/pulled units move exactly 1 tile.
- Destination occupied by a unit → both take 1 damage, no movement.
- Water → ground units die instantly; flying units are unaffected.
- Chasm → all non-flying units die.
- Mountain → collision: 1 damage to unit, 1 damage to mountain (mountains have 2 HP, then become rubble = plain tile).
- Building → collision: 1 damage to unit and 1 to building.
- Map edge → treated as a wall: 1 collision damage, no movement.

**Terrain set:** plain, water, mountain (blocks movement and line attacks; destructible), chasm, building tiles. No forest, fire, smoke, or acid.

**Grid power:** shared pool, starts at 8 (cap 10). Each point of building HP lost = −1 grid power. Persists across missions; the only way to restore it is the shop's "+1 Grid Power" item. 0 = run over. No defense RNG — every building hit deals its damage. *(Balance changed from the original draft — playtesting showed a non-recoverable 7-point pool made missions 5–7 statistically unwinnable.)*

**Buildings:** 1–2 HP each, placed per mission map. Excess damage beyond a building's remaining HP is ignored for grid power accounting.

## Run Structure & Content

**Flow:** Title → M1 → Shop → M2 → Shop → ... → M7 (boss) → Victory.
Game Over if grid power hits 0 or all 3 mechs are destroyed in one battle.
Mechs repair to full HP between missions.

**Missions (fixed sequence, hand-authored 8×8 maps):**

| # | Objective | Notes |
|---|-----------|-------|
| 1 | Kill all vek | Intro: 3 weak vek |
| 2 | Kill all vek | Adds Firefly (ranged) |
| 3 | Survive 5 turns | Heavy spawn pressure |
| 4 | Protect the objective structure | Structure has own HP; losing it fails the mission (−2 grid power) but the run continues |
| 5 | Kill all vek | Harder mix incl. Scarab artillery |
| 6 | Survive 6 turns | Boss minions preview |
| 7 | Kill the boss | Hornet Leader + escorts |

"Kill all" completes only when no live vek remain **and** no pending spawns exist. "Survive" missions end after the final enemy phase of turn N; remaining vek despawn.

**Enemies:**

| Vek | Type | Attack |
|-----|------|--------|
| Hornet | Flying | Melee, 1 dmg |
| Firefly | Ground | Line projectile, 1 dmg |
| Scorpion | Ground, tanky | Melee, 2 dmg |
| Scarab | Ground | Artillery arc (ignores mountains), 1 dmg |
| Hornet Leader (boss) | Flying, 9 HP | Melee sweep hitting all 4 adjacent tiles, 2 dmg |

**Mech squad (fixed, 3):**

| Mech | Weapon | Effect |
|------|--------|--------|
| Prime | Titan Fist | Melee, 2 dmg, pushes target away |
| Artillery | Arc Shot | Artillery, 1 dmg at impact, pushes the 4 adjacent tiles outward |
| Science | Force Beam | Line projectile, 1 dmg, pulls target 1 tile toward shooter |

**Mid-battle mech death:** dead for the rest of that battle, returns at full HP next mission.

**Economy:** completing a mission earns 3 reputation + 1 for the bonus objective ("lose no grid power this mission"). Unspent rep carries over. Shop offers:

| Item | Cost | Effect |
|------|------|--------|
| +1 Grid Power | 2 | Repeatable, cap 10 |
| +2 Mech HP | 2 | Choose a mech |
| +1 Weapon Damage | 3 | Choose a weapon |
| +1 Movement | 2 | Choose a mech |
| Grappling Hook | 4 | New Science weapon: pull target 1 tile (longer range than Force Beam, no damage) |
| Cluster Shells | 4 | New Artillery weapon: 1 dmg to all 4 tiles adjacent to impact, no push |

New weapons replace the mech's existing weapon slot.

## UI & Screens

Screen flow: **Title → Battle → Shop → ... → Victory / Game Over.**

**Battle screen** (wireframe approved):
- Top-left: grid power bar (pip display)
- Top-center: turn counter + phase indicator
- Top-right: mission objective panel with checkboxes (objective + bonus)
- Center: isometric board — selected-unit tile highlight, movement range overlay, vek telegraph arrows, spawn-tile markers (▲)
- Bottom-left: selected unit card (name, HP pips, move, weapon summary)
- Bottom-center: action buttons (Move / Weapon / Repair*)
- Bottom-right: Undo, End Turn

*Repair: a mech may use its action to heal 1 HP in place (standard ItB action; included since it costs the same action slot as attacking).

**Shop screen** (wireframe approved): reputation balance, grid of purchase cards, squad status panel, Next Mission button. Hover previews; purchases that require a target (e.g., +2 HP) prompt a mech pick.

**Attack preview:** hovering a weapon target shows predicted outcomes (damage numbers, push arrows, death skulls) computed from a cloned core state.

## Assets

Generated with the Meowa `game-assets` skill (isometric pixel style, consistent palette, 64×32 diamond tile footprint):

- Terrain tiles: plain, water, mountain (+ damaged), rubble, chasm
- Buildings: standard (intact + damaged), objective structure
- Units: 3 mechs, 5 vek (incl. boss)
- Overlays: telegraph arrows, spawn marker, tile highlights (can be drawn shapes if generation quality is poor)
- Title background image
- Audio (nice-to-have, generated last): hit, push, splash, building damage, UI click, 1 battle BGM. The demo is fully functional silent.

## Testing

GUT unit tests on `src/core` only:

- Push chains: collision damage, push into water/chasm/mountain/building/map edge, flying vs ground
- Telegraph redirection when attacker or intended victim is displaced
- Spawn blocking (blocker damage, spawn retry next turn)
- Grid power accounting incl. over-damage on dying buildings
- Snapshot/restore round-trip (undo correctness)
- Objective resolution: kill-all (incl. pending spawns), survive-N, protect-structure failure path
- Shop transactions: costs, carryover, weapon replacement

View layer verified manually by running the game (Godot CLI / editor) through a full run: golden path to victory, grid-zero game over, mission-4 failure path.

## Out of Scope

Islands/world map, pilots and pilot abilities, fire/smoke/acid, grid defense RNG, time-pod side objectives, multiple squads, difficulty settings, save/load mid-run, achievements.
