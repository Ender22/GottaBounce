shader_type canvas_item;
// WK-66a sports net FRAME sprites (docs/briefs/sports_nets_2026-11-15.md sections 5 + 8).
//   tint_mode 0: plain multiply (Dropshot per-court modulate on the white volleyball set).
//   tint_mode 1: the fx_tint.gdshader gradient map (Rocketball goal tubes become saturated team colour,
//                chocolate outline + gloss survive). Tint/flash come from modulate (vertex COLOR).
// clip_y: nothing is drawn below this WORLD y (DOME: no net art under the floor line).
uniform int tint_mode = 0;
uniform float clip_y = 1.0e9;

varying vec4 v_tint;
varying float v_wy;

void vertex() {
	v_tint = COLOR;
	v_wy = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).y;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec4 o;
	if (tint_mode == 1) {
		float l = dot(t.rgb, vec3(0.299, 0.587, 0.114));
		vec3 body = v_tint.rgb * mix(0.78, 1.0, smoothstep(0.70, 0.92, l));
		vec3 col = mix(t.rgb, body, smoothstep(0.22, 0.38, l));
		col = mix(col, vec3(1.0), smoothstep(0.93, 1.0, l) * 0.85);
		o = vec4(col, t.a * v_tint.a);
	} else {
		o = t * v_tint;
	}
	o.a *= step(v_wy, clip_y);
	COLOR = o;
}
