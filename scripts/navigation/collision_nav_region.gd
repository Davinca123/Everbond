extends NavigationRegion2D

# Futásidőben sütött navigációs háló a pálya ütközési alakzataiból.
# A pálya kiterjedését a jelenet összes TileMapLayer-éből számoljuk,
# az akadályokat pedig a megadott ütközési maszk statikus testeiből (falak, ajtók).
# Rétegenként (Lenti/Fenti szint) egy-egy ilyen régió kell, a navigation_layers
# bitje egyezzen a source_collision_mask bitjével.

## Melyik ütközési réteg(ek) akadályait vegye figyelembe a sütés
@export_flags_2d_physics var source_collision_mask: int = 1
## A karakter ütközési sugara + egy kis ráhagyás, ennyivel tartja távol az utat a falaktól
@export var agent_radius: float = 36.0

var _rebake_pending: bool = false

func _ready() -> void:
	# Ha egy ajtó kinyílik (vagy más akadály változik), újrasütjük a hálót
	SignalBus.navigation_obstacles_changed.connect(_request_rebake)
	bake()

func _request_rebake() -> void:
	# Egy képkockán belüli több kérést egyetlen sütéssé vonunk össze
	if _rebake_pending:
		return
	_rebake_pending = true
	await get_tree().physics_frame
	_rebake_pending = false
	bake()

func bake() -> void:
	var source_root: Node = owner if owner else get_parent()
	var bounds: Rect2 = GameMap.get_tile_bounds(source_root)
	if not bounds.has_area():
		push_warning("CollisionNavRegion: nincs TileMapLayer a pályán, nem sütünk hálót.")
		return

	var nav_poly := NavigationPolygon.new()
	nav_poly.agent_radius = agent_radius
	nav_poly.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_poly.parsed_collision_mask = source_collision_mask
	nav_poly.add_outline(PackedVector2Array([
		bounds.position,
		Vector2(bounds.end.x, bounds.position.y),
		bounds.end,
		Vector2(bounds.position.x, bounds.end.y),
	]))

	var source_data := NavigationMeshSourceGeometryData2D.new()
	NavigationServer2D.parse_source_geometry_data(nav_poly, source_data, source_root)
	NavigationServer2D.bake_from_source_geometry_data(nav_poly, source_data)
	navigation_polygon = nav_poly
