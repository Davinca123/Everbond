extends CharacterBody2D

# Beállítások
@export var follow_speed: float = 160.0 # Kicsit lassabb, mint a főhős
@export var min_distance: float = 60.0  # Milyen közel álljon meg a hőstől
@export var target_margin: float = 5.0  # Pontosság a kattintott célpontnál

# Hivatkozás a főhősre
@onready var player = $"../Player"
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite_2d: Sprite2D = $Sprite2D

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
	# Kiszámoljuk a távolságot és az irányt a Player felé
	var direction = player.global_position - global_position
	var distance = direction.length()
	
	# Ha messzebb van a hős, mint a megengedett minimum, utána megyünk
	if distance > min_distance:
		velocity = direction.normalized() * follow_speed
	else:
		velocity = Vector2.ZERO # Ha elég közel van, megáll

# 2. LOGIKA: Séta a kattintott pontra
func handle_goto_logic():
	var direction = click_target_pos - global_position
	var distance = direction.length()
	
	# Ha még nem értük el a pontot
	if distance > target_margin:
		velocity = direction.normalized() * follow_speed
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
	print("Lény: Indulok a koordinátára: ", target_pos)

func _on_animation_finished(anim_name: String) -> void:
	# Ha az idle2 ért véget (és közben nem indultunk el)
	if anim_name == "idle2" and velocity.length() == 0:
		is_playing_fidget = false
		idle2_timer = 0.0
		animation_player.play("idle1")
