shader_type canvas_item;
// Gradient-map tint for the greyscale "Glossy Toybox" FX layers (WK-23 KO blast + WK-24 hit burst;
// tintability contract in docs/briefs/ko_blast_2026-11-14.md — the brief's preferred method 2).
// The tint colour AND the fade come from the node's modulate * self_modulate (vertex COLOR), so ONE shared
// material serves every sprite: set self_modulate = identity colour, animate modulate.a to fade.
//   dark outline  (lum < ~0.3)  -> kept as authored (house chocolate #3B241B)
//   grey body     (mid lum)     -> the tint, shaded 0.78..1.0 by the art's own value (keeps the form)
//   top highlight (lum > 0.93)  -> blended back toward white (the toybox gloss survives the tint)
varying vec4 v_tint;

void vertex() {
	v_tint = COLOR;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float l = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	vec3 body = v_tint.rgb * mix(0.78, 1.0, smoothstep(0.70, 0.92, l));
	vec3 col = mix(t.rgb, body, smoothstep(0.22, 0.38, l));
	col = mix(col, vec3(1.0), smoothstep(0.93, 1.0, l) * 0.85);
	COLOR = vec4(col, t.a * v_tint.a);
}
