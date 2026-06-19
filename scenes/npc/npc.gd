extends CharacterBody2D

@onready var interaction_area: Area2D = $InteractionArea

@export var npc_name: String = "Öreg Bölcs"
@export var dialogue_lines: Array[String] = [
	"Üdvözöllek, utazó!",
	"A sötétség egyre jobban terjed a világban...",
	"Kérlek, légy nagyon óvatos az erdőben!"
]

var player_in_range: bool = false
var is_talking: bool = false
# Itt határozzuk meg, hogy ez egy beszélgetős NPC
var interaction_type: String = "chat" 

func _ready() -> void:
	# Szignálok bekötése az Area2D-hez
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	
	# Figyeljük, mikor nyomják meg a gombot az UI-on
	SignalBus.interaction_pressed.connect(_on_interaction_pressed)
	# Figyeljük, mikor ér véget a beszélgetés
	SignalBus.dialogue_finished.connect(_on_dialogue_finished)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_in_range = true
		if not is_talking:
			# Jelezzük az UI-nak, hogy mutassa a gombot a "chat" ikonnal/szöveggel
			SignalBus.show_interaction_button.emit(interaction_type)

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_in_range = false
		# Ha elmegyünk mellőle, elrejtjük a gombot
		SignalBus.hide_interaction_button.emit()

func _on_interaction_pressed() -> void:
	# Csak akkor reagál ez az NPC, ha a közelében vagyunk és épp nem beszélünk vele
	if player_in_range and not is_talking:
		is_talking = true
		# Amíg beszélünk, tüntessük el az interakciós gombot
		#SignalBus.hide_interaction_button.emit()
		# Elindítjuk a párbeszédet
		SignalBus.dialogue_started.emit(npc_name, dialogue_lines)

func _on_dialogue_finished() -> void:
	is_talking = false
	# Ha véget ért a párbeszéd, de a játékos MÉG MINDIG az NPC mellett áll,
	# tegyük vissza a gombot, hátha újra akar beszélni vele
	if player_in_range:
		SignalBus.show_interaction_button.emit(interaction_type)
