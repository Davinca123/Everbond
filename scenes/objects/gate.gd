extends StaticBody2D

# Kapu: nyitva van, amíg a hozzá kötött nyomólapok közül valamelyik le van nyomva.
# Lassan nyílik (open_time alatt csúszik fel, és nyitva eltűnik a falban), és azonnal
# zárul, ha a lapot elengedik: így a lény várakozási ideje dönti el, hogy a hős átjut-e
# (docs/gameplay-plan.md, 10. rész). Záráskor a kép close_time alatt csúszik vissza, de a
# kapu már az elengedés pillanatában zárva van (ütközik, kitol).
# Aki záráskor a kapu alatt áll, azt a kapu kitolja arra, amerről jött, így senki sem
# ragad bele, de átjutni sem lehet úgy, hogy valaki benne áll.
# latch_on_pass: ha a hős átment a nyitott kapun, a túloldali retesz nyitva tartja, végleg
# (a pálya állapotával mentve).

signal opened_changed(open: bool)
# A hős átment a nyitott kapun, és a retesz nyitva tartja (a betöltött állapotra nem jön)
signal latched_by_pass

## A nyomólapok, amelyek nyitják (bármelyik elég)
@export var plates: Array[NodePath] = []
## Ennyi idő alatt nyílik ki teljesen (mp)
@export var open_time: float = 1.5
## Ennyi idő alatt csúszik vissza a kép záráskor (mp)
@export var close_time: float = 0.25
## Ha a hős átment rajta, nyitva marad
@export var latch_on_pass: bool = false

# A kapu képe a textúrán (az ajtóé, zárva)
const CLOSED_REGION: Rect2 = Rect2(29, 90, 37, 64)
# Kitoláskor ennyivel kerül a test a kapunyíláson kívülre (px)
const PUSH_MARGIN: float = 4.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var doorway: Area2D = $Doorway
@onready var doorway_shape: CollisionShape2D = $Doorway/CollisionShape2D

# 0 = zárva, 1 = teljesen nyitva (csak ekkor lehet átmenni)
var progress: float = 0.0
# Amennyire a kép nyitva látszik: nyitáskor a progress, záráskor lassan követi
var shown_progress: float = 0.0
var is_open: bool = false
var latched: bool = false
var linked_plates: Array[Node] = []
# A kapunyílásban állók: test -> melyik oldalról jött (1 = dél, -1 = észak)
var entry_sides: Dictionary = {}

func _ready() -> void:
	add_to_group(GameMap.PERSISTENT_GROUP)
	for path in plates:
		var plate := get_node_or_null(path)
		if plate:
			linked_plates.append(plate)
		else:
			push_warning("%s: nincs ilyen nyomólap: %s" % [name, path])
	doorway.body_entered.connect(_on_doorway_entered)
	doorway.body_exited.connect(_on_doorway_exited)
	update_sprite()

func is_pressed() -> bool:
	for plate in linked_plates:
		if plate.pressed:
			return true
	return false

func _physics_process(delta: float) -> void:
	if latched:
		return
	if is_pressed():
		if not is_open:
			progress = minf(progress + delta / open_time, 1.0)
			if progress >= 1.0:
				set_open(true)
	elif progress > 0.0:
		progress = 0.0
		if is_open:
			set_open(false)
	# A kép nyitáskor a kapuval együtt megy, záráskor close_time alatt csúszik vissza
	if shown_progress != progress:
		shown_progress = progress if progress > shown_progress else move_toward(shown_progress, progress, delta / close_time)
		update_sprite()

func set_open(open: bool) -> void:
	is_open = open
	collision_shape.set_deferred("disabled", open)
	# Nyitva a kapun át is vezethet út, zárva nem
	SignalBus.navigation_obstacles_changed.emit.call_deferred()
	if not open:
		push_out_of_doorway()
	opened_changed.emit(open)

func latch() -> void:
	latched = true
	progress = 1.0
	shown_progress = 1.0
	if not is_open:
		set_open(true)
	update_sprite()

# Felcsúszó kapu: az alja emelkedik, a teteje a helyén marad; teljesen nyitva nem látszik
func update_sprite() -> void:
	sprite.visible = shown_progress < 1.0
	if sprite.visible:
		sprite.region_rect = Rect2(CLOSED_REGION.position + Vector2(0, CLOSED_REGION.size.y * shown_progress),
				Vector2(CLOSED_REGION.size.x, CLOSED_REGION.size.y * (1.0 - shown_progress)))

# --- KAPUNYÍLÁS ---

func doorway_rect() -> Rect2:
	return doorway_shape.global_transform * doorway_shape.shape.get_rect()

func side_of(body: Node2D) -> int:
	return 1 if body.global_position.y > doorway_rect().get_center().y else -1

func _on_doorway_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		entry_sides[body] = side_of(body)

func _on_doorway_exited(body: Node2D) -> void:
	var entry_side: int = entry_sides.get(body, 0)
	entry_sides.erase(body)
	# A hős a nyitott kapun át a túloldalra ért
	if latch_on_pass and not latched and is_open and body.name == "Player" and entry_side != 0 and side_of(body) != entry_side:
		latch()
		latched_by_pass.emit()

# Záráskor a kapunyílásban állókat kitolja arra, amerről jöttek
func push_out_of_doorway() -> void:
	var rect := doorway_rect()
	for body in doorway.get_overlapping_bodies():
		if not body is CharacterBody2D:
			continue
		var shape_node := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape_node == null:
			continue
		var body_rect: Rect2 = shape_node.global_transform * shape_node.shape.get_rect()
		if entry_sides.get(body, side_of(body)) > 0:
			body.global_position.y += rect.end.y - body_rect.position.y + PUSH_MARGIN
		else:
			body.global_position.y -= body_rect.end.y - rect.position.y + PUSH_MARGIN

# A pálya mentett állapota (GameMap.save_map_state / load_map_state)
func save_state() -> Dictionary:
	return { "latched": latched }

func load_state(state: Dictionary) -> void:
	if state.get("latched", false):
		latch()
