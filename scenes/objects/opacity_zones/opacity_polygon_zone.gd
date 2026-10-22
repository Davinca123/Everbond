extends Area2D

#További rétegek, amiket el kell halványítani
@export var additional_layers: Array[Node2D] = []
@export var target_opacity: float = 0.4
@export var fade_duration: float = 0.2

# Lokális állapotok a Playernek és a Companionnek
var player_in: bool = false #player enterer the zone through an EnterZone
var companion_in: bool = false
#Player is in the ShaderZone
var player_in_shader_zone: bool = false
var companion_in_shader_zone: bool = false

# A shader egyszerre ennyi halványított zónát és zónánként ennyi pontot tud tárolni (opacity_polygon.gdshader)
const MAX_ACTIVE: int = 2
const MAX_POINTS: int = 16

# Az épp halványított zónák, helyenként (slot) egy. Minden zóna osztozik rajta.
static var slots: Array = [null, null]

# A shaderhez szükséges pontok a nagy takaró zónához
var global_points: PackedVector2Array = []
# A zóna helye a shader tömbjeiben, amíg halványítva van; -1, ha nincs helye
var slot: int = -1
var current_opacity: float = 1.0
var fading_out: bool = false
var fade_tween: Tween
# Szintváltó kapuk (EnterZone sávok) a lény útvonaltervezéséhez (companion.gd).
# Elemei: { "center": a sáv közepe, "inward": a ShaderZone felé mutató egységvektor,
#           "outside_level": szint kint, "inside_level": szint bent }
var portals: Array[Dictionary] = []

func _ready() -> void:
	add_to_group("opacity_zones")
	# A részletes "shape" szignálokat kötjük be
	body_shape_entered.connect(_on_body_shape_entered)
	body_shape_exited.connect(_on_body_shape_exited)
		
	# Megkeressük a nagy ShaderZone-t a jelenetben, és elmentjük a pontjait a shaderhez
	var shader_poly = get_node_or_null("ShaderZone")
	if shader_poly is CollisionPolygon2D:
		for vertex in shader_poly.polygon:
			global_points.append(shader_poly.to_global(vertex))

	if global_points.size() > MAX_POINTS:
		push_warning("%s: a ShaderZone-nak %d pontja van, a shader csak az első %d-at használja." % [name, global_points.size(), MAX_POINTS])
		global_points.resize(MAX_POINTS)
	find_portals()

# Az EnterZone sávok vékony téglalapok: a legrövidebb oldaluk iránya a sávon át mutat,
# és amerre a ShaderZone van, arra van "bent"
func find_portals() -> void:
	for child in get_children():
		if not child is CollisionPolygon2D or not child.name.begins_with("EnterZone") or child.polygon.size() < 3:
			continue
		var points: PackedVector2Array = []
		var center := Vector2.ZERO
		for vertex in child.polygon:
			points.append(child.to_global(vertex))
			center += points[-1]
		center /= points.size()
		var across := Vector2.ZERO
		for i in points.size():
			var edge: Vector2 = points[(i + 1) % points.size()] - points[i]
			if across == Vector2.ZERO or edge.length() < across.length():
				across = edge
		var inward := across.normalized()
		if not Geometry2D.is_point_in_polygon(center + inward * 20.0, global_points):
			inward = -inward
		portals.append({ "center": center, "inward": inward, "outside_level": 1, "inside_level": 2 })

# Ha a pálya kicserélődik, a helyet is felszabadítjuk
func _exit_tree() -> void:
	release_slot()

# Szabad helyet keresünk; ha nincs, egy éppen visszaálló zónától vesszük el
func acquire_slot() -> bool:
	var free := -1
	for i in MAX_ACTIVE:
		if slots[i] == null or not is_instance_valid(slots[i]):
			free = i
			break
	if free < 0:
		for i in MAX_ACTIVE:
			if slots[i].fading_out:
				free = i
				if slots[i].fade_tween:
					slots[i].fade_tween.kill()
				slots[i].release_slot()
				break
	if free < 0:
		push_warning("%s: egyszerre legfeljebb %d zóna lehet halványítva, ez nem halványul." % [name, MAX_ACTIVE])
		return false

	slots[free] = self
	slot = free
	current_opacity = 1.0
	write_points()
	return true

# A zóna kikerül a shaderből: a helyén nem marad sokszög
func release_slot() -> void:
	if slot < 0:
		return
	for mat in get_materials():
		var counts = mat.get_shader_parameter("point_counts")
		if counts is PackedInt32Array and counts.size() > slot:
			counts[slot] = 0
			mat.set_shader_parameter("point_counts", counts)
	if slots[slot] == self:
		slots[slot] = null
	slot = -1
	current_opacity = 1.0

# A zóna pontjait a saját helyére írjuk be minden anyagba
func write_points() -> void:
	for mat in get_materials():
		var points = mat.get_shader_parameter("polygon_points")
		if not points is PackedVector2Array:
			points = PackedVector2Array()
		points.resize(MAX_ACTIVE * MAX_POINTS)
		for i in global_points.size():
			points[slot * MAX_POINTS + i] = global_points[i]
		mat.set_shader_parameter("polygon_points", points)

		var counts = mat.get_shader_parameter("point_counts")
		if not counts is PackedInt32Array:
			counts = PackedInt32Array()
		counts.resize(MAX_ACTIVE)
		counts[slot] = global_points.size()
		mat.set_shader_parameter("point_counts", counts)
	set_opacity(current_opacity)

