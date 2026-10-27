extends CharacterBody2D

@onready var interaction_area: Area2D = $InteractionArea

# A név és a sorok fordítási kulcsok (localization/texts.csv); a dialógus ablak fordítja le őket
@export var npc_name: String = "NPC_OLD_SAGE_NAME"
@export var dialogue_lines: Array[String] = [
	"NPC_OLD_SAGE_GREETING_1",
	"NPC_OLD_SAGE_GREETING_2",
	"NPC_OLD_SAGE_GREETING_3",
]

## A dialógus után a lény erre a helyzetre mond valamit (pl. &"sage_hint"; üres = semmit)
@export var companion_reply: StringName = &""

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
	if not SignalBus.dialogue_finished.is_connected(_on_dialogue_finished):
		SignalBus.dialogue_finished.connect(_on_dialogue_finished, CONNECT_ONE_SHOT)

# Késleltetve, hogy a buborék már tudja, hogy véget ért a dialógus
func _on_dialogue_finished() -> void:
	SignalBus.npc_talked.emit(npc_name)
	if companion_reply != &"":
		SignalBus.companion_say.emit.call_deferred(companion_reply)
