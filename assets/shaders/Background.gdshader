shader_type canvas_item;

// ナイトスタジアム風の背景
// 暗いチャコールのグラデーション + フラッドライトの光芒 + 芝目ストライプ + 赤のグロー
uniform vec4 top_color : source_color = vec4(0.035, 0.04, 0.065, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.10, 0.035, 0.045, 1.0);
uniform vec4 beam_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float beam_strength : hint_range(0.0, 0.5) = 0.10;
uniform vec4 accent_color : source_color = vec4(0.9, 0.08, 0.14, 1.0);
uniform float accent_strength : hint_range(0.0, 0.5) = 0.12;
uniform float sway_speed : hint_range(0.0, 1.0) = 0.15;

// 上方から差すサーチライト風の光芒（コーン状に広がる）
float beam(vec2 uv, vec2 origin, float angle, float width) {
	vec2 dir = vec2(sin(angle), cos(angle));
	vec2 p = uv - origin;
	float along = dot(p, dir);
	float perp = abs(dot(p, vec2(dir.y, -dir.x)));
	float w = width * (0.25 + along);
	float i = smoothstep(w, w * 0.15, perp);
	i *= smoothstep(0.0, 0.2, along) * smoothstep(1.7, 0.5, along);
	return max(i, 0.0);
}

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(top_color.rgb, bottom_color.rgb, uv.y * uv.y);

	// フラッドライト2本（ゆっくり左右にスイング）
	float t = TIME * sway_speed;
	col += beam_color.rgb * beam(uv, vec2(0.12, -0.08),  0.35 + sin(t) * 0.05, 0.16) * beam_strength;
	col += beam_color.rgb * beam(uv, vec2(0.88, -0.08), -0.35 + cos(t * 0.8) * 0.05, 0.16) * beam_strength * 0.85;

	// 画面下部にうっすら芝目（ピッチ）ストライプ
	if (uv.y > 0.62) {
		float band = step(1.0, mod(floor((uv.x + uv.y * 0.35) * 9.0), 2.0));
		float fade = smoothstep(0.62, 0.8, uv.y);
		col += vec3(1.0) * band * fade * 0.012;
	}

	// 下端に赤のグロー（チームカラー）
	col += accent_color.rgb * smoothstep(0.72, 1.08, uv.y) * accent_strength;

	// ビネット
	float vig = smoothstep(1.2, 0.35, distance(uv, vec2(0.5, 0.45)));
	col *= mix(0.7, 1.0, vig);

	COLOR = vec4(col, 1.0);
}
