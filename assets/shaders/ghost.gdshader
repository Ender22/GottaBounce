shader_type canvas_item;
// WK-37 ghost goat (docs/briefs/ghost_goats_2026-11-14.md §3). Runs on the EXISTING bouncer_<skin>_idle.png:
//   colour      keep the hue, saturation x0.85, then 20 % toward white (the brief's §4 "ghost body" targets)
//   outline     a dark pixel next to transparency (8 taps at outline_tap of the texture width) -> the pale `rim`
//               colour: no chocolate outline = "not touchable" (house rule)
//   inner lines other dark pixels (pupils, mouth, horn grooves) -> `deep` (skin x 0.45) so the face still reads
//   hem         a crisp animated sheet-ghost hem cut (feet removed)
// Modes: flat_mode = the rim/halo layer; grey_art = tintable greyscale art (the tail, fx_tint contract) coloured to
// skin_col first. wave_amp > 0 = the tail's UV sway (0 at the root -> tip).
// Alpha = sampled alpha x vertex COLOR alpha (the root's modulate.a = Tuning.ghost_alpha), gated so the RGB junk in
// alpha-0 pixels can never bleed into the rim.
//
// WK-37c rim (flat_mode): an OUTLINE-ONLY band of constant SCREEN width (rim_px, via fwidth) around the hem-cut
// silhouette, so it stays 2-3 px on the widest cameras where the body is a ~25 px speck (the old x1.08 scaled copy
// shrank to < 1 px there and also showed through the 40 % body). Optional thin outer `deep` line (deep_px, deep_gain)
// gives the pale band contrast over bright skies. The quad is padded (quad_pad; the sprite is scaled up by the same
// factor and its offset divided by it) because the idle art is trimmed to its edges. rim_gain lifts the band's
// alpha above the body's so the silhouette edge is the findable part, never the fill.
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
uniform float quad_pad = 1.0;     // flat_mode: quad scale vs the art (content remapped back to its true size)
uniform float rim_px = 2.5;       // flat_mode: pale band width, SCREEN px
uniform float deep_px = 0.0;      // flat_mode: outer deep line width, SCREEN px (0 = off)
uniform float rim_gain = 1.0;     // flat_mode: band alpha x this (clamped to 1)
uniform float deep_gain = 1.0;    // flat_mode: deep line alpha x this
uniform float flatten = 0.0;      // body: pull the shaded art toward flat skin_col (0..1); inner lines/eyes kept.
                                  // Quiets the baked jetpack + horn detail that turns a small ghost into noise.
uniform float off_hue_flatten = 0.0;  // body: extra flatten for SATURATED pixels far from the ghost's own skin hue
                                  // (the baked orange jetpack; cream horns are unsaturated and survive). Hue distance
                                  // to its OWN skin, so BILLY's orange body is never eaten (brief E5 concern).

// WK-37d bright-backdrop lift: the backdrop luma behind the ghost's CENTRE (bright_uv, set per frame from GDScript;
// a high mip of the screen copy = a ~16 px average, so the whole ghost gets ONE alpha, never a mottled one) lifts the
// root alpha toward bright_alpha_max on pale backdrops only (smoothstep lum_lo..lum_hi; mid/dark = no change, so T9's
// 0.40 / 0.25 hold there). The lift scales the alpha the ghost already has (near-fight 0.25 stays proportionally lower)
// and never pushes it above bright_alpha_max (nor lowers an alpha that is already higher, e.g. the widest-camera boost).
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform bool bright_on = false;
uniform vec2 bright_uv = vec2(0.5);
uniform float bright_base_alpha = 0.40;
uniform float bright_alpha_max = 0.50;
uniform float bright_lum_lo = 0.62;
uniform float bright_lum_hi = 0.82;
uniform float bright_lod = 4.0;
uniform int bright_debug = 0;     // QA only: 1 = paint the sampled backdrop colour, 2 = paint the lift amount k

vec3 bright_bg() {
	return textureLod(screen_tex, clamp(bright_uv, vec2(0.0), vec2(1.0)), bright_lod).rgb;
}

varying vec4 v_col;

