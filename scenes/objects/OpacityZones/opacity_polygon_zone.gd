extends Area2D

@export var target_layers: Array[Node2D] = []
@export var target_opacity: float = 0.4
@export var fade_duration: float = 0.2

@onready var collision_poly: CollisionPolygon2D = $CollisionPolygon2D

var global_points: PackedVector2Array = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Kiszámoljuk a sokszög pontjainak GLOBÁLIS pozícióit
	if collision_poly:
		for vertex in collision_poly.polygon:
			global_points.append(collision_poly.to_global(vertex))

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		for layer in target_layers:
			if layer and layer.material is ShaderMaterial:
				var mat: ShaderMaterial = layer.material
				
				# Átadjuk a globális pontokat a shader tömbjének
				mat.set_shader_parameter("point_count", global_points.size())
				mat.set_shader_parameter("polygon_points", global_points)
				
				var tween = create_tween()
				tween.tween_property(mat, "shader_parameter/opacity", target_opacity, fade_duration)

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		for layer in target_layers:
			if layer and layer.material is ShaderMaterial:
				var mat: ShaderMaterial = layer.material
				var tween = create_tween()
				tween.tween_property(mat, "shader_parameter/opacity", 1.0, fade_duration)
