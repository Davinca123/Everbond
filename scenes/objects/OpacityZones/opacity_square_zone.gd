extends Area2D

@export var target_layers: Array[Node2D] = []
@export var target_opacity: float = 0.4
@export var fade_duration: float = 0.2

var global_min: Vector2
var global_max: Vector2

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Kiszámoljuk a CollisionShape2D kiterjedését
	var collision_shape: CollisionShape2D = $CollisionShape2D
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var zone_size: Vector2 = collision_shape.shape.size
		global_min = global_position - (zone_size / 2)
		global_max = global_position + (zone_size / 2)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		for layer in target_layers:
			if layer and layer.material is ShaderMaterial:
				var mat: ShaderMaterial = layer.material
				
				# Közvetlenül a tiszta globális pozíciókat adjuk át!
				mat.set_shader_parameter("zone_min", global_min)
				mat.set_shader_parameter("zone_max", global_max)
				
				var tween = create_tween()
				tween.tween_property(mat, "shader_parameter/opacity", target_opacity, fade_duration)

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		for layer in target_layers:
			if layer and layer.material is ShaderMaterial:
				var mat: ShaderMaterial = layer.material
				var tween = create_tween()
				tween.tween_property(mat, "shader_parameter/opacity", 1.0, fade_duration)
