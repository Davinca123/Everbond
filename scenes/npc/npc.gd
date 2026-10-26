extends CharacterBody2D

@onready var interaction_area: Area2D = $InteractionArea

@export var npc_name: String = "Öreg Bölcs"
@export var dialogue_lines: Array[String] = [
	"Üdvözöllek, utazó!",
	"A sötétség egyre jobban terjed a világban...",
	"Kérlek, légy nagyon óvatos az erdőben!"
]

# Itt határozzuk meg, hogy ez egy beszélgetős NPC
var interaction_type: String = "chat" 

func _ready() -> void:
	# Szignálok bekötése az Area2D-hez
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

# A gombot és a gombnyomást az InteractionManager osztja ki; a dialógus alatt elrejti
# a gombot, utána visszateszi, ha a hős még mindig itt áll
func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		InteractionManager.enter(self)

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		InteractionManager.exit(self)

func interact() -> void:
	SignalBus.dialogue_started.emit(npc_name, dialogue_lines)
