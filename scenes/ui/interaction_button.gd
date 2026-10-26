extends TouchScreenButton

# Ha raktál alá egy Label-t a feliratnak, így éred el:
@onready var label: Label = $Label 

# A gomb feliratának fordítási kulcsa interakció típusonként (localization/texts.csv)
const LABEL_KEYS: Dictionary = {
	"chat": "UI_INTERACT_CHAT",
	"loot": "UI_INTERACT_LOOT",
	"chest": "UI_INTERACT_CHEST",
	"door_enter": "UI_INTERACT_DOOR_ENTER",
}

func _ready() -> void:
	hide() # Alapból elrejtjük magunkat
	
	# Maga a gomb iratkozik fel a globális eseményekre
	SignalBus.show_interaction_button.connect(_on_show_interaction)
	SignalBus.hide_interaction_button.connect(_on_hide_interaction)
	
	# Magához köti a saját megnyomását
	pressed.connect(_on_pressed)

func _on_show_interaction(type: String) -> void:
	show()
	# A Label a kulcsot magától lefordítja, nyelvváltáskor is
	label.text = LABEL_KEYS.get(type, "UI_INTERACT")

func _on_hide_interaction() -> void:
	hide()

# PC-n az "interact" billentyű (E, szóköz, Enter) is megnyomja a gombot, amíg látszik.
# Az _unhandled_input-ban: ha épp dialógus van, azt a dialógus ablak már lekezelte.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_on_pressed()

func _on_pressed() -> void:
	# Ha megnyomtak, jelzi a SignalBus-on az NPC-nek
	SignalBus.interaction_pressed.emit()
