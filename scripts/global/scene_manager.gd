extends Node

# Pályaváltás: a Main jelenet (scenes/main/main.tscn) végig betöltve marad, csak a
# MapContainer-ben lévő pálya cserélődik. A Player és a Companion túléli a váltást:
# átköltöznek az új pálya YSort_Entities-ébe, hogy az NPC-kkel és ajtókkal együtt rendeződjenek.

const FADE_DURATION: float = 0.25
# A lény ennyivel a hős mellé érkezik, hogy ne a pálya másik végéről induljon
const COMPANION_SPAWN_OFFSET: Vector2 = Vector2(-60, 0)
# Kamerahatár, ha a pályán nincs egy csempe sem (a Camera2D alapértéke)
const NO_CAMERA_LIMIT: int = 10000000

var main: Node
# Az épp betöltött pálya (a MapContainer egyetlen gyereke)
var current_map: GameMap
var changing: bool = false

# A karakterek kezdő szintje (ütközési maszk és z_index). A szintváltó zónák ezt
# átállítják, ezért új pályán mindig a Lenti szintről indulnak.
var start_levels: Dictionary = {}

func register_main(main_node: Node) -> void:
	main = main_node
	for character in [main.player, main.companion]:
		start_levels[character] = { "mask": character.collision_mask, "z_index": character.z_index }

# A pálya lecserélése; a karakterek a spawn_id nevű érkezési pontra kerülnek (a pálya
# Spawns csomópontja alatt). A régi pálya minden állapota elveszik (lásd a terv 7. pontját).
func change_map(map_path: String, spawn_id: StringName = &"default", fade: bool = true) -> void:
	if changing:
		return
	changing = true
	main.player.control_enabled = false

	if fade:
		await _fade(1.0)

	var player: CharacterBody2D = main.player
	var companion: CharacterBody2D = main.companion

	# 1. A karakterek kiköltöznek a régi pályából, mielőtt az felszabadul
	if current_map:
		player.reparent(main, false)
		companion.reparent(main, false)
		main.map_container.remove_child(current_map)
		current_map.queue_free()

	# 2. Az új pálya betöltése (a _ready-jében már sül a navigációs háló)
	current_map = load(map_path).instantiate()
	main.map_container.add_child(current_map)

	# 3. Beköltöznek az új pálya YSort_Entities-ébe, a kezdőpontra
	player.reparent(current_map.entities, false)
	companion.reparent(current_map.entities, false)
	var spawn_point: Marker2D = current_map.get_spawn(spawn_id)
	var spawn: Vector2 = spawn_point.global_position if spawn_point else Vector2.ZERO
	player.global_position = spawn
	companion.global_position = spawn + COMPANION_SPAWN_OFFSET
	for character in start_levels:
		character.collision_mask = start_levels[character].mask
		character.z_index = start_levels[character].z_index
	companion.on_map_entered()
	_set_camera_limits(player.get_node("Camera2D"), current_map.get_camera_rect())

	if fade:
		await _fade(0.0)
	main.player.control_enabled = true
	changing = false

# A kamera nem mutat a pálya csempéin túl; csempék nélkül (pl. üres belső tér) nincs határ.
# A képernyőnél kisebb pályát (pl. egy szobát) középre tesszük: a határt a pálya közepe
# körül a képernyő méretére tágítjuk, különben a kamera a bal felső sarkához tapadna.
func _set_camera_limits(camera: Camera2D, rect: Rect2) -> void:
	if rect.has_area():
		var view_size: Vector2 = camera.get_viewport_rect().size / camera.zoom
		rect = rect.grow_individual(
			maxf(0.0, (view_size.x - rect.size.x) / 2.0), maxf(0.0, (view_size.y - rect.size.y) / 2.0),
			maxf(0.0, (view_size.x - rect.size.x) / 2.0), maxf(0.0, (view_size.y - rect.size.y) / 2.0))
		camera.limit_left = floori(rect.position.x)
		camera.limit_top = floori(rect.position.y)
		camera.limit_right = ceili(rect.end.x)
		camera.limit_bottom = ceili(rect.end.y)
	else:
		camera.limit_left = -NO_CAMERA_LIMIT
		camera.limit_top = -NO_CAMERA_LIMIT
		camera.limit_right = NO_CAMERA_LIMIT
		camera.limit_bottom = NO_CAMERA_LIMIT
	camera.reset_smoothing()

func _fade(to_alpha: float) -> void:
	var fade_rect: ColorRect = main.fade_rect
	# Elsötétítés alatt az érintések nem érik el a pályát
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP if to_alpha > 0.0 else Control.MOUSE_FILTER_IGNORE
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", to_alpha, FADE_DURATION)
	await tween.finished
