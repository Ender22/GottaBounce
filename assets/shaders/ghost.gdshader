shader_type canvas_item;
// WK-37 ghost goat (docs/briefs/ghost_goats_2026-11-14.md §3). Runs on the EXISTING bouncer_<skin>_idle.png:
//   colour      keep the hue, saturation x0.85, then 20 % toward white (the brief's §4 "ghost body" targets)
//   outline     a dark pixel next to transparency (8 taps at outline_tap of the texture width) -> the pale `rim`
//               colour: no chocolate outline = "not touchable" (house rule)
//   inner lines other dark pixels (pupils, mouth, horn grooves) -> `deep` (skin x 0.45) so the face still reads
//   hem         a crisp animated sheet-ghost hem cut (feet removed)
// Modes: flat_mode = the rim/halo layer (alpha only, painted rim_col, same hem); grey_art = tintable greyscale art
// (the tail, fx_tint contract) coloured to skin_col first. wave_amp > 0 = the tail's UV sway (0 at the root -> tip).
// Alpha = sampled alpha x vertex COLOR alpha (the root's modulate.a = Tuning.ghost_alpha), gated so the RGB junk in
// alpha-0 pixels can never bleed into the rim.
uniform vec4 skin_col : source_color = vec4(1.0, 0.373, 0.659, 1.0);
uniform vec4 rim_col : source_color = vec4(1.0, 0.812, 0.898, 1.0);
uniform vec4 deep_col : source_color = vec4(0.451, 0.169, 0.298, 1.0);
uniform bool hem_on = true;
uniform float hem_y = 0.80;
uniform float hem_amp = 0.035;
uniform float hem_waves = 3.0;
uniform bool flat_mode = false;
uniform bool grey_art = false;
uniform float wave_amp = 0.0;
uniform float wave_count = 2.0;
uniform float outline_tap = 0.04;
uniform float phase = 0.0;

varying vec4 v_col;

// 4-tap rotated-grid supersample at the screen footprint: the 780 px goat art is drawn ~40 px tall, and the ghost's
// 40 % alpha exposes minification shimmer that the opaque living goat hides. Soft is on-theme for a ghost.
vec4 ss(sampler2D tex, vec2 uv, vec2 fw) {
	vec2 a = fw * vec2(0.125, 0.375);
	vec2 b = fw * vec2(0.375, -0.125);
	vec4 s0 = texture(tex, uv + a);
	vec4 s1 = texture(tex, uv - a);
	vec4 s2 = texture(tex, uv + b);
	vec4 s3 = texture(tex, uv - b);
	float sa = s0.a + s1.a + s2.a + s3.a;
	vec3 rgb = s0.rgb * s0.a + s1.rgb * s1.a + s2.rgb * s2.a + s3.rgb * s3.a;   // alpha-weighted: alpha-0 RGB junk never bleeds
	return vec4(rgb / max(sa, 1e-4), sa * 0.25);
}

void vertex() {
	v_col = COLOR;
}

vec3 ghostify(vec3 c) {
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 g = mix(vec3(l), c, 0.85);
	return mix(g, vec3(1.0), 0.20);
}

void fragment() {
	vec2 uv = UV;
	if (wave_amp > 0.0) {
		uv.x += wave_amp * sin(uv.y * wave_count * 6.2831853 - TIME * 3.0 + phase) * uv.y;
	}
	vec2 fw = fwidth(UV);
	vec4 t = ss(TEXTURE, uv, fw);
	float a = t.a;
	if (hem_on) {
		float cut = hem_y + hem_amp * sin(UV.x * hem_waves * 6.2831853 + TIME * 3.0 + phase);
		a *= 1.0 - smoothstep(cut, cut + 0.025, UV.y);
	}
	vec3 col;
	if (flat_mode) {
		col = rim_col.rgb;
	} else {
		float l = dot(t.rgb, vec3(0.299, 0.587, 0.114));
		vec3 src = t.rgb;
		if (grey_art) {
			vec3 body = skin_col.rgb * mix(0.78, 1.0, smoothstep(0.70, 0.92, l));
			src = mix(t.rgb, body, smoothstep(0.22, 0.38, l));
			src = mix(src, vec3(1.0), smoothstep(0.93, 1.0, l) * 0.85);
		}
		col = ghostify(src);
		float dark = 1.0 - smoothstep(0.24, 0.34, l);
		if (dark > 0.0) {
			vec2 d = vec2(outline_tap, outline_tap * TEXTURE_PIXEL_SIZE.y / max(TEXTURE_PIXEL_SIZE.x, 1e-6));   // same px distance on both axes
			float mn = 1.0;
			for (int k = 0; k < 8; k++) {
				float ang = float(k) * 0.7853982;
				mn = min(mn, texture(TEXTURE, uv + vec2(cos(ang), sin(ang)) * d).a);
			}
			vec3 line_col = mn < 0.5 ? rim_col.rgb : deep_col.rgb;
			col = mix(col, line_col, dark);
		}
	}
	COLOR = vec4(col * v_col.rgb, a * v_col.a);
}
