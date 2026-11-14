shader_type canvas_item;
// WK-37 ghost puff cloud — the art pass's "keep-white" variant (tools/out/ghost_tint_test.png row 2): fx_tint fills
// the WHOLE cloud with colour, which reads as a coloured blob / a bubblegum mat. Here only the grey UNDERSIDE shading
// (#BDBDBD band, luma ~0.6-0.8) takes the owner colour; the white marshmallow top (#F2F2F2 / #FFFFFF) stays white and
// the chocolate outline + face stay as authored. Tint + fade come from modulate * self_modulate (vertex COLOR).
varying vec4 v_tint;

void vertex() {
	v_tint = COLOR;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float l = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	float w = smoothstep(0.22, 0.38, l) * (1.0 - smoothstep(0.80, 0.90, l));
	vec3 body = v_tint.rgb * mix(0.80, 1.0, smoothstep(0.55, 0.80, l));
	vec3 col = mix(t.rgb, body, w);
	COLOR = vec4(col, t.a * v_tint.a);
}
