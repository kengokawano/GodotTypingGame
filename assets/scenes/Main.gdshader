shader_type canvas_item;

// 透過したい色を指定（ここでは緑）
uniform vec4 key_color : source_color = vec4(0.0, 1.0, 0.0, 1.0);
// 色の許容誤差
uniform float threshold : hint_range(0.0, 0.5) = 0.08;

void fragment() {
    vec4 c = texture(TEXTURE, UV);
    float d = distance(c.rgb, key_color.rgb);
    if (d < threshold) {
        COLOR = vec4(c.rgb, 0.0); // 透明化
    } else {
        COLOR = c;
    }
}
