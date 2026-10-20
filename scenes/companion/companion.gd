extends CharacterBody2D

# Beállítások
@export var follow_speed: float = 160.0 # Kicsit lassabb, mint a főhős
@export var min_distance: float = 60.0  # Milyen közel álljon meg a hőstől
@export var target_margin: float = 5.0  # Pontosság a kattintott célpontnál
## Koppintott célnál ennyit vár (mp), mielőtt visszamegy a hőshöz.
## Később a lény tanításával ("maradj!") nőhet.
@export var stay_duration: float = 2.0

# Útkeresés: ilyen gyakran számoljuk újra az utat (mp), és ilyen közel kell érni egy útponthoz
const REPATH_INTERVAL: float = 0.25
const WAYPOINT_REACHED_DISTANCE: float = 8.0
# Szintváltásnál ennyivel a hős átlépési pontja mögé célzunk, hogy a lény teste
# biztosan belépjen a szintváltó zónába (a hős kapszulája magasabb, előbb ér bele)
const CROSSING_OVERSHOOT: float = 64.0
# A szintváltó zóna előtti pont távolsága: eddig a régi szint hálóján jövünk,
# onnan egyenesen megyünk át (a zóna mögötti pont a régi szint hálóján akár egy
# egészen más helyen, pl. a hídon/fennsíkon lehet elérhető)
const CROSSING_APPROACH: float = 32.0
# A várakozás visszaszámlálása: vékony szürke csík a lény feje fölött, ami fogy
const STAY_BAR_WIDTH: float = 40.0
const STAY_BAR_THICKNESS: float = 4.0
const STAY_BAR_OFFSET: Vector2 = Vector2(0, -85) # a csík közepe a lény origójához (a talpához) képest (épp a fül fölött)
const STAY_BAR_COLOR: Color = Color(0.75, 0.75, 0.75, 0.9)
const STAY_BAR_BACKGROUND_COLOR: Color = Color(0.2, 0.2, 0.2, 0.4)
# A koppintott cél jelölése a földön, amíg a lény oda nem ér
const TARGET_MARKER_TEXTURE: Texture2D = preload("res://scenes/companion/companion_spot_marker.png")
const TARGET_MARKER_SCALE: Vector2 = Vector2(5, 5) # mint a lény sprite-ja, hogy a pixelméret egyezzen
# A jelölő a YSort_Entities alatt van, és ennyivel feljebb rendezzük, mint ahol látszik:
# így a rajta/mellette álló karakterek fölé kerülnek (az origójuk a talpuknál van, legfeljebb ~40 px-rel a cél alatt)
const TARGET_MARKER_SORT_LIFT: float = 100.0
# Ha a célpont felé ennyi ideig nem jut előre (fal mögötti cél), feladja (mp)
const GOTO_STUCK_TIME: float = 1.0
# Ennyivel kell csökkennie a hátralévő útnak, hogy előrehaladásnak számítson
const GOTO_PROGRESS_DISTANCE: float = 10.0
# Egy pont akkor van egy szint hálóján, ha a háló legközelebbi pontja ennyin belül van
const NAV_REACH: float = 40.0

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

# Szintváltó pontok, sorrendben: ezeken át jut el a lény a hős szintjére, mert a
# navigációs háló szintenként külön van. A hős szintváltásai a sor végére kerülnek,
# a lény saját (pl. koppintásra történt) szintváltásai a sor elejére, visszaútként.
# Elemei: { "at": Vector2, "approach": Vector2, "position": Vector2, "level": int, "approached": bool }
# at: ahol a váltás történt, approach: a zóna előtt (régi szint), position: a zóna
# mögött, level: a váltás utáni szint.
var level_crossings: Array[Dictionary] = []
var last_player_level: int = 0
var last_level: int = 0

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
var wait_timer: float = 0.0
var stay_bar_shown: bool = false
var target_marker: Node2D
var goto_stuck_timer: float = 0.0
var goto_best_distance: float = INF
# Koppintásnál a szintváltó kapuk, amiken át a legrövidebb út vezet a célhoz (lásd plan_crossings)
var goto_crossings: Array[Dictionary] = []

