# Known Bugs

Findings from a code review and a headless smoke test on Godot 4.7.2 (2026-10-11, commit `50a92df`).

**Status:** the project imports and runs 600 frames without script errors. The headless smoke test passed 11 of 17 checks. A rendered playtest is covered under [Playtest findings](#playtest-findings). No Android APK was built (no Android SDK or export templates were available).

Each bug is marked:
- **Confirmed**: reproduced by the smoke test or the playtest.
- **Code review**: found by reading the code, not reproduced.

---

## Bugs

### 1. ~~Opacity zones overwrite each other~~ (Fixed)
`scenes/objects/OpacityZones/opacity_polygon_zone.gd:125-136`

All three `OpacityPolygonZone`s in `world.tscn` use the same two materials: `Walls_TileMapLayer2` and `Ground_Upper_TileMapLayer2`. The shader holds only one polygon, so the last zone to update replaces the polygon and opacity for all of them. Each update also starts a new tween without stopping the previous one, so tweens fight over the same property.

- **Example:** the player is in zone 2 when the companion leaves zone 1. Zone 1 sets opacity back to 1.0 and restores its own polygon, so the area around the player becomes opaque again.
- **Reproduced in play:** both stand in the courtyard and the companion is tapped into the tunnel. The courtyard still records the player inside, but the shader switches to the tunnel's polygon, so the courtyard goes opaque around the player.

Fixed: the shader (`opacity_polygon.gdshader`) now holds 2 zones × 16 points (`polygon_points[32]`, `point_counts[2]`, `opacities[2]`), and each pixel fades by the faintest zone it falls in. Any number of zones can exist, but at most 2 are faded at once (enough for the player and the companion): a zone takes a free slot when it starts to fade, writes its points there, tweens only `opacities[slot]` (stopping its previous tween first) and gives the slot back once it is opaque again. If no slot is free, it takes one from a zone that is fading out; if none is, it warns and doesn't fade. A zone with more than 16 points warns and uses only the first 16. Test: `SCENARIO=court_tap_tunnel` in `test/drive.gd`.

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

### 5. Interactables share one button and one signal (Code review; locked-door part confirmed in playtest)
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
- ~~**Line 117:** the `await` timer can fire after the companion has been sent elsewhere and switch it back to FOLLOW too early.~~ Fixed: the wait is now a countdown in the IDLE state, so a new tap restarts it.

### 8. Joystick stays active after a dialogue (Code review)
`scenes/ui/joystick.gd:20-21`

If a finger is on the joystick when a dialogue opens, the joystick is hidden and never receives the release. When the dialogue closes, `joystick_active` is still `true` and the joystick is drawn at its old position.

**Fix:** reset `joystick_active` and hide the joystick sprites in the `dialogue_started` handler.

### 9. ~~Return spawn point only barely works~~ (Fixed)
`scenes/objects/door.gd:85`

The return spawn point is `door + (0, 32)`, which is inside the door's collision box (165×212 centred at `(0.5, 32)`). The player isn't stuck, because their collision shape sits lower (offset `(4, 75)`) and clears the box by about 0.3 px. Any change to either shape will trap the player.

The companion is not moved on return. It ends up near the player only because Door1 is near the companion's start position.

**Fix:** give each door a `Marker2D` for the return spawn point. Move the companion next to the player on return.

Fixed: doors name a `target_map` and a `target_spawn`, a `Marker2D` under the target map's `Spawns` node. World's `from_house_1` is at `(160, 170)`, the same spot as before, so it clears the door box by the same margin. `SceneManager` puts the companion 60 px left of the player on every map change.

---

## Playtest findings

The game was run with real rendering: Xvfb plus Mesa's software Vulkan (lavapipe), using the project's Forward Mobile renderer. A driver script played it through Godot's normal input pipeline (keyboard events, and multi-finger touch for the joystick and buttons) and the screenshots were reviewed.

**Working:**
- Keyboard and joystick movement.
- The companion follows the player.
- NPC dialogue: the button appears, the text types out, and the dialogue closes.
- The locked-door message.
- The tunnel fade: the wall above the player fades so they can be seen underneath.
- Entering and leaving the house.

**Not tested:** performance (software rendering isn't representative of phones), audio (no audio device was available), and real touch hardware.

### 10. ~~Player can walk off the map~~ (Fixed)
`scenes/world/world.tscn`, `scenes/player/player.tscn`

The map edge has no boundary colliders, so the player can walk out into the empty grey area (reached x = -1190). The camera limits are ±10000, so a grey strip already shows on the left edge of the starting view.

**Fix:** add boundary collision around the map. Set the `Camera2D` limits to the map's bounds.

Fixed: the camera limits already come from the map's tile bounds (`GameMap.get_camera_rect()`). For the boundary, `GameMap` has a `block_map_edges` export, switched on in `base_outdoor_grass.tscn` (World and Town). When the map enters the tree, `build_edge_walls()` adds an `EdgeWalls` `StaticBody2D` on both levels: every empty cell next to a ground cell (diagonals too) on the `Ground_TileMapLayer` grid collides, with each row's adjacent cells merged into one rectangle (72 shapes in World). This follows World's irregular outline, not just its bounding box. Because it is built before the navigation mesh bakes, the mesh also stops at the edge, so a tap outside the map sends the companion to the nearest ground. Edge exits still work: their strips lie on ground cells. Interiors are closed by their wall tiles and leave the export off.

### 11. House interior is a placeholder (Partly fixed)
`scenes/maps/House1Interior.tscn`

- ~~`Ground_TileMapLayer` and `Walls_TileMapLayer` have no tileset or tiles. The interior renders as an empty grey screen, and nothing blocks the player.~~ Fixed: a furnished 20×13 room built from `resources/tilesets/interior.tres` (wood floor, wallpaper, bed, shelves, table), with wall and furniture collision and a navigation mesh.
- ~~The `ExitDoor` sprite override (`region_rect = Rect2(96, 0, 32, 128)`) shows a chest instead of a door.~~ Fixed: the override is removed; the exit door uses the default door sprite.
- The exit door uses `interaction_type = "door_enter"`, so its button says "Belép" (Enter) instead of an exit label.

### 12. Companion's idle animations are hidden behind the player (Confirmed)
`scenes/companion/companion.gd:5`

`min_distance = 60`, but the player sprite is about 145 px wide. When the companion stops, it sits behind the player, so the idle2 and sleep animations can barely be seen.

**Fix:** raise `min_distance` (about 100–120), or stop beside the player rather than at their centre.

### 13. UI text is too small or misplaced (Confirmed)
`scenes/ui/screen_ui.tscn`

- The interaction button's label is about 20 px tall on screen (`font_size = 100` × button scale `0.2`) and sits off-centre at the button's top-left.
- Dialogue text is small inside a large, mostly empty panel.
- The locked-door message has an empty speaker name, which leaves a blank line.

**Fix:** centre the label, scale fonts for a 1080p screen, and hide `NameLabel` when the speaker name is empty.

### 14. Visual polish issues (Confirmed)

- ~~The player sprite has a white halo from the white-to-transparent shader (see Code quality).~~ Fixed: the player uses a sprite sheet with real transparency and no shader.
- The fox is very small next to the player.
- ~~The NPC uses the Godot icon as a placeholder sprite, and the player walks through it.~~ Fixed: the NPC has a sprite sheet and a collision shape at its feet.

### 15. Opacity zones with an empty entrance (Confirmed)
`scenes/world/world.tscn`

`EnterZone2` has no polygon points in `OpacityPolygonZone` and `OpacityPolygonZone3`, so those zones have only one working entrance. Delete the empty nodes or draw the polygons.

### 16. ~~Companion's spot marker appears on walls~~ (Fixed)
`scenes/companion/companion.gd:207`, `scenes/companion/companion.gd:333`

When you tap a wall, the spot marker is drawn on the wall itself. The companion can't stand there, so it walks to the nearest point it can reach while the marker stays on the wall. `send_to_position` stores the raw tap position, and the marker is drawn at that position.

**Fix:** when the companion is sent, snap the destination to the nearest reachable point next to where the user tapped. Use the end of the companion's navigation path to the tap (`map_get_path` on its own level). Don't use `map_get_closest_point`: it ignores the level, and with two overlapping navmeshes it can pick a point on the other level. Then store that point as `click_target_pos`, so the marker and the arrival check both use it. If there is no navmesh (no path), keep the tap position.

Fixed: `send_to_position()` plans the crossings first, then `get_reachable_point()` takes the end of the navigation path to the tap on the level where the route ends: from the companion on its own level, or from the last crossing's far side on that crossing's level. That point becomes `click_target_pos`, so the marker, the path and the arrival check all use it. Tapping the bakery wall in Town puts the target on the road in front of it (tap y 60 → 196), and a tap on open ground is unchanged. All `test/drive.gd` scenarios still pass.

### 17. Companion can't avoid moving NPCs (Code review)
`scripts/navigation/collision_nav_region.gd:39`, `scenes/companion/companion.gd`

The navmesh is baked only from static colliders (`PARSED_GEOMETRY_STATIC_COLLIDERS`), so NPCs, which are `CharacterBody2D`, are not cut out of it. The companion plans its path straight through an NPC and relies on `move_and_slide()` to slide around its collision shape. This works today because the only NPC stands still: the companion follows the player past it without getting stuck. Once NPCs move, the companion can't steer around them, and it can get pushed or stuck when an NPC walks into its path.

**Fix:** when NPCs start moving, use navigation avoidance: a `NavigationAgent2D` with `avoidance_enabled` on the companion, and a `NavigationObstacle2D` (or an agent of their own) on the NPCs. Don't rebake the navmesh around moving NPCs.

### 18. ~~Player's head is drawn over the roof edge~~ (Fixed)
`scenes/world/world.tscn` (`OpacityPolygonZone3`)

The plateau on top of the mountain has a "roof" zone that fades when the player or companion goes under it. Walking north toward it, the player stays on level 1 until their feet reach the entry strip at y −600 (they switch at y −578). Before that (feet at y −531 and −558) the player is drawn after the roof's tile layer, so their head covers the plateau's edge as if they were on the same level. The head should go under the roof.

Fixed: the zone's entrance moved 100 px south (`ShaderZone` bottom edge y 300, `EnterZone1` y 300..310). The player now switches to level 2 at feet y −500 and back to level 1 at −469 on the way out; screenshots show the head just below the edge before the switch and under the faded roof after it.

### 19. ~~Companion stops at a zone's edge when sent out of it~~ (Fixed)
`scenes/companion/companion.gd` (`handle_goto_logic`, `track_level_changes`)

Both stand under the roof (bug 18) and the player taps the ground in front of the tunnel. The companion leaves the zone, walks about 150 px and stops at (2039, −514) as if it had arrived. The same happens whenever the player stands in a zone and sends the companion out of it.

- The tap starts the companion on level 2, where the path is 1310 px long.
- Once it crosses to level 1, the real path (round by the stairs) is 2606 px.
- The stuck check measures progress against the best remaining length so far (`goto_best_distance`, still 1310 from level 2). Nothing beats it, so after `GOTO_STUCK_TIME` (1 s) the companion gives up.

Fixed: `track_level_changes()` now restarts the stuck check (`goto_best_distance`, `goto_stuck_timer`) when the companion changes level. Test: `SCENARIO=roof_tap` in `test/drive.gd`.

**Note:** a tap target on another level used to be reachable only when the current level's path happened to cross an entry strip. Taps now plan across levels (bug 20).

### 20. ~~Companion goes round the mountain instead of through the tunnel~~ (Fixed)
`scenes/companion/companion.gd` (`send_to_position`, `handle_goto_logic`)

The companion stands south of the tunnel and the player taps the ground north of it. The companion walks west round the whole mountain instead of through the tunnel, and after its wait it comes back round the mountain too.

- Both ends are on level 1, and the tunnel is level 2. Each level has its own navigation mesh, so the companion only sees the level-1 route.
- Follow mode crosses levels through the player's breadcrumbs, but a tap had nothing like it.

Fixed: on a tap, `plan_crossings()` searches for the shortest route across levels (Dijkstra). The nodes are the companion, the target and both sides of every zone entry strip (`portals` in `opacity_polygon_zone.gd`), and the costs come from the navigation mesh of each level. The companion then walks those crossings in order (`goto_crossings`), the same way follow mode walks the player's. When its wait ends with no breadcrumbs left, it plans the route back to the player the same way. If the target is on the companion's level, it stays the target level as before; if not, the route may end on another level. A plan takes under 1 ms. Test: `SCENARIO=tap_through_tunnel` in `test/drive.gd`.

### 21. Open door shows the wall or grass behind it (Reported, cosmetic)
`scenes/objects/door.gd` (`open_door`), `scenes/objects/door.tscn`

When the player enters or leaves the house, the door switches to its open frame for a moment before the map changes. The doorway in that frame is transparent, so it shows whatever is drawn behind the door, such as the wall or the grass ground. It should look like an opening into the other side.

**Fix:** draw a dark backdrop behind the open doorway, either black or a hint of the other side (interior floor seen from outside, grass seen from inside). For example, add a black sprite or `Polygon2D` under the door sprite, shaped like the doorway and shown only while `is_open` is true.

### 22. ~~Collision shapes in the room are too big~~ (Fixed)
`resources/tilesets/interior.tres`, `scenes/maps/House1Interior.tscn`

The player stops too far from the plant, the floor lamp and the walls, so she can't walk up to them. Their collision is larger than the part that touches the floor.

Fixed: the side walls collide only on their 4 px outline, the bottom wall on its 5 px edge (the corners are L-shaped), the lamp on its base and the plant on the lower half of its pot. The player now walks up to the drawn wall edge.

### 23. ~~Player is drawn behind the table and the bed when standing beside them~~ (Fixed)
`resources/tilesets/interior.tres` (`y_sort_origin` of the furniture tiles)

When the player stands next to the table or the bed, she is drawn behind the furniture, as if she were smaller than it and partly under it. The furniture tiles Y-sort from the bottom edge of their footprint, so the player stays behind them until her feet pass that edge. That is right for tall furniture (the bookshelf, the chair's backrest), but the table and the bed are lower than an adult woman, so the player should be drawn in front of them.

Fixed: the table sorts from the back edge of its top (`y_sort_origin` −27) and the bed from just below its headboard (−15). Tall furniture still sorts from its bottom edge. Beside them the player is drawn in front; behind the table's edge or the headboard she is drawn behind them (bug 24). The other table and bed tiles in `interior.tres` (not placed in any map yet) still sort from their bottom edge.

### 24. ~~Player can hide behind the table and the chairs~~ (Fixed)
`resources/tilesets/interior.tres` (table and chair collision)

- **Table:** the collision doesn't reach the table's back edge, so the player can walk behind its top and disappear under it. The collision's upper edge should reach the table's back edge, so she stops at the edge or at most a few pixels below it.
- **Chairs:** standing just above a chair, the backrest covers the player up to her head, so the chair looks as tall as she is. Extend the chair's collision upward so she stops further from the backrest.

Fixed: the table's collision reaches its back edge, so she stops just behind it instead of on the tabletop, and the chairs' collision starts at the top of the seat. Standing behind a chair, the backrest now covers only her legs. The right chair is drawn 4 px further right (`texture_origin`), so its seat no longer overlaps the table. The bed collides from the pillows down, so she can walk behind the headboard, which covers her legs.

---

## Code quality

- **Name checks:** `body.name == "Player"` / `"Companion"` is used in 6 files. It breaks when a node is renamed or a second instance is added. Use groups (`is_in_group("player")`) or the physics layers instead.
- **Duplicated layer-switching code:** `clim_zone.gd` and `opacity_polygon_zone.gd:set_character_to_underground` both switch layers by setting collision masks and z-index by hand. Move this into one shared helper. `ClimZone` also flips state on every enter, so stepping in and back out leaves the character on the wrong layer. It isn't placed in any scene yet.
- **White-to-transparent shader:** `game.gdshader` makes near-white pixels transparent, and it's still applied to the companion (no longer to the player). White highlights and eyes in those sprites become see-through. Export the source images as PNGs with real transparency instead.
- ~~**NPC has no collision shape:** the NPC body has no `CollisionShape2D` (only its `InteractionArea` does). The player walks through it, and Godot shows a configuration warning.~~ Fixed: the NPC has a capsule at its feet.
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
