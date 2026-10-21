class_name GameMap extends Node2D

# Minden pálya gyökerének közös szkriptje (a scenes/maps/_base/ alapjeleneteken keresztül).
# A SceneManager ezen keresztül kérdezi meg az érkezési pontot és a kamera határait.

## A pálya kulcsa a mentett állapothoz (pl. &"village_house_01")
@export var map_id: StringName

@onready var entities: Node2D = $YSort_Entities
@onready var spawns: Node2D = $Spawns

# Az érkezési pont a Spawns alatt, azon a néven, ahonnan érkezünk (pl. &"from_world").
# Ha nincs ilyen, az első pontot adjuk vissza; null, ha egy sincs.
func get_spawn(spawn_id: StringName) -> Marker2D:
	var spawn := spawns.get_node_or_null(NodePath(spawn_id)) as Marker2D
	if spawn == null:
		push_warning("%s: nincs '%s' érkezési pont, az elsőt használjuk." % [name, spawn_id])
		if spawns.get_child_count() > 0:
			spawn = spawns.get_child(0) as Marker2D
	return spawn

# A kamera eddig mehet: a pálya összes TileMapLayer-ének kiterjedése
func get_camera_rect() -> Rect2:
	return get_tile_bounds(self)

# A pálya globális kiterjedése: az összes TileMapLayer használt területének uniója
static func get_tile_bounds(root: Node) -> Rect2:
	var bounds := Rect2()
	for layer in root.find_children("*", "TileMapLayer", true, false):
		var used: Rect2i = layer.get_used_rect()
		if not used.has_area() or layer.tile_set == null:
			continue
		var tile_size := Vector2(layer.tile_set.tile_size)
		var top_left: Vector2 = layer.to_global(Vector2(used.position) * tile_size)
		var bottom_right: Vector2 = layer.to_global(Vector2(used.end) * tile_size)
		var rect := Rect2(top_left, bottom_right - top_left).abs()
		bounds = rect if not bounds.has_area() else bounds.merge(rect)
	return bounds
