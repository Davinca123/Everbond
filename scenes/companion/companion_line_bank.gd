class_name CompanionLineBank extends RefCounted

# A lény mondatainak tára (docs/companion-nature.md, 4. rész): localization/companion_lines.csv.
# Soronként egy mondat: key (fordítási kulcs a texts.csv-ben), trigger (a helyzet),
# min_mood, max_mood, min_bond (mikor mondhatja), weight (súly a választásnál),
# cooldown (ennyi mp-ig nem mondja újra).
# Választás: a feltételeknek megfelelő, nem hűlő mondatok közül súly szerint, véletlenszerűen.

var lines: Array[Dictionary] = []
# kulcs -> mikor mondta utoljára (mp)
var last_said: Dictionary = {}

static func load_csv(path: String) -> CompanionLineBank:
	var bank := CompanionLineBank.new()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("CompanionLineBank: nem olvasható: %s" % path)
		return bank
	var header := file.get_csv_line()
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < header.size() or row[0] == "":
			continue
		var line: Dictionary = {}
		for i in header.size():
			line[header[i]] = row[i]
		bank.lines.append({
			"key": line.key,
			"trigger": StringName(line.trigger),
			"min_mood": float(line.min_mood),
			"max_mood": float(line.max_mood),
			"min_bond": float(line.min_bond),
			"weight": float(line.weight),
			"cooldown": float(line.cooldown),
		})
	return bank

func has_trigger(trigger: StringName) -> bool:
	return lines.any(func(line): return line.trigger == trigger)

# Egy illő mondat kulcsa, vagy üres, ha most nincs mit mondani
func pick(trigger: StringName, mood: float, bond: float, now: float) -> String:
	var candidates: Array[Dictionary] = []
	var total: float = 0.0
	for line in lines:
		if line.trigger != trigger or mood < line.min_mood or mood > line.max_mood or bond < line.min_bond:
			continue
		if last_said.has(line.key) and now - last_said[line.key] < line.cooldown:
			continue
		candidates.append(line)
		total += line.weight
	if candidates.is_empty():
		return ""
	var roll: float = randf() * total
	var chosen: Dictionary = candidates.back()
	for line in candidates:
		roll -= line.weight
		if roll < 0.0:
			chosen = line
			break
	last_said[chosen.key] = now
	return chosen.key
