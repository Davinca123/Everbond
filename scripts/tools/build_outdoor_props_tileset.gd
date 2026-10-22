extends SceneTree

# A városi csomag apró tárgyaiból (fák, bokrok, lámpák, padok, automaták ...) atlaszképet
# és TileSetet készít, hogy a pályákon csempeként lehessen festeni őket, mint a bútorokat.
# Minden tárgy egy több cellás csempe: a kép alja a blokk aljához igazodik, a talppontja
# (y_sort_origin) a kép alja, az ütközése pedig egy téglalap a kép aljánál.
#
# Futtatás (a projekt gyökeréből), utána egy --import, hogy a kép újra beolvasódjon:
#   godot --headless --path . -s res://scripts/tools/build_outdoor_props_tileset.gd
#
# FIGYELEM: a tárgyak sorrendje adja az atlasz-koordinátákat. Új tárgyat a lista VÉGÉRE
# vegyél fel, különben a már lefestett pályákon máshová mutatnak a csempék.

const SOURCE_DIR := "res://assets/Ranitaya’s 50+ City Essential Assets Pack/Assets/"
const ATLAS_PATH := "res://assets/outdoor_props.png"
const TILESET_PATH := "res://resources/tilesets/outdoor_props.tres"
const CELL := 16
## Az atlasz szélessége cellákban
const ATLAS_COLUMNS := 16

## file: a kép neve; foot: az ütköző talp mérete a kép pixeleiben;
## cx: a talp közepe a képen (ha nincs megadva, a kép közepe)
const PROPS := [
	{"file": "Tree1.png", "foot": Vector2(8, 4)},
	{"file": "Tree2.png", "foot": Vector2(8, 4)},
	{"file": "Tree3.png", "foot": Vector2(8, 4)},
	{"file": "Bush1.png", "foot": Vector2(22, 8)},
	{"file": "Bush2.png", "foot": Vector2(22, 8)},
	{"file": "Light Pole.png", "foot": Vector2(10, 3)},
	{"file": "Fire Hidrant.png", "foot": Vector2(12, 5)},
	{"file": "Sign1.png", "foot": Vector2(47, 10)},
	{"file": "Sign2.png", "foot": Vector2(40, 10)},
	{"file": "Closed Trashbin.png", "foot": Vector2(14, 6)},
	{"file": "Opened Trashbin.png", "foot": Vector2(20, 6), "cx": 19.0},
	{"file": "Trashbag.png", "foot": Vector2(18, 5)},
	{"file": "Green Vending Machine.png", "foot": Vector2(16, 8)},
	{"file": "Yellow Vending Machine.png", "foot": Vector2(16, 8)},
	{"file": "Red Vending machine.png", "foot": Vector2(26, 8)},
	{"file": "Beige Vending Machine.png", "foot": Vector2(30, 8)},
	{"file": "Horizental cardboard box.png", "foot": Vector2(16, 8)},
	{"file": "vertical cardboardbox.png", "foot": Vector2(16, 8)},
	{"file": "Opened Cardboard box.png", "foot": Vector2(16, 8)},
	{"file": "Circular table.png", "foot": Vector2(18, 5)},
	{"file": "Square table.png", "foot": Vector2(18, 5)},
	{"file": "Red Table.png", "foot": Vector2(22, 5)},
	{"file": "Front chair.png", "foot": Vector2(10, 4)},
	{"file": "Back chair.png", "foot": Vector2(10, 4)},
	{"file": "Side chair.png", "foot": Vector2(8, 4)},
	{"file": "Front red chair.png", "foot": Vector2(10, 4)},
	{"file": "Back red chair.png", "foot": Vector2(10, 4)},
	{"file": "Side red chair.png", "foot": Vector2(8, 4)},
	{"file": "Plant1.png", "foot": Vector2(10, 4)},
	{"file": "Plant2.png", "foot": Vector2(10, 4)},
	{"file": "Plant3.png", "foot": Vector2(10, 4)},
	{"file": "Plant4.png", "foot": Vector2(10, 4)},
	{"file": "Plant5.png", "foot": Vector2(10, 4)},
]

