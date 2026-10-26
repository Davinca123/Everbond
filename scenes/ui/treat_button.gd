extends TouchScreenButton

# Falat gomb: akkor látszik, ha a lény a hős mellett van és van még falat. Megnyomva
# (vagy PC-n a T, "give_treat" billentyűvel) a lény kap egy falatot (SignalBus.treat_given).
# A feliratán a falatok száma is ott van.

@onready var label: Label = $Label

var companion: Node
var dialogue_open: bool = false

func _ready() -> void:
	hide()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	SignalBus.treats_changed.connect(func(_count): update_label())
	SignalBus.language_changed.connect(func(_language): update_label())
	SignalBus.dialogue_started.connect(func(_s, _l): dialogue_open = true)
	SignalBus.dialogue_finished.connect(func(): dialogue_open = false)
	pressed.connect(_on_pressed)
	update_label()

func _process(_delta: float) -> void:
	if companion == null or not is_instance_valid(companion):
		companion = get_tree().get_first_node_in_group(&"companion")
	visible = can_give()

func can_give() -> bool:
	return companion != null and companion.is_inside_tree() and companion.is_next_to_player() \
			and PlayerData.treats > 0 and not dialogue_open and not SceneManager.changing

func update_label() -> void:
	label.text = "%s ×%d" % [tr("UI_GIVE_TREAT"), PlayerData.treats]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("give_treat") and can_give():
		get_viewport().set_input_as_handled()
		_on_pressed()

func _on_pressed() -> void:
	if PlayerData.use_treat():
		SignalBus.treat_given.emit()
