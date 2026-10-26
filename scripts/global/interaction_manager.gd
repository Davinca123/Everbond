# interaction_manager.gd
extends Node

# Egyszerre csak egy interakciós tárgy (NPC, ajtó, …) kapja meg a gombnyomást és
# irányítja a gombot: az, amelyiknek a hatósugarába a hős legutoljára lépett be.
# Ha abból kilép, a korábbi (még hatótávon belüli) tárgy lesz újra az aktuális.
#
# A tárgyak a hatósugaruk szélén hívják az enter()/exit()-et, és tudniuk kell:
#   interaction_type: String   – a gomb felirata (pl. "chat", "door_enter")
#   interact()                 – a gombnyomás
#   can_interact() -> bool     – (nem kötelező) most épp lehet-e vele mit kezdeni
# Ha a tárgy állapota megváltozik (pl. kinyílt az ajtó), hívja a refresh()-t.

# A hatótávon belüli tárgyak, a belépés sorrendjében (az utolsó az aktuális)
var in_range: Array[Node] = []
var dialogue_open: bool = false

func _ready() -> void:
	SignalBus.interaction_pressed.connect(_on_interaction_pressed)
	SignalBus.dialogue_started.connect(func(_speaker, _lines):
		dialogue_open = true
		refresh())
	SignalBus.dialogue_finished.connect(func():
		dialogue_open = false
		refresh())

func enter(node: Node) -> void:
	in_range.erase(node)
	in_range.append(node)
	refresh()

func exit(node: Node) -> void:
	in_range.erase(node)
	refresh()

# Az aktuális tárgy: a legutóbb belépett, amelyikkel most lehet mit kezdeni
func current() -> Node:
	for i in range(in_range.size() - 1, -1, -1):
		var node: Node = in_range[i]
		if not is_instance_valid(node) or not node.is_inside_tree():
			continue
		if not node.has_method("can_interact") or node.can_interact():
			return node
	return null

# A gomb megjelenítése az aktuális tárgy szerint (dialógus és pályaváltás alatt rejtve)
func refresh() -> void:
	in_range = in_range.filter(func(node): return is_instance_valid(node) and node.is_inside_tree())
	var node := current()
	if node and not dialogue_open and not SceneManager.changing:
		SignalBus.show_interaction_button.emit(node.interaction_type)
	else:
		SignalBus.hide_interaction_button.emit()

func _on_interaction_pressed() -> void:
	# Pályaváltás közben (elsötétítés) a gombnyomás még nem az új pálya tárgyainak szól
	if dialogue_open or SceneManager.changing:
		return
	var node := current()
	if node:
		node.interact()
		refresh()
