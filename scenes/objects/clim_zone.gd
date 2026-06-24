extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# Csak a Player és a Companion rétegeit módosítjuk
	if body.name == "Player" or body.name == "Companion":
		
		# Megnézzük, hogy az 1-es (Lenti) réteget figyeli-e éppen a karakter
		var is_currently_on_lower_layer: bool = body.get_collision_mask_value(1)
		
		if is_currently_on_lower_layer:
			# Ha lent volt, átrakjuk fentre
			body.set_collision_mask_value(1, false)
			body.set_collision_mask_value(2, true)
			body.z_index = 1
			#print(body.name, " FELFELÉ halad (Réteg megfordítva fentre).")
		else:
			# Ha fent volt, átrakjuk lentre
			body.set_collision_mask_value(1, true)
			body.set_collision_mask_value(2, false)
			body.z_index = 0
			#print(body.name, " LEFELÉ halad (Réteg megfordítva lentre).")