func get_materials() -> Array[ShaderMaterial]:
	var materials: Array[ShaderMaterial] = []
	for layer in additional_layers:
		if layer and layer.material is ShaderMaterial and not materials.has(layer.material):
			materials.append(layer.material)
	return materials

# --- BELÉPÉS ---
func _on_body_shape_entered(body_rid: RID, body: Node2D, _body_shape_index: int, local_shape_index: int) -> void:
	if body.name == "Player" or body.name == "Companion":
		var hit_polygon = get_polygon_node_from_index(local_shape_index)
		if not hit_polygon:
			return

		# 1. Ha a nagy ShaderZone-ba lép be: regisztráljuk, hogy bent van
		if hit_polygon.name == "ShaderZone":
			if body.name == "Player":
				player_in_shader_zone = true
				#print("p shader in")
			elif body.name == "Companion":
				companion_in_shader_zone = true
				#print("c shader in")

		# 2. Ha az egyik kapun lép be: elindítjuk az alagút módot
		elif hit_polygon.name.begins_with("EnterZone"):
			if body.name == "Player":
				player_in = true
				set_character_to_underground(body, true)
				#print("p enter in")
			elif body.name == "Companion":
				companion_in = true
				set_character_to_underground(body, true)
				#print("c enter in")
			update_zone_state()

# --- KILÉPÉS ---
func _on_body_shape_exited(body_rid: RID, body: Node2D, _body_shape_index: int, local_shape_index: int) -> void:
	if body.name == "Player" or body.name == "Companion":
		var exited_polygon = get_polygon_node_from_index(local_shape_index)
		if not exited_polygon:
			return

		if exited_polygon.name == "ShaderZone":
			if body.name == "Player":
				player_in_shader_zone = false
				#player_in = false
				#print("p shader out")
			elif body.name == "Companion":
				companion_in_shader_zone = false
				#companion_in = false
				#print("c shader out")
			#update_zone_state()

		elif exited_polygon.name.begins_with("EnterZone"):
			#print("enter exited")
			# Megnézzük, hogy a kapu elhagyásakor bent van-e a nagy zónában.
			var is_still_inside = player_in_shader_zone if body.name == "Player" else companion_in_shader_zone
			
			if not is_still_inside:
				if body.name == "Player":
					player_in = false
					set_character_to_underground(body, false)
					#print("p enter out")
				elif body.name == "Companion":
					companion_in = false
					set_character_to_underground(body, false)
					#print("c enter out")
				update_zone_state()

# --- SEGÉDFÜGGVÉNY AZ INDEXEKHEZ ---
func get_polygon_node_from_index(shape_index: int) -> Node:
	var owner_id = shape_find_owner(shape_index)
	var polygon_node = shape_owner_get_owner(owner_id)
	return polygon_node
	
# --- KARAKTER ÁLLAPOT VÁLTÓ ---
func set_character_to_underground(character: Node2D, underground: bool) -> void:
	if underground:
		# VIZUÁLIS VÁLTÁS: Lemegy Z-index 0-ra, hogy a híd (Z-index: 1) eltakarja őt
		character.z_index = 0
		
		# FIZIKAI VÁLTÁS: Átrakjuk a maszkot az alagút alatti falakra (Layer 2)
		character.set_collision_mask_value(1, false)
		character.set_collision_mask_value(2, true)
	else:
		# VIZUÁLIS RESET: Visszakerül Z-index 1-re, hogy a híd tetején sétáljon
		character.z_index = 1
		
		# FIZIKAI RESET: Visszarakjuk a maszkot a normál falakra (Layer 1)
		character.set_collision_mask_value(2, false)
		character.set_collision_mask_value(1, true)

# --- ÁLLAPOT FRISSÍTÉS ---
func update_zone_state() -> void:
	var should_be_active: bool = player_in or companion_in
	
	if should_be_active:
		set_zone_state(target_opacity)

	else:
		set_zone_state(1.0)


func set_zone_state(opa: float) -> void:
	fading_out = opa >= 1.0
	if slot < 0:
		# Ami nincs halványítva, azt nem kell visszaállítani
		if fading_out or not acquire_slot():
			return
	# Az előző áttűnést leállítjuk, különben a kettő egymással harcolna
	if fade_tween:
		fade_tween.kill()
	fade_tween = create_tween()
	fade_tween.tween_method(set_opacity, current_opacity, opa, fade_duration)
	# Ha teljesen visszaállt, a helyét átadhatja egy másik zónának
	if fading_out:
		fade_tween.tween_callback(release_slot)

# Csak a saját helyünket írjuk át az opacities tömbben, a többi zónáét nem
func set_opacity(opa: float) -> void:
	if slot < 0:
		return
	current_opacity = opa
	for mat in get_materials():
		var opacities = mat.get_shader_parameter("opacities")
		if not opacities is PackedFloat32Array:
			opacities = PackedFloat32Array()
		opacities.resize(MAX_ACTIVE)
		opacities[slot] = opa
		mat.set_shader_parameter("opacities", opacities)