float lifted_alpha(float a) {
	if (!bright_on) {
		return a;
	}
	vec3 bg = bright_bg();
	float lum = dot(bg, vec3(0.299, 0.587, 0.114));
	float k = smoothstep(bright_lum_lo, bright_lum_hi, lum);
	float mult = mix(1.0, bright_alpha_max / max(bright_base_alpha, 0.01), k);
	return max(a, min(a * mult, bright_alpha_max));
}

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

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 ghostify(vec3 c) {
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 g = mix(vec3(l), c, 0.85);
	return mix(g, vec3(1.0), 0.20);
}

float hem_cut(vec2 uv) {
	if (!hem_on) {
		return 1.0;
	}
	float cut = hem_y + hem_amp * sin(uv.x * hem_waves * 6.2831853 + TIME * 3.0 + phase);
	return 1.0 - smoothstep(cut, cut + 0.025, uv.y);
}

// Hem-cut silhouette alpha at uv; 0 outside the texture (the padded quad samples beyond [0,1]).
float sil(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(tex, uv).a * hem_cut(uv);
}

// Max silhouette alpha on a ring of radius r (UV units, per axis), 12 taps.
float ring_max(sampler2D tex, vec2 uv, vec2 r) {
	float m = 0.0;
	for (int k = 0; k < 12; k++) {
		float ang = float(k) * 0.5235988;
		m = max(m, sil(tex, uv + vec2(cos(ang), sin(ang)) * r));
	}
	return m;
}

void fragment() {
	if (flat_mode) {
		vec2 uv = (UV - 0.5) * quad_pad + 0.5;
		vec2 fw = fwidth(uv);   // UV per screen pixel -> constant screen-px band at any zoom
		float own = sil(TEXTURE, uv);
		float a_in = max(ring_max(TEXTURE, uv, fw * rim_px * 0.5), ring_max(TEXTURE, uv, fw * rim_px));
		float inner = clamp(a_in - own, 0.0, 1.0);
		float outer = 0.0;
		if (deep_px > 0.0) {
			float a_out = ring_max(TEXTURE, uv, fw * (rim_px + deep_px));
			outer = clamp(a_out - max(a_in, own), 0.0, 1.0) * deep_gain;
		}
		float sum = inner + outer;
		vec3 col = sum > 1e-4 ? (rim_col.rgb * inner + deep_col.rgb * outer) / sum : rim_col.rgb;
		COLOR = vec4(col * v_col.rgb, clamp(clamp(sum, 0.0, 1.0) * lifted_alpha(v_col.a) * rim_gain, 0.0, 1.0));
	} else {
		vec2 uv = UV;
		if (wave_amp > 0.0) {
			uv.x += wave_amp * sin(uv.y * wave_count * 6.2831853 - TIME * 3.0 + phase) * uv.y;
		}
		vec2 fw = fwidth(UV);
		vec4 t = ss(TEXTURE, uv, fw);
		float a = t.a * hem_cut(UV);
		float l = dot(t.rgb, vec3(0.299, 0.587, 0.114));
		vec3 src = t.rgb;
		if (grey_art) {
			vec3 body = skin_col.rgb * mix(0.78, 1.0, smoothstep(0.70, 0.92, l));
			src = mix(t.rgb, body, smoothstep(0.22, 0.38, l));
			src = mix(src, vec3(1.0), smoothstep(0.93, 1.0, l) * 0.85);
		}
		vec3 col = ghostify(src);
		float fl = flatten;
		if (off_hue_flatten > 0.0) {
			vec3 hs = rgb2hsv(src);
			vec3 hk = rgb2hsv(skin_col.rgb);
			float dh = abs(hs.x - hk.x);
			dh = min(dh, 1.0 - dh);
			float far = smoothstep(0.05, 0.12, dh) * smoothstep(0.30, 0.50, hs.y);
			fl = max(fl, off_hue_flatten * far);
		}
		if (fl > 0.0) {
			col = mix(col, skin_col.rgb * mix(0.86, 1.04, smoothstep(0.35, 0.9, l)), fl);
		}
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
		COLOR = vec4(col * v_col.rgb, a * lifted_alpha(v_col.a));
		if (bright_debug == 1) {
			COLOR = vec4(bright_bg(), a);
		} else if (bright_debug == 2) {
			float lum = dot(bright_bg(), vec3(0.299, 0.587, 0.114));
			COLOR = vec4(vec3(smoothstep(bright_lum_lo, bright_lum_hi, lum)), a);
		}
	}
}
