class_name GameMap extends Node2D

# Minden pálya gyökerének közös szkriptje (a scenes/maps/_base/ alapjeleneteken keresztül).
# A SceneManager ezen keresztül kérdezi meg az érkezési pontot és a kamera határait.

## A pálya kulcsa a mentett állapothoz (pl. &"village_house_01")
@export var map_id: StringName
## Láthatatlan fal a talaj széle körül, hogy a hős és a lény ne menjen le a pályáról
## (a kültéri pályákon; a belső terekben a falcsempék zárnak)
@export var block_map_edges: bool = false

# Ennek a csoportnak a tagjai a pálya elhagyásakor elmentik, betöltéskor visszakapják az
# állapotukat (save_state() -> Dictionary, load_state(state: Dictionary)), pl. a nyitott ajtók
const PERSISTENT_GROUP: StringName = &"map_state"

# A pályaszéli fal mindkét szinten (Lenti_Szint, Fenti_Szint) ütközik
const EDGE_COLLISION_LAYERS: int = 1 | 2

@onready var entities: Node2D = $YSort_Entities
@onready var spawns: Node2D = $Spawns

# Már belépéskor építjük, a gyerekek _ready-je előtt: így a navigációs háló sütésekor
# (CollisionNavRegion._ready) a fal is akadály, és a háló nem lóg ki a talaj szélén túlra
func _enter_tree() -> void:
	if block_map_edges and not has_node("EdgeWalls"):
		add_child(build_edge_walls())

# A gyerekek _ready-je után: a mentett állapot visszatöltése
func _ready() -> void:
	load_map_state()

func load_map_state() -> void:
	if map_id == &"":
		return
	var saved: Dictionary = GameManager.map_state.get(map_id, {})
	for node in get_persistent_nodes():
		var key := str(get_path_to(node))
		if saved.has(key):
			node.load_state(saved[key])

# A SceneManager hívja, mielőtt kiveszi a pályát a fából (az _exit_tree-ben már késő:
# addigra a gyerekek kiléptek a fából és a csoportokból)
func save_map_state() -> void:
	if map_id == &"":
		push_warning("%s: nincs map_id, az állapota nem mentődik." % name)
		return
	var saved: Dictionary = {}
	for node in get_persistent_nodes():
		saved[str(get_path_to(node))] = node.save_state()
	GameManager.map_state[map_id] = saved

# A pálya saját mentendő csomópontjai (a Player és a Companion nincs a csoportban)
func get_persistent_nodes() -> Array[Node]:
	var nodes: Array[Node] = []
	for node in get_tree().get_nodes_in_group(PERSISTENT_GROUP):
		if is_ancestor_of(node):
			nodes.append(node)
	return nodes

# A talaj (a MAP_LAYERS alatti, a Ground_TileMapLayer rácsán lévő csempék) körüli üres
# cellák ütköznek, az átlósan szomszédosak is, hogy a sarkoknál ne legyen rés. A pálya
# szabálytalan alakú is lehet; a soronként összefüggő cellák egy téglalapot kapnak.
func build_edge_walls() -> StaticBody2D:
	var walls := StaticBody2D.new()
	walls.name = "EdgeWalls"
	walls.collision_layer = EDGE_COLLISION_LAYERS
	walls.collision_mask = 0
	var ground := get_node_or_null("MAP_LAYERS/Ground_TileMapLayer") as TileMapLayer
	if ground == null or ground.tile_set == null:
		push_warning("%s: nincs Ground_TileMapLayer, nem építünk pályaszéli falat." % name)
		return walls

	var floor_cells: Dictionary = {}
	for layer in get_node("MAP_LAYERS").find_children("*", "TileMapLayer", true, false):
		if layer.tile_set != null and layer.tile_set.tile_size == ground.tile_set.tile_size and layer.transform == ground.transform:
			for cell in layer.get_used_cells():
				floor_cells[cell] = true
	var blocked: Dictionary = {}
	for cell in floor_cells:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var neighbour: Vector2i = cell + Vector2i(dx, dy)
				if not floor_cells.has(neighbour):
					blocked[neighbour] = true

	var cells: Array = blocked.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var cell_size: Vector2 = Vector2(ground.tile_set.tile_size) * ground.global_transform.get_scale()
	var i: int = 0
	while i < cells.size():
		var first: Vector2i = cells[i]
		var count: int = 1
		while i + count < cells.size() and cells[i + count] == first + Vector2i(count, 0):
			count += 1
		var shape := RectangleShape2D.new()
		shape.size = Vector2(cell_size.x * count, cell_size.y)
		var collision := CollisionShape2D.new()
		collision.shape = shape
		var top_left: Vector2 = ground.to_global(Vector2(first * ground.tile_set.tile_size))
		collision.position = to_local(top_left + shape.size / 2.0)
		walls.add_child(collision)
		i += count
	return walls

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
