extends CharacterBody2D

# Beállítások
@export var follow_speed: float = 160.0 # Kicsit lassabb, mint a főhős
@export var min_distance: float = 60.0  # Milyen közel álljon meg a hőstől
@export var target_margin: float = 5.0  # Pontosság a kattintott célpontnál

# Útkeresés: ilyen gyakran számoljuk újra az utat (mp), és ilyen közel kell érni egy útponthoz
const REPATH_INTERVAL: float = 0.25
const WAYPOINT_REACHED_DISTANCE: float = 8.0

# Hivatkozás a főhősre
@onready var player = $"../Player"
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite_2d: Sprite2D = $Sprite2D
# A lábak (ütközési alakzat) helye, az útkeresés ehhez igazodik, nem a sprite közepéhez
@onready var feet: CollisionShape2D = $CollisionShape2D
@onready var player_feet: CollisionShape2D = player.get_node("CollisionShape2D")

# Az aktuális út a navigációs hálón
var path: PackedVector2Array = []
var path_index: int = 0
var repath_timer: float = 0.0

# Változó, ami másodpercben méri, mióta állunk egy helyben
var idle_time: float = 0.0
var idle2_timer: float =0.0
var is_playing_fidget: bool = false # Figyeli, hogy fut-e az egyszeri idle2

# Itt adhatod meg (másodpercben), mikor váltson szintet az unalom
const TIME_FOR_IDLE2: float = 5.0  # 5 másodperc után unatkozik
const TIME_FOR_SLEEP: float = 12.0 # 12 másodperc után elalszik


# Állapotok (Enums)
enum State { FOLLOW, GO_TO_TARGET, IDLE }
var current_state : State = State.FOLLOW

# Változók a kattintásos mozgáshoz
var click_target_pos : Vector2 = Vector2.ZERO

func _ready() -> void:
	# BIZTONSÁGI CSERE: Leválasztjuk a régit (ha volt), és tisztán kódból kötjük össze
	animation_player.animation_finished.connect(_on_animation_finished)
			

func _physics_process(delta):
	repath_timer -= delta
	match current_state:
		State.FOLLOW:
			handle_follow_logic()
		State.GO_TO_TARGET:
			handle_goto_logic()
		State.IDLE:
			velocity = Vector2.ZERO
			
	# IRÁNYBA FORDULÁS:
	# Ha a sebesség x tengelye negatív, balra megy -> tükrözzük a képet
	if velocity.x < 0:
		sprite_2d.flip_h = true
	# Ha pozitív, jobbra megy -> visszaállítjuk az eredetire
	elif velocity.x > 0:
		sprite_2d.flip_h = false
		
	# ANIMÁCIÓ VEZÉRLÉS:
	if velocity.length() > 0:
		# HA MOZOG: nullázzuk az állási időt és fut a walk
		idle_time = 0.0
		idle2_timer = 0.0
		is_playing_fidget = false
		if animation_player.current_animation != "walk":
			animation_player.play("walk")
			animation_player.speed_scale = 2.0
	else:
		# HA ÁLL: elkezdjük növelni az állási időt a delta idővel (másodperccel)
		if not is_playing_fidget:
			idle_time += delta
			idle2_timer += delta
			
		# Ha épp az egyszeri idle2 pörög, nem nyúlunk hozzá, megvárjuk, míg lefut
		if is_playing_fidget:
			return
		
		# Megnézzük, melyik fázisban tart az unalom
		if idle_time >= TIME_FOR_SLEEP:
			# Nagyon sokáig állt -> Alvás
			if animation_player.current_animation != "sleep":
				animation_player.play("sleep")
				animation_player.speed_scale = 1.0
		elif idle_time >= TIME_FOR_IDLE2 and idle2_timer >TIME_FOR_IDLE2:
			# Elérte az 5 másodpercet: elindítjuk az egyszeri idle2-t
			is_playing_fidget = true
			animation_player.play("idle2")
			animation_player.speed_scale = 1.0
		else:
			# Épp most állt meg -> Alap Idle
			if animation_player.current_animation != "idle":
				animation_player.play("idle1")
				animation_player.speed_scale = 1.0

	move_and_slide()

# 1. LOGIKA: A főhős automatikus követése
func handle_follow_logic():
	# A navigációs hálón keresünk utat a hős lábához, így a falakat is megkerüli
	update_path(player_feet.global_position)

	# Ha messzebb van a hős (az úton mérve), mint a megengedett minimum, utána megyünk
	if remaining_path_length() > min_distance:
		velocity = path_direction() * follow_speed
	else:
		velocity = Vector2.ZERO # Ha elég közel van, megáll

# 2. LOGIKA: Séta a kattintott pontra
func handle_goto_logic():
	update_path(click_target_pos)

	# Ha még nem értük el a pontot
	if remaining_path_length() > target_margin:
		velocity = path_direction() * follow_speed
	else:
		# Megérkeztünk! Átváltunk IDLE (várakozó) állapotba
		velocity = Vector2.ZERO
		current_state = State.IDLE
		print("Lény: Megérkeztem a célhoz!")
		
		# IDŐZÍTŐ (Opcionális): Vár 2 másodpercet, majd visszaszalad a hőshöz
		await get_tree().create_timer(2.0).timeout
		if current_state == State.IDLE: # Ha közben nem küldtük máshova
			current_state = State.FOLLOW

# Ezt a függvényt a fő Game kód fogja meghívni, ha a játékos kattintott
func send_to_position(target_pos: Vector2):
	click_target_pos = target_pos
	current_state = State.GO_TO_TARGET
	repath_timer = 0.0 # Azonnal új utat számolunk az új célhoz
	print("Lény: Indulok a koordinátára: ", target_pos)

# --- ÚTKERESÉS ---

# Újraszámolja az utat a célig, de csak REPATH_INTERVAL-onként
func update_path(target: Vector2) -> void:
	if repath_timer > 0.0 and not path.is_empty():
		return
	repath_timer = REPATH_INTERVAL

	var nav_map: RID = get_world_2d().navigation_map
	path = NavigationServer2D.map_get_path(nav_map, feet.global_position, target, true, get_navigation_layers())
	path_index = 0
	# Nincs navigációs háló (pl. belső tér) -> egyenesen megyünk a célhoz, mint régen
	if path.is_empty():
		path = PackedVector2Array([feet.global_position, target])

# A Lenti/Fenti szint ütközési maszkjához tartozó navigációs réteget használjuk
func get_navigation_layers() -> int:
	var layers: int = 0
	if get_collision_mask_value(1):
		layers |= 1
	if get_collision_mask_value(2):
		layers |= 2
	return layers

# Irány a következő útpont felé (az elért útpontokat átlépjük)
func path_direction() -> Vector2:
	var from: Vector2 = feet.global_position
	while path_index < path.size() - 1 and from.distance_to(path[path_index]) < WAYPOINT_REACHED_DISTANCE:
		path_index += 1
	if path_index >= path.size():
		return Vector2.ZERO
	return from.direction_to(path[path_index])

# A hátralévő út hossza: a fal mögött álló hős ne számítson "közelinek"
func remaining_path_length() -> float:
	if path_index >= path.size():
		return 0.0
	var length: float = feet.global_position.distance_to(path[path_index])
	for i in range(path_index, path.size() - 1):
		length += path[i].distance_to(path[i + 1])
	return length

func _on_animation_finished(anim_name: String) -> void:
	# Ha az idle2 ért véget (és közben nem indultunk el)
	if anim_name == "idle2" and velocity.length() == 0:
		is_playing_fidget = false
		idle2_timer = 0.0
		animation_player.play("idle1")
