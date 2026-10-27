extends Node

# --- DIALÓGUS JELZÉSEK ---
signal dialogue_started(speaker_name: String, lines: Array[String])
signal dialogue_finished

# --- IRÁNYÍTÁS JELZÉSEK ---
signal joystick_moved(direction: Vector2)
signal interaction_pressed
# Rövid koppintás a képernyőn (képernyő koordinátában), pl. a lény elküldéséhez
signal screen_tapped(screen_position: Vector2)

# Ez a két szignál kezeli az UI gomb megjelenítését és elrejtését
signal show_interaction_button(interaction_type: String)
signal hide_interaction_button

# --- BEÁLLÍTÁSOK ---
# A játék nyelve megváltozott (Settings.set_language), pl. "en" vagy "hu"
signal language_changed(language: String)

# --- NAVIGÁCIÓ ---
# Akkor küldjük, ha egy akadály eltűnt vagy megjelent (pl. kinyílt egy ajtó),
# így a navigációs hálót újra kell sütni
signal navigation_obstacles_changed

# --- KÍSÉRŐ / SZIMBIÓZIS JELZÉSEK ---
# A hős visszahívja a lényt (a visszahívó gomb vagy a Q billentyű)
signal companion_recalled
# Egy koppintásra elindult a cél felé
signal companion_sent(target: Vector2)
# Amíg a lény kint van, a koppintást nem fogadja el (fejrázás)
signal companion_tap_ignored
# Odaért a célhoz (vagy elakadt előtte), és elkezdett várni
signal companion_arrived
# Vége a várakozásnak; full: kivárta a teljes időt (nem hívták vissza, és a hős nem ment túl messzire)
signal companion_stay_finished(full: bool)
# Visszaért a hős mellé, újra lehet küldeni
signal companion_returned
# A hős adott egy jutalomfalatot a lénynek (a falat gomb vagy a T billentyű)
signal treat_given
# Változott a hős falatainak száma (PlayerData.treats)
signal treats_changed(count: int)
# Kérés a lénynek, hogy szóljon valamit erre a helyzetre (pl. &"gate_opened"); a mondatot
# a buborék választja (scenes/companion/speech_bubble.gd, localization/companion_lines.csv)
signal companion_say(trigger: StringName)
# A lény egyik képessége (pl. "stay") haladt vagy szintet lépett (PlayerData.companion_skills)
signal companion_skill_changed(skill: String, level: int, progress: int)
# Véget ért egy beszélgetés egy NPC-vel (a neve a fordítási kulcs, pl. "NPC_OLD_SAGE_NAME")
signal npc_talked(npc_name: String)
# Egy rejtvény eseménye (pl. &"old_gate": &"found", &"too_short", &"passed"), a küldetéseknek
signal puzzle_event(puzzle: StringName, event: StringName)
# Egy küldetés szakasza vagy szövege változott (a küldetés csomópontja, lásd scripts/quests/)
signal quest_changed(quest: Node)
# A lény hangulata (-1..1) és kötődése (0-tól) változott (CompanionState)
signal companion_mood_changed(mood: float)
signal companion_bond_changed(bond: float)
signal companion_obedience_changed(new_level: int)
signal companion_leveled_up(new_form: String)

# --- HARC ÉS ÉLET JELZÉSEK ---
signal player_health_changed(current_health: int, max_health: int)
signal player_died
