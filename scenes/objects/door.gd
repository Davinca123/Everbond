extends StaticBody2D

@onready var interaction_area: Area2D = $InteractionArea
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite_2d: Sprite2D = $Sprite2D

const FRAME_CLOSED: int = 0  # A csukott ajtó csempe indexe
const FRAME_OPEN: int = 1    # A nyitott ajtó csempe indexe

var player_in_range: bool = false
var is_open: bool = false
var interaction_type: String = "door_enter"

# --- EDITORTÓL FÜGGŐ EGYEDI TULAJDONSÁGOK ---
@export_group("Teleportáció")
## Bejárható belső tér jelenetének elérési útja (pl. res://scenes/maps/house_1.tscn)
@export_file("*.tscn") var target_scene_path: String = ""

@export_group("Zár Mechanika")
## Megadja, hogy az ajtó alapból zárva van-e
@export var is_locked: bool = false
## A kulcs egyedi neve, amit a Player inventory-jában keresni kell (pl. "old_key")
@export var required_key_name: String = ""



func _ready() -> void:
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	SignalBus.interaction_pressed.connect(_on_interaction_pressed)
	
	sprite_2d.frame = FRAME_CLOSED

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" and not is_open:
		player_in_range = true
		SignalBus.show_interaction_button.emit(interaction_type)

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_in_range = false
		SignalBus.hide_interaction_button.emit()

func _on_interaction_pressed() -> void:
	if not player_in_range or is_open:
		return
		
	# 1. Ellenőrizzük, hogy zárva van-e
	if is_locked:
		if check_player_has_key():
			print("Door: Player unlocked the door with key: ", required_key_name)
			is_locked = false # Feloldjuk a zárat véglegesen
			open_door()
		else:
			print("Door: It's locked! You need a key.")
			# Itt küldhetsz egy üzenetet a DialogueBox-nak, hogy írja ki: "Zárva van..."
			return
	else:
		open_door()

func open_door() -> void:
	is_open = true
	player_in_range = false
	SignalBus.hide_interaction_button.emit()
	
	collision_shape.set_deferred("disabled", true)
	sprite_2d.frame = FRAME_OPEN
	
	# 2. Ha az ajtó egy belső térbe vezet, elindítjuk a jelenetváltást egy kis szünet után
	if target_scene_path != "":
		# Várunk 0.3 másodpercet, míg lefut a nyitási vizualizáció
		await get_tree().create_timer(0.1).timeout
		teleport_player()

func check_player_has_key() -> bool:
	# Ezt a függvényt később össze kell kötnöd a Player vagy a globális Inventory rendszereddel!
	# Feltételezzük, hogy van egy globális GameManager vagy a Player-nek van kulcs-listája:
	# return GameManager.player_inventory.has(required_key_name)
	return false # Alapértelmezetten most még hamisat ad vissza, amíg nincs inventory

func teleport_player() -> void:
	#print("Door: Teleporting player to: ", target_scene_path)
	# Ha a külső világban vagyunk (vagyis a world.tscn-ben)
	if get_tree().current_scene.name == "World":
		# Elmentjük, hol áll az ajtó. Amikor visszajövünk, picit ezelé rakjuk a játékost!
		GameManager.world_spawn_position = global_position + Vector2(0, 32) # 32 pixellel lejjebb, az ajtó elé
		GameManager.coming_back_from_interior = true

	
	# A Godot beépített jelenetváltó függvénye:
	get_tree().change_scene_to_file(target_scene_path)
