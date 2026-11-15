shader_type canvas_item;
// WK-131 kickoff gate badge + "NOT YET!" glyph: the sprite as authored, mixed toward white by `white` (hit flash and the
// warning's brightness swing: an additive-style brightening, alpha never drops, so the badge never blinks out).
// Tint/fade come from modulate (vertex COLOR).
uniform float white = 0.0;

varying vec4 v_col;

void vertex() {
	v_col = COLOR;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	COLOR = vec4(mix(t.rgb, vec3(1.0), clamp(white, 0.0, 1.0)) * v_col.rgb, t.a * v_col.a);
}
