shader_type canvas_item;

// Egyszerre legfeljebb 2 zóna halványítható, mindegyik legfeljebb 16 csúcsponttal.
// Az i. hely pontjai a polygon_points[i * 16 .. i * 16 + point_counts[i]] tartományban vannak.
// A helyeket az opacity_polygon_zone.gd osztja ki és tölti fel; az üres hely point_counts értéke 0.
const int MAX_ZONES = 2;
const int MAX_POINTS = 16;
uniform vec2 polygon_points[32];
uniform int point_counts[2];
uniform float opacities[2];

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// Segédfüggvény: megnézi, hogy a pont a zóna sokszögén belül van-e (Ray-casting algoritmus)
bool is_point_in_zone(vec2 p, int zone) {
	int count = point_counts[zone];
	if (count < 3) return false;
	int base = zone * MAX_POINTS;
	bool inside = false;

	for (int i = 0; i < MAX_POINTS; i++) {
		if (i >= count) break;
		int j = (i + 1) % count;
		vec2 vi = polygon_points[base + i];
		vec2 vj = polygon_points[base + j];

		if (((vi.y > p.y) != (vj.y > p.y)) &&
			(p.x < (vj.x - vi.x) * (p.y - vi.y) / (vj.y - vi.y) + vi.x)) {
			inside = !inside;
		}
	}
	return inside;
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);

	// HAJSZÁLPONTOSAN csak a zónák sokszögein belül csökkentjük az opacity-t!
	// Ha több zóna is fedi a pontot, a leghalványabb számít.
	float opacity = 1.0;
	for (int zone = 0; zone < MAX_ZONES; zone++) {
		if (is_point_in_zone(world_pos, zone)) {
			opacity = min(opacity, opacities[zone]);
		}
	}
	tex_color.a *= opacity;

	COLOR = tex_color;
}