func _ready() -> void:
	# BIZTONSÁGI CSERE: Leválasztjuk a régit (ha volt), és tisztán kódból kötjük össze
	animation_player.animation_finished.connect(_on_animation_finished)
	target_marker = create_target_marker()
	get_parent().add_child.call_deferred(target_marker)
	last_player_level = get_level(player)
	last_level = get_level(self)
			

func _physics_process(delta):
	repath_timer -= delta
	# Várakozás közben (és egyszer utána, hogy eltűnjön) újrarajzoljuk a csíkot
	if current_state == State.IDLE or stay_bar_shown:
		queue_redraw()
	update_target_marker()
	track_level_changes()
	match current_state:
		State.FOLLOW:
			handle_follow_logic()
		State.GO_TO_TARGET:
			handle_goto_logic(delta)
		State.IDLE:
			velocity = Vector2.ZERO
			# Kis várakozás után visszaszalad a hőshöz
			wait_timer -= delta
			if wait_timer <= 0.0:
				current_state = State.FOLLOW
				# Ha a hős szintjén vagyunk, de a hozzá vezető legrövidebb út más szinten át
				# visz (pl. az alagúton jöttünk ide), azon megyünk vissza
				if level_crossings.is_empty():
					level_crossings = plan_crossings(player_feet.global_position, get_level(player))
			
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
	# Ha a hős másik szintre ment, előbb az ő nyomában a szintváltó ponthoz megyünk
	if not level_crossings.is_empty():
		if walk_crossing(level_crossings[0]):
			level_crossings.pop_front()
			repath_timer = 0.0
		else:
			return

	# A navigációs hálón keresünk utat a hős lábához, így a falakat is megkerüli
	update_path(player_feet.global_position)

	# Ha messzebb van a hős (az úton mérve), mint a megengedett minimum, utána megyünk
	if remaining_path_length() > min_distance:
		velocity = path_direction() * follow_speed
	else:
		velocity = Vector2.ZERO # Ha elég közel van, megáll

# 2. LOGIKA: Séta a kattintott pontra
func handle_goto_logic(delta: float):
	# Ha a cél felé vezető legrövidebb út más szinten át visz (pl. az alagúton),
	# előbb sorban átmegyünk a kapukon
	if not goto_crossings.is_empty():
		var crossing: Dictionary = goto_crossings[0]
		if walk_crossing(crossing):
			goto_crossings.pop_front()
			repath_timer = 0.0
			goto_best_distance = INF
			goto_stuck_timer = 0.0
			return
		var to_crossing: float = feet.global_position.distance_to(crossing.position) if crossing.approached else remaining_path_length()
		if is_goto_stuck(to_crossing, delta):
			arrive()
		return

	update_path(click_target_pos)

	# Ha nem jutunk előre (pl. a cél fal mögött van, és nincs navigációs háló), feladjuk.
	# A hátralévő út hosszát figyeljük, nem a sebességet, mert a fal mentén csúszva is mozog.
	var remaining: float = remaining_path_length()
	var stuck: bool = is_goto_stuck(remaining, delta)

	# Ha még nem értük el a pontot
	if remaining > target_margin and not stuck:
		velocity = path_direction() * follow_speed
	else:
		arrive()

# Igaz, ha a hátralévő út GOTO_STUCK_TIME óta nem rövidült
func is_goto_stuck(remaining: float, delta: float) -> bool:
	if remaining < goto_best_distance - GOTO_PROGRESS_DISTANCE:
		goto_best_distance = remaining
		goto_stuck_timer = 0.0
	else:
		goto_stuck_timer += delta
	return goto_stuck_timer >= GOTO_STUCK_TIME

# Megérkeztünk! Átváltunk IDLE (várakozó) állapotba, majd stay_duration
# után visszaszalad a hőshöz (időzítő változóval, így egy új koppintás
# nem rövidíti le a következő várakozást)
func arrive() -> void:
	velocity = Vector2.ZERO
	goto_crossings.clear()
	current_state = State.IDLE
	wait_timer = stay_duration
	print("Lény: Megérkeztem a célhoz!")

# Ezt a függvényt a fő Game kód fogja meghívni, ha a játékos kattintott
func send_to_position(target_pos: Vector2):
	click_target_pos = target_pos
	current_state = State.GO_TO_TARGET
	goto_stuck_timer = 0.0
	goto_best_distance = INF
	repath_timer = 0.0 # Azonnal új utat számolunk az új célhoz
	goto_crossings = plan_crossings(target_pos)
	print("Lény: Indulok a koordinátára: ", target_pos)

