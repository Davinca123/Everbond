extends StaticBody2D

# Láda: egyszer lehet kinyitni (az interakció gombbal, az InteractionManager-en át),
# és nyitva marad, ha visszajövünk a pályára.

signal opened

## Ennyi jutalomfalat van benne
@export var treats: int = 5

const CLOSED_REGION: Rect2 = Rect2(96, 30, 32, 31)
const OPEN_REGION: Rect2 = Rect2(96, 76, 32, 49)

var interaction_type: String = "chest"
var is_open: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_area: Area2D = $InteractionArea

func _ready() -> void:
	add_to_group(GameMap.PERSISTENT_GROUP)
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	update_sprite()

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		InteractionManager.enter(self)

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		InteractionManager.exit(self)

func can_interact() -> bool:
	return not is_open

func interact() -> void:
	if is_open:
		return
	is_open = true
	update_sprite()
	if treats > 0:
		PlayerData.add_treats(treats)
		SignalBus.dialogue_started.emit("", (["CHEST_FOUND_TREATS"] as Array[String]))
	opened.emit()

# A kép alja a csomópont helyén van (a nyitott láda magasabb a felcsapott fedél miatt)
func update_sprite() -> void:
	sprite.region_rect = OPEN_REGION if is_open else CLOSED_REGION
	sprite.position = Vector2(-sprite.region_rect.size.x * sprite.scale.x / 2.0, -sprite.region_rect.size.y * sprite.scale.y)

# A pálya mentett állapota (GameMap.save_map_state / load_map_state)
func save_state() -> Dictionary:
	return { "is_open": is_open }

func load_state(state: Dictionary) -> void:
	is_open = state.get("is_open", is_open)
	update_sprite()
