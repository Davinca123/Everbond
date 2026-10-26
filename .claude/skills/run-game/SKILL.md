---
name: run-game
description: Run the Everbond Godot game headless in the Linux container and drive it with a script (joystick, interact, tap), taking screenshots. Use to check a gameplay change in the real game.
---

# Run the game

Everbond is a Godot 4.7 project. The container has no Godot and no display, so the
game runs under `xvfb-run` and is driven by a GDScript that extends `SceneTree`.

## 1. Get Godot

```bash
G=$(.claude/skills/run-game/install_godot.sh)   # downloads once into ~/.cache/everbond-godot
"$G" --version                                  # 4.7.stable...
```

If `project.godot` moves to a new version (`config/features`), set `GODOT_VERSION`.

## 2. Import (fresh clone only)

When `.godot/` doesn't exist yet, import the resources first or scenes fail to load:

```bash
timeout 300 "$G" --headless --path . --import
```

## 3. Run a driver script

```bash
mkdir -p .claude/tmp/screenshots && touch .claude/tmp/.gdignore
OUT=.claude/tmp/screenshots timeout 120 xvfb-run -a -s "-screen 0 1280x720x24" \
  "$G" --path . --rendering-method gl_compatibility --rendering-driver opengl3 \
  --audio-driver Dummy -s <driver.gd> > .claude/tmp/run.log 2>&1
grep -E "CHECK|RESULT|ERROR|SCRIPT ERROR" .claude/tmp/run.log
```

- Keep `--rendering-method gl_compatibility --rendering-driver opengl3`: the default
  Vulkan renderer doesn't work under xvfb.
- `--headless` works too if you don't need screenshots (it's faster).
- Screenshots, videos, logs and throwaway drivers go in `.claude/tmp/` (see CLAUDE.md), so
  they can be opened from the workspace. The `.gdignore` keeps Godot from importing them.
- The driver can live in `.claude/tmp/` or outside the project; it still sees `res://`.
- The only expected warning is `Could not set V-Sync mode`. Anything else is worth reading.
- Look at the screenshots. A grey frame with nothing on it means the scene didn't load.

## Writing a driver

Start from `house_smoke.gd` in this folder. It enters House1Interior through World's
Door1, checks that the companion is there, follows the player and goes to a tapped
point, then leaves the house again. It then goes back in through the door that stayed
open (saved map state) and out once more. Exit code 0 means every check passed.
`exit_smoke.gd` does the same for the edge exits: World → Town → World.
`slice_playthrough.gd` plays the first playable slice (docs/gameplay-plan.md, section 10): the
Sage's hint, the gate failing at stay level 0, five stay trainings with treats (T), getting
through at level 1, and the chest. It also shows how to advance dialogue (`interact` action)
and give treats (`give_treat` action) through `Input.parse_input_event`.

The game is controlled through the `SignalBus` autoload, the same way the touch UI does it:

| What | How |
|---|---|
| Start the game | `change_scene_to_file("res://scenes/main/main.tscn")` in `_initialize()` (Main loads World) |
| Move the player | `SignalBus.joystick_moved.emit(direction)` every frame; `Vector2.ZERO` to stop |
| Interact (doors) | Put the player just below the door (`door.global_position + Vector2(0, 30)`), wait ~0.3 s, then `SignalBus.interaction_pressed.emit()` |
| Send the companion | `SignalBus.screen_tapped.emit(screen_position)` (screen, not world, coordinates) |
| Find the map | `root.get_node("SceneManager").current_map` (`current_scene` is always Main) |
| Find the entities | `<map>.get_node("YSort_Entities/Player")`, `.../Companion` |
| Screenshot | `root.get_viewport().get_texture().get_image().save_png(path)` |

Notes:

- Wait ~0.5–1 s after a map loads before acting: the navigation meshes bake in `_ready`.
- Door changes swap only the map: the Player and Companion nodes survive and move into the new
  map's `YSort_Entities`. The change fades out and in (~0.5 s), so wait for `current_map.name`.
- Companion states: `current_state` is `0` FOLLOW, `1` GO_TO_TARGET, `2` IDLE. After a tap it
  waits `stay_duration` (2 s) before walking back, so give "back with the player" checks time.
- Compare positions using the feet (`$CollisionShape2D`), not the sprite: the companion's
  path finding works from its feet.

`test/drive.gd` is an older driver for the World level-crossing scenarios
(`SCENARIO=tunnel` etc.). Run it the same way, with `res://test/drive.tscn` in place of `-s <driver.gd>`.
