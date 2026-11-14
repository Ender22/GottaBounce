shader_type canvas_item;
// Flat-colour silhouette: keeps only the texture's alpha and paints it one tint (Herd Lobby EMPTY slot
// silhouette, WK-81 F4 — "cream at 0.16", not a colour-tinted ghost of the sprite).
uniform vec4 tint : source_color = vec4(1.0, 0.968627, 0.921569, 0.16);

void fragment() {
	float a = texture(TEXTURE, UV).a;
	COLOR = vec4(tint.rgb, a * tint.a);
}
