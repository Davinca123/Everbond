shader_type canvas_item;

// A zóna GLOBÁLIS koordinátái (pixelpontosan)
uniform vec2 zone_min;
uniform vec2 zone_max;
uniform float opacity = 1.0;

// Ezzel a speciális függvénnyel kiszámoljuk a pixel valódi helyét a világban
varying vec2 world_pos;

void vertex() {
	// Kiszámoljuk a csempe pixelének pontos globális helyzetét a térképen
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Most már a valódi világ koordinátákat hasonlítjuk össze!
	if (world_pos.x >= zone_min.x && world_pos.x <= zone_max.x && world_pos.y >= zone_min.y && world_pos.y <= zone_max.y) {
		tex_color.a *= opacity;
	}
	
	COLOR = tex_color;
}
