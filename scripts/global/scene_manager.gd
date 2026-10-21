extends Node

# Pályaváltás: a Main jelenet (scenes/main/main.tscn) végig betöltve marad, csak a
# MapContainer-ben lévő pálya cserélődik. A Player és a Companion túléli a váltást:
# átköltöznek az új pálya YSort_Entities-ébe, hogy az NPC-kkel és ajtókkal együtt rendeződjenek.

const FADE_DURATION: float = 0.25
# A lény ennyivel a hős mellé érkezik, hogy ne a pálya másik végéről induljon
const COMPANION_SPAWN_OFFSET: Vector2 = Vector2(-60, 0)

var main: Node
# Az épp betöltött pálya (a MapContainer egyetlen gyereke)
var current_map: Node2D
var changing: bool = false

# A karakterek kezdő szintje (ütközési maszk és z_index). A szintváltó zónák ezt
# átállítják, ezért új pályán mindig a Lenti szintről indulnak.
var start_levels: Dictionary = {}

func register_main(main_node: Node) -> void:
	main = main_node
	for character in [main.player, main.companion]:
		start_levels[character] = { "mask": character.collision_mask, "z_index": character.z_index }

# A pálya lecserélése. A régi pálya minden állapota elveszik (lásd a terv 7. pontját).
func change_map(map_path: String, fade: bool = true) -> void:
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
	var entities: Node = current_map.get_node("YSort_Entities")
	player.reparent(entities, false)
	companion.reparent(entities, false)
	var spawn: Vector2 = _get_spawn_position(current_map)
	player.global_position = spawn
	companion.global_position = spawn + COMPANION_SPAWN_OFFSET
	for character in start_levels:
		character.collision_mask = start_levels[character].mask
		character.z_index = start_levels[character].z_index
	companion.on_map_entered()
	player.get_node("Camera2D").reset_smoothing()

	if fade:
		await _fade(0.0)
	main.player.control_enabled = true
	changing = false

# Ha a pálya maga dönti el, hová érkezünk (pl. a World az ajtó elé), azt használjuk,
# különben a kézzel lerakott SpawnPoint-ot
func _get_spawn_position(map: Node) -> Vector2:
	if map.has_method("get_spawn_position"):
		return map.get_spawn_position()
	return map.get_node("YSort_Entities/SpawnPoint").global_position

func _fade(to_alpha: float) -> void:
	var fade_rect: ColorRect = main.fade_rect
	# Elsötétítés alatt az érintések nem érik el a pályát
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP if to_alpha > 0.0 else Control.MOUSE_FILTER_IGNORE
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", to_alpha, FADE_DURATION)
	await tween.finished
