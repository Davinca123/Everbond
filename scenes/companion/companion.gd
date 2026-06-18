extends CharacterBody2D

# Beállítások
@export var follow_speed: float = 160.0 # Kicsit lassabb, mint a főhős
@export var min_distance: float = 60.0  # Milyen közel álljon meg a hőstől
@export var target_margin: float = 5.0  # Pontosság a kattintott célpontnál

# Hivatkozás a főhősre
@onready var player = $"../Player"

# Állapotok (Enums)
enum State { FOLLOW, GO_TO_TARGET, IDLE }
var current_state : State = State.FOLLOW

# Változók a kattintásos mozgáshoz
var click_target_pos : Vector2 = Vector2.ZERO

func _physics_process(delta):
	match current_state:
		State.FOLLOW:
			handle_follow_logic()
		State.GO_TO_TARGET:
			handle_goto_logic()
		State.IDLE:
			velocity = Vector2.ZERO
			
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
