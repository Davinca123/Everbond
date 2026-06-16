shader_type canvas_item;

void fragment() {
    vec4 col = texture(TEXTURE, UV);
    // Ha a pixel nagyon közel van a fehérhez (vörös, zöld és kék is 0.9 felett van)
    if (col.r > 0.95 && col.g > 0.9 && col.b > 0.9) {
        col.a = 0.0; // Teljesen átlátszóvá tesszük
    }
    COLOR = col;
}