func _initialize() -> void:
	var tiles: Array[Dictionary] = []
	var cursor := Vector2i.ZERO
	var row_height := 0
	for prop in PROPS:
		var image := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_DIR + prop.file))
		image.convert(Image.FORMAT_RGBA8)
		# Csak a kép üres teteje marad le, az alja és a szélessége megmarad,
		# hogy a talp a kép aljához és közepéhez mérve ugyanott legyen.
		var top := image.get_used_rect().position.y
		var crop := Rect2i(0, top, image.get_width(), image.get_height() - top)
		var size := Vector2i(ceili(crop.size.x / float(CELL)), ceili(crop.size.y / float(CELL)))
		if cursor.x + size.x > ATLAS_COLUMNS:
			cursor = Vector2i(0, cursor.y + row_height)
			row_height = 0
		tiles.append({"prop": prop, "image": image, "crop": crop, "coords": cursor, "size": size})
		cursor.x += size.x
		row_height = maxi(row_height, size.y)

	var atlas := Image.create_empty(ATLAS_COLUMNS * CELL, (cursor.y + row_height) * CELL, false, Image.FORMAT_RGBA8)
	var lines: PackedStringArray = []
	for tile in tiles:
		var block_px: Vector2i = tile.size * CELL
		var crop: Rect2i = tile.crop
		var pad_x := (block_px.x - crop.size.x) / 2
		var dest: Vector2i = tile.coords * CELL + Vector2i(pad_x, block_px.y - crop.size.y)
		atlas.blit_rect(tile.image, crop, dest)

		# A csempe saját koordinátái a blokk közepétől számítódnak; a kép alja block_px.y / 2-nél van.
		var bottom := block_px.y / 2
		var foot: Vector2 = tile.prop.foot
		var cx: float = tile.prop.get("cx", crop.size.x / 2.0)
		var left := pad_x + cx - foot.x / 2.0 - block_px.x / 2.0
		var key := "%d:%d" % [tile.coords.x, tile.coords.y]
		if tile.size != Vector2i.ONE:
			lines.append("%s/size_in_atlas = Vector2i(%d, %d)" % [key, tile.size.x, tile.size.y])
		lines.append("%s/0 = 0" % key)
		lines.append("%s/0/y_sort_origin = %d" % [key, bottom])
		lines.append("%s/0/physics_layer_0/polygon_0/points = PackedVector2Array(%s, %s, %s, %s, %s, %s, %s, %s)" % [
			key, left, bottom - foot.y, left + foot.x, bottom - foot.y, left + foot.x, bottom, left, bottom,
		])

	atlas.save_png(ProjectSettings.globalize_path(ATLAS_PATH))

	var text := "[gd_resource type=\"TileSet\" format=3]\n\n"
	text += "[ext_resource type=\"Texture2D\" path=\"%s\" id=\"1_sheet\"]\n\n" % ATLAS_PATH
	text += "[sub_resource type=\"TileSetAtlasSource\" id=\"TileSetAtlasSource_props\"]\n"
	text += "texture = ExtResource(\"1_sheet\")\n"
	text += "texture_region_size = Vector2i(%d, %d)\n" % [CELL, CELL]
	text += "\n".join(lines) + "\n\n"
	text += "[resource]\n"
	text += "tile_size = Vector2i(%d, %d)\n" % [CELL, CELL]
	text += "physics_layer_0/collision_layer = 1\n"
	text += "sources/0 = SubResource(\"TileSetAtlasSource_props\")\n"
	var file := FileAccess.open(TILESET_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()

	for tile in tiles:
		print("%-30s atlas %s size %s" % [tile.prop.file, tile.coords, tile.size])
	quit()
