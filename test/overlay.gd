extends Node2D
# Hibakereső rajz a tesztvezérlőhöz: navigációs háló (kék = 1-es, rózsaszín = 2-es szint),
# szintváltó zónák (sárga = EnterZone, narancs = ShaderZone), a hős (zöld) és a lény (piros)
# lába, a lény útja és a sorban álló szintváltó pontjai (sárga kör).
# LAYER=1 vagy 2: csak az adott szint hálóját rajzolja
var world: Node
func _process(_d): queue_redraw()
func _draw():
	var cols = {1: Color(0.2, 0.6, 1, 0.25), 2: Color(1, 0.3, 0.8, 0.25)}
	var only = int(OS.get_environment("LAYER")) if OS.get_environment("LAYER") != "" else 0
	for r in world.find_children("*", "NavigationRegion2D", true, false):
		if only and r.navigation_layers != only: continue
		var np: NavigationPolygon = r.navigation_polygon
		if np == null: continue
		var verts = np.get_vertices()
		for i in np.get_polygon_count():
			var poly = PackedVector2Array()
			for idx in np.get_polygon(i): poly.append(r.to_global(verts[idx]))
			var c: Color = cols[r.navigation_layers]
			draw_colored_polygon(poly, Color(c, 0.12))
			poly.append(poly[0])
			draw_polyline(poly, Color(c, 0.8), 2)
	for z in world.find_children("*", "CollisionPolygon2D", true, false):
		if z.get_parent().get_script() == null or not z.get_parent().has_method("set_character_to_underground"): continue
		var poly = PackedVector2Array()
		for p in z.polygon: poly.append(z.to_global(p))
		if poly.is_empty(): continue
		poly.append(poly[0])
		draw_polyline(poly, Color.YELLOW if z.name.begins_with("Enter") else Color.ORANGE, 6 if z.name.begins_with("Enter") else 3)
	var pl = world.get_node("YSort_Entities/Player"); var cp = world.get_node("YSort_Entities/Companion")
	draw_circle(pl.get_node("CollisionShape2D").global_position, 14, Color.GREEN)
	draw_circle(cp.get_node("CollisionShape2D").global_position, 14, Color.RED)
	if cp.path.size() > 1:
		draw_polyline(cp.path, Color.RED, 4)
	for c in cp.level_crossings:
		draw_circle(c.position, 18, Color.YELLOW)