# --- ÚTKERESÉS ---

# Újraszámolja az utat a célig, de csak REPATH_INTERVAL-onként.
# exact_target: a háló széle után egyenesen továbbmegyünk a célig (szintváltó zónába
# lépéshez kell, mert a háló az agent_radius miatt a zóna előtt véget érhet)
# then: ha meg van adva, a cél után egyenesen ide megyünk tovább (át a zónán)
func update_path(target: Vector2, exact_target: bool = false, then = null) -> void:
	if repath_timer > 0.0 and not path.is_empty():
		return
	repath_timer = REPATH_INTERVAL

	var nav_map: RID = get_world_2d().navigation_map
	path = NavigationServer2D.map_get_path(nav_map, feet.global_position, target, true, get_navigation_layers())
	path_index = 0
	# Nincs navigációs háló (pl. belső tér) -> egyenesen megyünk a célhoz, mint régen
	if path.is_empty():
		path = PackedVector2Array([feet.global_position, target])
	elif exact_target and path[path.size() - 1].distance_to(target) > 1.0:
		path.append(target)
	if then != null:
		path.append(then)

# A Lenti/Fenti szint ütközési maszkjához tartozó navigációs réteget használjuk
func get_navigation_layers() -> int:
	return get_level(self)

# Egy karakter szintje = az ütközési maszkjának Lenti/Fenti bitjei (egyben a navigációs réteg)
func get_level(body: CollisionObject2D) -> int:
	var level: int = 0
	if body.get_collision_mask_value(1):
		level |= 1
	if body.get_collision_mask_value(2):
		level |= 2
	return level

# --- SZINTVÁLTÁS KÖVETÉSE ---

# A szintváltó zónák (alagút, lépcső) a maszkot állítják át, ezt figyeljük mindkét karakteren
func track_level_changes() -> void:
	var player_level: int = get_level(player)
	if player_level != last_player_level:
		last_player_level = player_level
		add_level_crossing(player_level)

	var level: int = get_level(self)
	if level != last_level:
		# Ha nem a soron következő pont felé léptünk át (pl. koppintásra mentünk be az
		# udvar alá), megjegyezzük a visszautat, különben a hős alatt ragadnánk
		if level_crossings.is_empty() or level_crossings[0].level != level:
			level_crossings.push_front(make_crossing(feet.global_position, -velocity.normalized(), last_level))
		last_level = level
		repath_timer = 0.0 # Új szint, új navigációs háló -> azonnal új út
		# Az új szinten az út hossza más (pl. a lépcsőn kerülve hosszabb), ezért az
		# elakadásfigyelés elölről kezdi, különben a régi, rövidebb úthoz mérve feladná
		goto_best_distance = INF
		goto_stuck_timer = 0.0
		# A koppintott úton következő kapun átjutottunk
		if not goto_crossings.is_empty() and goto_crossings[0].level == level:
			goto_crossings.pop_front()

	# Ha már azon a szinten vagyunk, ahová a soron következő pont vezet, átléptük:
	# jöhet a következő pont, vagy ha nincs több, közvetlenül a hős
	if not level_crossings.is_empty() and level_crossings[0].level == level:
		level_crossings.pop_front()
		repath_timer = 0.0

func add_level_crossing(new_level: int) -> void:
	# Az átlépés iránya: amerre a hős ment, abba az irányba lépünk túl a ponton
	var crossing: Dictionary = make_crossing(player_feet.global_position, player.velocity.normalized(), new_level)

	# Ha ugyanazon a kapun visszafelé visz, mint az előző pont, a kettő kioltja egymást:
	# pl. a hős ki-be ment, mielőtt a lény odaért, vagy a lény már bement oda, ahová most a hős
	if not level_crossings.is_empty():
		var previous: Dictionary = level_crossings.back()
		if previous.level != new_level and previous.at.distance_to(crossing.at) < CROSSING_OVERSHOOT * 3.0:
			level_crossings.pop_back()
			repath_timer = 0.0
			return

	level_crossings.append(crossing)
	repath_timer = 0.0

