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

# A shaderhez szükséges pontok a nagy takaró zónához
var global_points: PackedVector2Array = []

func _ready() -> void:
	# A részletes "shape" szignálokat kötjük be
	body_shape_entered.connect(_on_body_shape_entered)
	body_shape_exited.connect(_on_body_shape_exited)
		
	# Megkeressük a nagy ShaderZone-t a jelenetben, és elmentjük a pontjait a shaderhez
	var shader_poly = get_node_or_null("ShaderZone")
	if shader_poly is CollisionPolygon2D:
		for vertex in shader_poly.polygon:
			global_points.append(shader_poly.to_global(vertex))

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
	# Set target layers opacity
	for layer in additional_layers:
		if layer and layer.material is ShaderMaterial:
			var mat: ShaderMaterial = layer.material
			
			# Átadjuk a globális pontokat a shader tömbjének
			mat.set_shader_parameter("point_count", global_points.size())
			mat.set_shader_parameter("polygon_points", global_points)
			
			var tween = create_tween()
			tween.tween_property(mat, "shader_parameter/opacity", opa, fade_duration)
