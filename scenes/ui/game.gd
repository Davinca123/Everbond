extends Node2D

@onready var companion = $Companion

func _input(event):
	# Ellenőrizzük, hogy a képernyőt megérintették-e
	if event is InputEventScreenTouch and event.pressed:
		
		# KISZŰRÉS: Ha a képernyő bal oldalára nyomtál (ahol a joystick van), azt NEM vesszük kattintásnak!
		if event.position.x < get_viewport_rect().size.x / 2:
			return
			
		# Átváltjuk a képernyő pixel-koordinátáját a játékvilág 2D koordinátájára
		var world_click_pos = get_canvas_transform().affine_inverse() * event.position
		
		# Elküldjük a lényt a megérintett pontra
		companion.send_to_position(world_click_pos)
