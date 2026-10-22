# Plan: world and room map structure

How to structure the world map, its areas and the room interiors so that:

- the large world is split into smaller areas, with a scene change between them,
- there can be many interiors, including buildings with several rooms,
- several tile sets are used, and many maps share the same tile set.

## Where things stand

Updated 2026-10-22. Steps 1–4 of the [order of work](#order-of-work) are done; steps 5–7 aren't started.

- **Done:** the tile sets are shared `.tres` files. `main.tscn` stays loaded and `SceneManager` swaps the maps inside it, so the Player, Companion and UI survive a map change. Every map inherits from a base scene with the `GameMap` script and named spawn points, and doors use `target_map` + `target_spawn`. Camera limits come from the map's tiles. Edge exits (`map_exit.tscn`) connect World and the new Town area. Outdoor maps are closed off by invisible edge walls (`GameMap.block_map_edges`).
- **Maps:** `world.tscn` (the first outdoor area, still in `scenes/world/`), `scenes/maps/world/town.tscn` (east of World, built from the city pack) and `House1Interior.tscn`, a furnished room on `base_interior_wood.tscn`.
- **Not done:** multi-room interiors (step 5), saved map state (step 6; `map_id` is exported but nothing reads it yet), and the folder moves and renames from [Project folders](#8-project-folders) (step 7): `world.tscn` is still in `scenes/world/`, and `House1Interior.tscn`, `ClimZone.tscn` and `OpacityZones/` aren't snake_case yet.
- **Example names:** `village`, `forest_01`, `inn` and `village_house_01` in the sections below are illustrations of the layout, not maps that exist. The real maps are listed above.
- **Before this plan:** every map had its own Player, Companion and UI and was loaded with `change_scene_to_file()`. Going back out of a house used the `world_spawn_position` workaround. The tile sets lived inside `world.tscn`, and the camera limits were hard-coded.

## 1. A root scene that stays loaded

`main.tscn` becomes `run/main_scene` and is the only scene the game ever runs:

```
Main (Node)                      main.gd
├── MapContainer (Node2D)        ← the current map is loaded in here
├── Player                       ← stays alive across map changes
├── Companion
├── ScreenUI (CanvasLayer)
└── Transition (CanvasLayer)     ← fade to black while maps swap
```

A new `SceneManager` autoload changes maps:

1. Fade out.
2. Free the old map.
3. Create the new map inside `MapContainer`.
4. Move the Player and Companion into the new map's `YSort_Entities` with `reparent()`, so they still Y-sort against NPCs and doors.
5. Put them on the target spawn point and set the camera limits.
6. Fade in.

The companion finds the player with `$"../Player"`. That keeps working as long as both are moved into the same parent together.

The tap-to-send handler in `world.gd` moves to `main.gd`.

## 2. Each tile set gets its own file

Each TileSet is saved as a `.tres` file in `resources/tilesets/`. Every map that uses one shares the same atlas, collisions and terrains, so a fix to a tile reaches every map.

Set up the physics layers inside the `.tres` (walls on `Lenti_Szint`, upper level on `Fenti_Szint`) so collision behaves the same in every map.

## 3. Base map scenes, built in layers

Every map's root gets one shared script, `scripts/maps/game_map.gd`:

```gdscript
class_name GameMap extends Node2D

@export var map_id: StringName          # key for saved state, e.g. &"village_house_01"
@export var music: AudioStream         # not added yet: waits until there is audio
@export var block_map_edges: bool       # outdoor maps: invisible walls around the ground tiles

@onready var entities: Node2D = $YSort_Entities

func get_spawn(spawn_id: StringName) -> Marker2D:
	return $Spawns.get_node(NodePath(spawn_id))

func get_camera_rect() -> Rect2:
	# Built from the TileMapLayers, like CollisionNavRegion._get_map_bounds
	...
```

`get_camera_rect()` replaces the hard-coded camera limits.

With `block_map_edges` on (set in `base_outdoor_grass.tscn`), `GameMap` builds an `EdgeWalls` `StaticBody2D` in `_enter_tree()`, before the navigation mesh is baked: every empty cell next to a ground tile (diagonals included) collides on both levels, so the Player and Companion stop at the edge of the map and the navigation mesh doesn't reach past it. Interiors leave it off, since their wall tiles close them.

The map scenes are built with Godot's inherited scenes (**Scene → New Inherited Scene**):

```
base_map.tscn                  GameMap script, MAP_LAYERS (no tile set), YSort_Entities,
│                              Spawns, Doors, NAVIGATION — no Player/Companion/UI
├── base_outdoor_grass.tscn    sets the outdoor tile sets on the layers, adds the Fenti layers + Navigation_Layer2
│   ├── forest_01.tscn
│   └── village.tscn
└── base_interior_wood.tscn    sets interior.tres, one level only
    ├── village_house_01.tscn
    └── inn.tscn
```

A change to a base scene reaches every map built from it. Stop at two levels of inheritance: deeper chains get fragile when a base node is renamed.

## 4. Doors name a target map and a spawn point

The door's export changes from a target scene path to a target map plus a spawn name:

```gdscript
@export_file("*.tscn") var target_map: String
@export var target_spawn: StringName = &"default"
```

Each map has a `Spawns` node with `Marker2D` children named after where you arrive from, such as `from_village_door` or `from_forest_east`. The door calls `SceneManager.change_map(target_map, target_spawn)`. This replaces the `world_spawn_position` / `coming_back_from_interior` workaround, and every door can return to the right place in any direction.

## 5. Splitting the large world into areas

Each area is its own map, for example `village.tscn` and `forest_01.tscn`. Neighbouring areas are connected with a new `map_exit.tscn`: an `Area2D` strip along the map edge that changes the map as soon as the player walks in, with no button press. It uses the same `target_map` and `target_spawn` exports as the door.

- Put the arrival spawn slightly inside the target area's edge, away from its exit strip. Otherwise the player lands on the exit and bounces straight back.
- Line up the shared edges between neighbouring areas, so a road that leaves forest_01 at y=640 enters village at y=640.
- Start with separate areas and a fade. Seamless streaming, where neighbouring areas load in the background, can be added later with `ResourceLoader.load_threaded_request` without changing this layout.

## 6. Interiors with several rooms

One scene per building, with each room as a group of nodes inside it:

```
inn.tscn (base_interior_wood)
├── MAP_LAYERS                ← all rooms painted on one set of layers, spaced apart
├── Rooms
│   ├── Taproom  (Area2D + CameraBounds)
│   ├── Kitchen
│   └── Upstairs
├── Spawns  (from_village, taproom_from_kitchen, kitchen_from_taproom, …)
└── Doors   (internal doors: target_map empty → teleport to target_spawn inside the same map)
```

- **Internal doors:** when `target_map` is empty and `target_spawn` is set, the door teleports to `target_spawn` inside the current map. The move is instant and needs no loading. A door with neither set stays a plain door that only opens: `door.gd` already treats an empty `target_map` as "open, don't change map". So `target_spawn`'s default changes from `&"default"` to `&""` here; every existing door sets it explicitly, and `GameMap.get_spawn()` already falls back to the first spawn point.
- **Camera:** when the player enters a room's `Area2D`, the camera limits are set to that room's bounds, so the other rooms painted beside it stay hidden.
- **Navigation:** everything is on one navigation mesh, so the companion can follow through internal doors.

Split a building into separate scenes only when parts of it are large or use a different tile set, such as an inn's cellar or the floors of a dungeon.

## 7. Saving map state

Freed maps forget everything: opened doors, picked-up items, NPC progress. That state is kept in an autoload keyed by `map_id`, for example `GameManager.map_state[&"inn"] = {"opened_doors": [...]}`. Each `GameMap` reads it when it loads and writes it back before it's freed.

## 8. Project folders

```
assets/                         raw third-party packs, unmodified
resources/tilesets/             *.tres tile sets (shared)
scenes/
├── main/main.tscn, main.gd     root scene (run/main_scene)
├── maps/
│   ├── _base/                  base_map, base_outdoor_*, base_interior_*
│   ├── world/                  village.tscn, forest_01.tscn, …
│   └── interiors/              village_house_01.tscn, inn.tscn, …
├── objects/                    door, map_exit, clim_zone, opacity zones
├── player/ companion/ npc/ ui/
scripts/
├── global/                     signal_bus, game_manager, player_data, scene_manager (new)
├── maps/game_map.gd
├── navigation/
└── tools/                      editor-time generators (build_outdoor_props_tileset)
```

File names use snake_case (Godot's convention): `House1Interior.tscn` becomes `house_1_interior.tscn`.

The moves still to do:

| From | To |
|---|---|
| `scenes/world/world.tscn` | `scenes/maps/world/world.tscn` |
| `scenes/world/Scene Overview.png` | `scenes/maps/world/world_overview.png` (the hidden reference `Sprite2D` in `world.tscn` uses it) |
| `scenes/maps/House1Interior.tscn` | `scenes/maps/interiors/house_1_interior.tscn` |
| `scenes/objects/ClimZone.tscn` | `scenes/objects/clim_zone.tscn` |
| `scenes/objects/OpacityZones/` | `scenes/objects/opacity_zones/` (`OpacityPolygonZone.tscn` → `opacity_polygon_zone.tscn`, `OpacitySquareZone.tscn` → `opacity_square_zone.tscn`) |

`BUGS.md` → Cleanup lists `TransparentLayer.gdshader`, `ClimZone.tscn` and the square opacity zone as unused. Check that with `grep` first; a file nothing uses is deleted instead of moved. `scenes/world/` is removed once it's empty.

Sprite sheets next to their scenes (`scenes/player/character.png` and the like) stay where they are, and so do the third-party pack folders' own names under `assets/`.

### Moving files without the editor

The moves are done here in the container with git and the headless Godot from the `run-game` skill, not in the Godot editor:

1. `git mv` each file together with its `.uid` and `.import` sidecar, so the file keeps its UID.
2. Rewrite every `res://` path to the moved files in `*.tscn`, `*.tres`, `*.gd`, `project.godot`, `test/`, `.claude/skills/run-game/` and the docs (`grep -rn` the old path first). Scenes reference by `uid://` too, but the path in each `ext_resource` must still be right, or Godot warns and falls back to the UID.
3. Delete `.godot/` and re-import headless (`timeout 300 "$G" --headless --path . --import`, as in the run-game skill). The import must finish with no "missing dependencies" or "invalid UID" errors.
4. Run the run-game smoke tests (`drive.gd` scenarios, `exit_smoke.gd`, `house_smoke.gd`) and check World → House1 → World and World ↔ Town still work.

One move per commit on the branch keeps a broken reference easy to bisect.

## Order of work

One branch per step:

1. ✅ **`refactor/shared-tilesets`**: save the TileSets as `.tres` files. Nothing visible changes.
2. ✅ **`refactor/persistent-main-scene`**: add `main.tscn` and `SceneManager`; move Player, Companion, ScreenUI and the tap-to-send handler into Main. The biggest step.
3. ✅ **`refactor/game-map-base`**: add `GameMap`, the base scenes and spawn points. Switch the door to `target_map` + `target_spawn` and remove the `world_spawn_position` workaround. The uncommitted `Room.tscn` from `feat/room-scene` becomes `base_interior_wood.tscn` here.
   As built: the interior base is `base_interior_wood.tscn` with one tile set, `interior.tres`, made from `assets/InteriorTilesLITE.png` (floors, wallpapers, wall-top outlines and every furniture sprite as a multi-cell tile with a footprint collision). It adds a `Rugs_TileMapLayer` and a Y-sorted `Furniture_TileMapLayer` inside `YSort_Entities`, so the characters walk behind and in front of furniture. Maps smaller than the screen are centred by the camera. `Doors` sits inside `YSort_Entities` so doors Y-sort with the characters, and `base_map` keeps `MAP_LAYERS` empty: each base adds its layers in draw order. The `music` export waits until there is audio. Camera limits come from `GameMap.get_camera_rect()`; a map with no tiles has no limits.
4. ✅ **`feat/map-exit`**: edge exits between areas, then split World into areas.
   As built: World is too small to split, so a second area, `town.tscn`, was added east of it instead. `map_exit.tscn` is an `Area2D` strip (exports `target_map`, `target_spawn`, `size`) that changes the map when the player walks in; World's east edge and Town's west edge are joined this way, with the arrival spawns 200 px inside the edges. Town is built on `base_outdoor_grass.tscn`: grass and a cobblestone road from the ground tile set, and the city pack's buildings and street objects placed as `prop.tscn` instances. A prop is a `StaticBody2D` whose origin is the image's bottom edge, so it Y-sorts with the characters, with a collision footprint at its base on `Lenti_Szint`, so the navigation mesh avoids it. The buildings have no interiors yet.
   Later (`feat/outdoor-props-tileset`): the small street objects moved into a tile set, `outdoor_props.tres`, like the interior furniture. `scripts/tools/build_outdoor_props_tileset.gd` packs the pack's object images into `assets/outdoor_props.png` (16 px cells) and writes each object as a multi-cell tile, with its `y_sort_origin` at the image's bottom and its footprint collision there. `base_outdoor_grass.tscn` has a Y-sorted `Props_TileMapLayer` inside `YSort_Entities` for painting them. Only the buildings are still `prop.tscn` instances, since they are large one-off images that will get doors and interiors. To add an object, append it to the end of the script's list (the order sets the atlas coordinates), run the script and reimport.
   Later (`fix/map-edge-bounds`): `GameMap.block_map_edges` builds invisible walls around the ground tiles of outdoor maps (see [section 3](#3-base-map-scenes-built-in-layers)).
5. **`feat/multi-room-interiors`**: room camera bounds and internal teleport doors (see the `target_spawn` default in [section 6](#6-interiors-with-several-rooms)).
6. **`feat/map-state`**: per-map saved state.
7. **`refactor/project-folders`**: the folder moves and snake_case renames from [Project folders](#8-project-folders), done in the container as described in [Moving files without the editor](#moving-files-without-the-editor). It touches no behaviour, so it can be done at any time, best before step 5 so the new interiors are made in `scenes/maps/interiors/` from the start.
