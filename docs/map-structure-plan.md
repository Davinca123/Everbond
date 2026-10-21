# Plan: world and room map structure

How to structure the world map, its areas and the room interiors so that:

- the large world is split into smaller areas, with a scene change between them,
- there can be many interiors, including buildings with several rooms,
- several tile sets are used, and many maps share the same tile set.

## Where things stand

- Every map (`world.tscn`, `House1Interior.tscn`) has its own Player, Companion and ScreenUI. Map changes use `get_tree().change_scene_to_file()`, so the player, the companion's state and the UI are rebuilt on every change.
- Going back from an interior uses `GameManager.world_spawn_position` / `coming_back_from_interior`. It only works for doors that start in World (`door.gd` checks `current_scene.name == "World"`).
- The three TileSets in `world.tscn` are stored inside that scene, so no other map can reuse them.
- The camera limits are hard-coded to ±10000 in `player.tscn`.

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
@export var music: AudioStream

@onready var entities: Node2D = $YSort_Entities

func get_spawn(spawn_id: StringName) -> Marker2D:
	return $Spawns.get_node(NodePath(spawn_id))

func get_camera_rect() -> Rect2:
	# Built from the TileMapLayers, like CollisionNavRegion._get_map_bounds
	...
```

`get_camera_rect()` replaces the hard-coded camera limits.

The map scenes are built with Godot's inherited scenes (**Scene → New Inherited Scene**):

```
base_map.tscn                  GameMap script, MAP_LAYERS (no tile set), YSort_Entities,
│                              Spawns, Doors, NAVIGATION — no Player/Companion/UI
├── base_outdoor_grass.tscn    sets the outdoor tile sets on the layers, adds the Fenti layers + Navigation_Layer2
│   ├── forest_01.tscn
│   └── village.tscn
└── base_interior_wood.tscn    sets interior_wood.tres, one level only
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

- **Internal doors:** when `target_map` is empty, the door teleports to `target_spawn` inside the current map. The move is instant and needs no loading.
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
└── navigation/
```

File names use snake_case (Godot's convention): `House1Interior.tscn` becomes `house_1_interior.tscn`. Rename and move files from inside the Godot editor so it updates the references.

## Order of work

One branch per step:

1. **`refactor/shared-tilesets`**: save the TileSets as `.tres` files. Nothing visible changes.
2. **`refactor/persistent-main-scene`**: add `main.tscn` and `SceneManager`; move Player, Companion, ScreenUI and the tap-to-send handler into Main. The biggest step.
3. **`refactor/game-map-base`**: add `GameMap`, the base scenes and spawn points. Switch the door to `target_map` + `target_spawn` and remove the `world_spawn_position` workaround. The uncommitted `Room.tscn` from `feat/room-scene` becomes `base_interior_wood.tscn` here.
   As built: the assets have no wood interior tiles, so the interior base is `base_interior_stone.tscn` with `interior_stone_ground.tres` (the pack's stone ground) for the floor and the outdoor lower walls for collision. `Doors` sits inside `YSort_Entities` so doors Y-sort with the characters, and `base_map` keeps `MAP_LAYERS` empty: each base adds its layers in draw order. The `music` export waits until there is audio. Camera limits come from `GameMap.get_camera_rect()`; a map with no tiles has no limits.
4. **`feat/map-exit`**: edge exits between areas, then split World into areas.
5. **`feat/multi-room-interiors`**: room camera bounds and internal teleport doors.
6. **`feat/map-state`**: per-map saved state.