# Szintváltó pont: at = ahol a váltás történt, direction = az átlépés iránya, level = a cél szint
func make_crossing(at: Vector2, direction: Vector2, level: int) -> Dictionary:
	return {
		"at": at,
		"approach": at - direction * CROSSING_APPROACH,
		"position": at + direction * CROSSING_OVERSHOOT,
		"level": level,
		"approached": false, # elérte-e már a lény a zóna előtti pontot
	}

# Átvezet egy szintváltó ponton: előbb a régi szint hálóján a zóna elé, onnan egyenesen át.
# Igazat ad, ha a zóna mögé értünk, de nem váltott szintet: ekkor a pontot el kell dobni,
# hogy ne ragadjunk itt örökre.
func walk_crossing(crossing: Dictionary) -> bool:
	if feet.global_position.distance_to(crossing.position) < WAYPOINT_REACHED_DISTANCE:
		return true
	if feet.global_position.distance_to(crossing.approach) < WAYPOINT_REACHED_DISTANCE:
		crossing.approached = true
	# A zóna előtti pontról már egyenesen megyünk át: az újratervezés ne küldjön
	# vissza oda, mert a kis kapszulájú hős átlépési pontja a zónán belül lehet,
	# és a lény sosem jutna ki belőle
	if crossing.approached:
		velocity = feet.global_position.direction_to(crossing.position) * follow_speed
	else:
		update_path(crossing.approach, true, crossing.position)
		velocity = path_direction() * follow_speed
	return false

# --- ÚTVONALTERVEZÉS SZINTEKEN ÁT (koppintásnál és a hőshöz visszatérésnél) ---

# A navigációs háló szintenként külön van, ezért a szinten belüli út néha nagy kerülő
# (pl. az alagút helyett a hegy körül). A szintváltó kapukon (az átlátszósági zónák
# EnterZone sávjain) át keressük a legrövidebb utat a célig (Dijkstra), és visszaadjuk
# a kapukon átvezető szintváltó pontokat, sorrendben. Üres, ha a szinten maradó út a legrövidebb.
# target_level: a cél szintje; ha nincs megadva, a háló alapján döntjük el (get_target_levels)
func plan_crossings(target: Vector2, target_level: int = 0) -> Array[Dictionary]:
	var start_level: int = get_level(self)
	# Csomópontok: a lény, a cél (minden szinten, ahol lehet), és minden kapu két oldala
	var nodes: Array[Dictionary] = [{ "position": feet.global_position, "level": start_level, "target": false }]
	var levels: Array[int] = [start_level]
	# Kapun át: csomópont -> [a kapu túloldala, a hozzá tartozó szintváltó pont]
	var links: Dictionary = {}
	for zone in get_tree().get_nodes_in_group("opacity_zones"):
		for portal in zone.portals:
			var outside: int = nodes.size()
			var inside: int = outside + 1
			nodes.append({ "position": portal.center - portal.inward * CROSSING_APPROACH, "level": portal.outside_level, "target": false })
			nodes.append({ "position": portal.center + portal.inward * CROSSING_APPROACH, "level": portal.inside_level, "target": false })
			links[outside] = [inside, make_crossing(portal.center, portal.inward, portal.inside_level)]
			links[inside] = [outside, make_crossing(portal.center, -portal.inward, portal.outside_level)]
			for level in [portal.outside_level, portal.inside_level]:
				if not levels.has(level):
					levels.append(level)
	if links.is_empty():
		return []
	for level in [target_level] if target_level != 0 else get_target_levels(target, start_level, levels):
		nodes.append({ "position": target, "level": level, "target": true })

	var distance: Array[float] = []
	distance.resize(nodes.size())
	distance.fill(INF)
	distance[0] = 0.0
	var previous: Array[int] = []
	previous.resize(nodes.size())
	previous.fill(-1)
	var done: Array[bool] = []
	done.resize(nodes.size())
	done.fill(false)
	var reached: int = -1
	while true:
		var current: int = -1
		for i in nodes.size():
			if not done[i] and distance[i] < INF and (current < 0 or distance[i] < distance[current]):
				current = i
		if current < 0:
			break
		if nodes[current].target:
			reached = current
			break
		done[current] = true
		# Ugyanazon a szinten a háló menti út hossza
		for i in nodes.size():
			if not done[i] and nodes[i].level == nodes[current].level:
				var length: float = distance[current] + nav_path_length(nodes[current].position, nodes[i].position, nodes[current].level)
				if length < distance[i]:
					distance[i] = length
					previous[i] = current
		# Át a kapun a másik szintre
		if links.has(current):
			var other: int = links[current][0]
			var length: float = distance[current] + CROSSING_APPROACH * 2.0
			if not done[other] and length < distance[other]:
				distance[other] = length
				previous[other] = current

	var crossings: Array[Dictionary] = []
	var node: int = reached
	while node > 0:
		var from: int = previous[node]
		if links.has(from) and links[from][0] == node and nodes[from].level != nodes[node].level:
			crossings.push_front(links[from][1].duplicate())
		node = from
	return crossings

