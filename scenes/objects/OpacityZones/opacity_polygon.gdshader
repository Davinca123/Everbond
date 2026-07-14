shader_type canvas_item;

// Maximum 8 csúcspontból álló sokszög (ha kevesebb kell, a többit nullán hagyjuk)
uniform vec2 polygon_points[8];
uniform int point_count = 0;
uniform float opacity = 1.0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// Segédfüggvény: megnézi, hogy a pont a sokszögön belül van-e (Ray-casting algoritmus)
bool is_point_in_polygon(vec2 p) {
	if (point_count < 3) return false;
	bool inside = false;
	
	for (int i = 0; i < point_count; i++) {
		int j = (i + 1) % point_count;
		vec2 vi = polygon_points[i];
		vec2 vj = polygon_points[j];
		
		if (((vi.y > p.y) != (vj.y > p.y)) && 
			(p.x < (vj.x - vi.x) * (p.y - vi.y) / (vj.y - vi.y) + vi.x)) {
			inside = !inside;
		}
	}
	return inside;
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	if (is_point_in_polygon(world_pos)) {
		// HAJSZÁLPONTOSAN csak a sokszögön belül csökkentjük az opacity-t!
		tex_color.a *= opacity;
	}
	
	COLOR = tex_color;
}

