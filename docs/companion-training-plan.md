# Plan: companion stay training and send range

Two changes to how the companion is sent with a tap. Both can be trained:

1. **Stay training.** The companion waits longer at a tapped spot as it gets trained.
2. **Send range.** The companion can only go up to a maximum distance from the player. A tap farther away sends it only as far as the range allows. The range follows the player as they move, and training makes it bigger.

## Where things stand

- `companion.gd` already has an exported `stay_duration` (default 2 s). `send_to_position()` walks the companion to the tapped spot, it waits `stay_duration`, then goes back to following.
- The grey countdown line above the companion already scales to `stay_duration`, so it needs no changes for training.
- `PlayerData` has `companion_obedience` (starts at 1) and `companion_unlocked_skills`, and `SignalBus` has `companion_obedience_changed`. None of them are used yet.
- There is no save system, so `PlayerData` resets each time the game starts.
- Bug #16 in `BUGS.md`: the tap position is used as the destination even when it's inside a wall. The range clamp below depends on fixing it, so it comes first.

## 1. Fix bug #16 first: snap the destination to a reachable point

In `send_to_position()`, replace the tapped position with the end of the companion's navigation path to it, on its own level (`map_get_path(..., get_navigation_layers())`). Store that as `click_target_pos`, so the marker, the walk and the arrival check all use the same point. If there's no navmesh (no path), keep the tapped position.

Branch: `fix/companion-target-snap`.

## 2. Send range

**Rule:** the companion's destination must stay within the send range of the player's feet, measured as a straight line. The range is checked continuously, not only at the tap: when the player moves, the destination moves with them.

**Destination while walking:** the companion keeps the original tap point `T`. Each time it recalculates its path (every 0.25 s, as it does today), it works out its destination from the player's current feet position `P` and the current range `R`:

1. If `T` is within `R` of `P`, the destination is `T`.
2. Otherwise it's the point on the edge of the range circle, toward the tap: `P + (T - P).normalized() * R`.
3. That point is snapped to the nearest reachable point (section 1).

**What this means in play:**
- The marker is always drawn at the current destination, so it slides along as the player moves. If the player walks back toward the tap, the destination moves back toward `T`, up to `T` itself.
- While walking, the companion chases the moving destination. The player is faster (200 vs 160), but the destination itself never leaves the range.
- **During the wait:** if the player moves but the companion is still within range, it keeps waiting. If the player moves out of range, the companion cancels the wait at once and goes back to following them. The countdown line disappears, and the wait isn't resumed if the player comes back.
- **Tolerance:** "out of range" during the wait means farther than `R` plus a small tolerance (placeholder 40 px). The snap can leave the destination slightly past `R`, for example when the circle edge is inside a wall. Without the tolerance, the companion would give up the moment it arrived.

**Range values:** the range comes from `PlayerData` and is trained like stay time (see section 3). Placeholder base value: 500 px. At the default zoom, the screen is 2400 px wide, so half the screen is 1200 px. That means a tap near the screen edge gets clamped at the starting level. The companion reads the range every time it uses it, so training takes effect immediately, even mid-walk.

**Why a straight line rather than walking distance:** it's a simple circle around the player that's easy to understand and could be drawn later. Walking distance would make the same tap behave differently depending on walls between the player and the target.

Branch: `feat/companion-send-range`.

## 3. Training

Both skills work the same way.

**Data in `PlayerData`:**
- `companion_stay_level: int = 0` and `companion_range_level: int = 0`.
- Level tables (placeholders to tune):
  - `COMPANION_STAY_DURATIONS = [2.0, 3.0, 5.0, 8.0, 12.0]` (seconds)
  - `COMPANION_SEND_RANGES = [500.0, 650.0, 800.0, 1000.0, 1200.0]` (pixels)
- `get_companion_stay_duration() -> float` and `get_companion_send_range() -> float` return the value for the current level.
- `train_companion_stay()` and `train_companion_range()` raise the level by one, up to the last level. Each emits `SignalBus.companion_skill_changed(skill, new_level)` (a new signal), with `skill` set to `"stay"` or `"range"`.

**Companion:**
- **Stay:** when the companion arrives at a tapped spot, it reads `PlayerData.get_companion_stay_duration()` into `stay_duration`. A new stay level therefore applies from the next wait, and a wait already counting down isn't changed.
- **Range:** read live from `PlayerData.get_companion_send_range()` every time it's used (see section 2).
- **No separate settings on the companion:** `PlayerData` is an autoload, so it's always available. The exported `stay_duration` is replaced by the `PlayerData` lookup. Tests set the levels in `PlayerData` directly.

**How training is earned** is not decided yet (see open questions). Until then, the two `train_*` functions are the only places to call from whatever gets chosen.

Branch: `feat/companion-training`.

## 4. Tests

Add these to `test/tap_test.tscn`, through the real input pipeline:

- **Tap inside range:** the destination is the tapped point, unchanged.
- **Tap beyond range:** the destination is on the range circle, toward the tap (within the snap allowance), and the marker is drawn there.
- **Tap on a wall:** the destination and the marker are on reachable ground next to the wall (bug #16).
- **Player moves while the companion walks:** the destination and the marker move with the player and stay within range. When the player walks back toward the tap, the destination returns to the tap point.
- **Player moves within range during the wait:** the companion keeps waiting until the countdown ends.
- **Player leaves the range during the wait:** the companion cancels the wait in the same moment and follows. The countdown line disappears.
- **Stay training:** at each stay level, the measured wait matches the table, and the countdown line starts full and runs out at the same time.
- **Range training:** at each range level, a far tap is clamped to that level's range. Raising the level mid-walk moves the destination out right away.

Also re-run the level-following scenarios in `test/drive.tscn`.

## Order of work

1. `fix/companion-target-snap`, for bug #16.
2. `feat/companion-send-range`.
3. `feat/companion-training`.

Each branch is made from `dev` and merged back with `--no-ff`, as in `CLAUDE.md`.

## Open questions

- **How is training earned?** Options: a trainer NPC, a mini-game, or experience from use (e.g. completed stays train stay, long sends train range). Should the levels come from the existing `companion_obedience` stat, or be separate? This plan assumes separate levels, so obedience stays free for something broader.
- **Tolerance during the wait:** 40 px is a placeholder. A larger value makes the companion less twitchy when the player stands near the edge of the range.
- **Show the range?** For example, a faint circle while tapping, or a brief flash when a tap gets clamped.
- **Values:** the stay durations and the ranges are placeholders to tune in playtesting.
- **Saving:** training is lost on restart until a save system exists.
- **Taps across levels:** tapping a spot under a bridge while the companion is on top still isn't routed through the entrance. That's out of scope here.
