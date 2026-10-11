# Known Bugs

Findings from a code review and a headless smoke test on Godot 4.7.2 (2026-10-11, commit `50a92df`).

**Status:** the project imports and runs 600 frames without script errors. The smoke test passed 11 of 17 checks. Headless mode doesn't render, so shaders and visuals were not tested. No Android APK was built (no Android SDK or export templates were available).

Each bug is marked:
- **Confirmed**: reproduced by the smoke test.
- **Code review**: found by reading the code, not reproduced.

---

## Bugs

### 1. Opacity zones overwrite each other (Confirmed)
`scenes/objects/OpacityZones/opacity_polygon_zone.gd:125-136`

All three `OpacityPolygonZone`s in `world.tscn` use the same two materials: `Walls_TileMapLayer2` and `Ground_Upper_TileMapLayer2`. The shader holds only one polygon, so the last zone to update replaces the polygon and opacity for all of them. Each update also starts a new tween without stopping the previous one, so tweens fight over the same property.

- **Example:** the player is in zone 2 when the companion leaves zone 1. Zone 1 sets opacity back to 1.0 and restores its own polygon, so the area around the player becomes opaque again.
- **Fix:** keep one manager that tracks every active zone and sends all their polygons to the shader, or give each zone its own material. Stop the previous tween before starting a new one. Clamp `point_count` to 8, the size of the shader's polygon array.

### 2. Joystick reacts to every finger (Confirmed)
`scenes/ui/joystick.gd:28-58`

The code never checks `event.index`, so it can't tell fingers apart:
- Lifting any other finger, for example after tapping the interaction button, stops the player while the left thumb is still down.
- Dragging any other finger steers the player.

**Fix:** store the finger index when the joystick activates and ignore events from other fingers.

### 3. Dialogue can't be advanced on PC (Confirmed)
`scenes/ui/dialogue_box.gd:54`

The dialogue box only handles `InputEventScreenTouch`. `TouchScreenButton` also only reacts to touch. `input_devices/pointing/emulate_touch_from_mouse` is off, and there is no keyboard action for "interact" or "next line". On desktop, once a dialogue opens, the player stays frozen. This defeats the keyboard fallback in `player.gd:27`.

**Fix:** add `interact` and `dialogue_next` input actions. Accept them alongside touch, or turn on touch emulation from the mouse.

### 4. Interaction button calls a missing method (Confirmed)
`scenes/ui/screen_ui.tscn:146`

`InteractionButton.pressed` is connected to `ScreenUI._on_interaction_button_pressed`. `screen_ui.gd` is empty, so every press logs an error. The real handling is in `interaction_button.gd`.

**Fix:** delete the connection.

### 5. Interactables share one button and one signal (Code review)
`scenes/npc/npc.gd`, `scenes/objects/door.gd`, `scripts/global/signal_bus.gd`

`interaction_pressed` goes to every listener, and each NPC or door shows and hides the button on its own. Problems:
- When the player is next to both an NPC and a door, one press triggers both.
- Leaving one of them hides the button while the player is still next to the other.
- After the locked door's "Zárva van..." message, the door never shows the button again (`door.gd:53-56`). The player has to walk away and come back. The NPC handles this case correctly in `_on_dialogue_finished`.

**Fix:** keep a "current interactable" tracker on the player or in `GameManager`. Only the tracked object handles the press and controls the button.

### 6. Locked doors can never be opened (Code review)
`scenes/objects/door.gd:74-78`

`check_player_has_key()` always returns `false`. The commented-out code refers to `GameManager.player_inventory`, which doesn't exist. The inventory is `PlayerData.inventory`.

**Fix:** `return PlayerData.inventory.has(required_key_name)`.

### 7. Companion idle logic errors (Code review)
`scenes/companion/companion.gd`

- **Line 84:** the code checks for `"idle"`, but the animation is named `"idle1"`. As a result, `play("idle1")` and `speed_scale` are set again every physics frame.
- **Line 69:** the early `return` during the idle2 fidget skips `move_and_slide()`.
- **Line 117:** the `await` timer can fire after the companion has been sent elsewhere and switch it back to FOLLOW too early. `send_to_position` isn't called anywhere yet, so this is latent.

### 8. Joystick stays active after a dialogue (Code review)
`scenes/ui/joystick.gd:20-21`

If a finger is on the joystick when a dialogue opens, the joystick is hidden and never receives the release. When the dialogue closes, `joystick_active` is still `true` and the joystick is drawn at its old position.

**Fix:** reset `joystick_active` and hide the joystick sprites in the `dialogue_started` handler.

### 9. Return spawn point only barely works (Confirmed, works today)
`scenes/objects/door.gd:85`

The return spawn point is `door + (0, 32)`, which is inside the door's collision box (165×212 centred at `(0.5, 32)`). The player isn't stuck, because their collision shape sits lower (offset `(4, 75)`) and clears the box by about 0.3 px. Any change to either shape will trap the player.

The companion is not moved on return. It ends up near the player only because Door1 is near the companion's start position.

**Fix:** give each door a `Marker2D` for the return spawn point. Move the companion next to the player on return.

---

## Code quality

- **Name checks:** `body.name == "Player"` / `"Companion"` is used in 6 files. It breaks when a node is renamed or a second instance is added. Use groups (`is_in_group("player")`) or the physics layers instead.
- **Duplicated layer-switching code:** `clim_zone.gd` and `opacity_polygon_zone.gd:set_character_to_underground` both switch layers by setting collision masks and z-index by hand. Move this into one shared helper. `ClimZone` also flips state on every enter, so stepping in and back out leaves the character on the wrong layer. It isn't placed in any scene yet.
- **White-to-transparent shader:** `game.gdshader` makes near-white pixels transparent, and it's applied to the player and companion. White highlights and eyes in those sprites become see-through. Export the source images as PNGs with real transparency instead.
- **NPC has no collision shape:** the NPC body has no `CollisionShape2D` (only its `InteractionArea` does). The player walks through it, and Godot shows a configuration warning.
- **Player collision layer differs between scenes:** layer 4 in `world.tscn`, layer 1 (the default) in `House1Interior.tscn`.

## Cleanup

- **Unused files:**
  - `scenes/world/TransparentLayer.gdshader`
  - `OpacitySquareZone.tscn` and `opacity_square_zone.gd`. The square zone also ignores the shape's position and scale when it computes its bounds.
  - `ClimZone.tscn`
- **Leftover debug output:** `print("npc")` in `npc.gd:28`, `print("gomb")` in `interaction_button.gd:18`, and the `print` calls in `companion.gd`.
- **Repo contents:**
  - A 1.4 MB `.unitypackage` is committed; Godot doesn't use it.
  - `Scene Overview.png` (820 KB) is committed twice.
  - Binary assets aren't stored with Git LFS.
- **Small mismatches:**
  - `door.gd:70`: the comment says the wait is 0.3 s, but the code waits 0.1 s.
  - `door.gd:10-11`: `FRAME_CLOSED` and `FRAME_OPEN` are named like constants but declared as `var`.
  - `project.godot`: `ui_attack` has no inputs bound.
  - `project.godot`: the Jolt setting only applies to 3D physics, so it has no effect in this 2D project.