# Melyik szinten lehet a cél: ha a lény szintjén is rajta van a hálón, ott (mint eddig),
# különben azokon a szinteken, ahol rajta van. Ha sehol, a lény szintjén.
func get_target_levels(target: Vector2, start_level: int, levels: Array[int]) -> Array[int]:
	if is_on_level(target, start_level):
		return [start_level]
	var on_levels: Array[int] = []
	for level in levels:
		if level != start_level and is_on_level(target, level):
			on_levels.append(level)
	return on_levels if not on_levels.is_empty() else [start_level]

func is_on_level(point: Vector2, level: int) -> bool:
	var path_on_level: PackedVector2Array = NavigationServer2D.map_get_path(get_world_2d().navigation_map, point, point, true, level)
	return not path_on_level.is_empty() and path_on_level[0].distance_to(point) < NAV_REACH

# Az út hossza egy szint hálóján; INF, ha a két pont nincs összekötve
func nav_path_length(from: Vector2, to: Vector2, level: int) -> float:
	var nav_path: PackedVector2Array = NavigationServer2D.map_get_path(get_world_2d().navigation_map, from, to, true, level)
	if nav_path.is_empty() or nav_path[0].distance_to(from) > NAV_REACH or nav_path[nav_path.size() - 1].distance_to(to) > NAV_REACH:
		return INF
	var length: float = 0.0
	for i in nav_path.size() - 1:
		length += nav_path[i].distance_to(nav_path[i + 1])
	return length

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

# --- CÉLJELÖLŐ ---

func create_target_marker() -> Node2D:
	var marker := Node2D.new()
	marker.name = "CompanionTargetMarker"
	marker.visible = false
	var sprite := Sprite2D.new()
	sprite.texture = TARGET_MARKER_TEXTURE
	sprite.scale = TARGET_MARKER_SCALE
	sprite.position = Vector2(0, TARGET_MARKER_SORT_LIFT)
	marker.add_child(sprite)
	return marker

# Csak amíg a koppintott cél felé tart; a z_index a lényét követi (alagútban a híd eltakarja)
func update_target_marker() -> void:
	target_marker.visible = current_state == State.GO_TO_TARGET
	if target_marker.visible:
		target_marker.global_position = click_target_pos - Vector2(0, TARGET_MARKER_SORT_LIFT)
		target_marker.z_index = z_index

# A várakozás hátralévő ideje: balról jobbra fogyó szürke csík a lény feje fölött
func _draw() -> void:
	stay_bar_shown = current_state == State.IDLE and stay_duration > 0.0
	if not stay_bar_shown:
		return
	var ratio: float = clampf(wait_timer / stay_duration, 0.0, 1.0)
	var left := STAY_BAR_OFFSET - Vector2(STAY_BAR_WIDTH / 2.0, 0)
	draw_line(left, left + Vector2(STAY_BAR_WIDTH, 0), STAY_BAR_BACKGROUND_COLOR, STAY_BAR_THICKNESS)
	if ratio > 0.0:
		draw_line(left, left + Vector2(STAY_BAR_WIDTH * ratio, 0), STAY_BAR_COLOR, STAY_BAR_THICKNESS)

func _on_animation_finished(anim_name: String) -> void:
	# Ha az idle2 ért véget (és közben nem indultunk el)
	if anim_name == "idle2" and velocity.length() == 0:
		is_playing_fidget = false
		idle2_timer = 0.0
		animation_player.play("idle1")
