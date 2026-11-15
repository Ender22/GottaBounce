shader_type canvas_item;
// WK-131 Rocketball KICKOFF GATE pole (docs/briefs/kickoff_gate_2026-11-15.md sections 2, 6, 9).
// Fork of net_frame.gdshader tint_mode 1 (the fx_tint gradient map: chocolate outline < 0.22 luma and gloss > 0.93
// survive), with a per-pixel CANDY STRIPE colour in place of the team tint. Drawn on ONE padded quad (a Polygon2D in
// pole-local world units); the tube texture is goal_frame.png's back-tube run, sampled by local position so the pole is
// the same toy tube as the cage at a uniform scale.
//   stripes : 45 deg cream / honey-gold bands in LOCAL WORLD units (constant band size on every mouth), anti-aliased
//             from fwidth; `scroll` (periods) slides them up the pole (the warning's barber-pole spin-up).
//   flex    : a Gaussian bow along x around the contact y (net_mesh's inverse-offset technique: q = p - D(p)); both
//             ends pinned. A bend, never a stretch.
//   flash   : mixes toward white (hit flash).
//   clip    : nothing is drawn above clip_top_wy (WORLD y = the top tube centre line): the retract slides the pole up
//             INTO the top socket.
//   ends    : rounded capsule ends with a chocolate rim (only ever seen while the pole lifts / retracts).

uniform sampler2D tube_tex : source_color, filter_linear, repeat_disable;
uniform vec4 tube_src = vec4(13.0, 300.0, 126.0, 1000.0);   // source rect (px) of the plain tube run
uniform vec2 tex_size = vec2(680.0, 1704.0);
uniform float bar_w = 52.0;                                  // drawn width (world px)
uniform float top_y = -158.0;                                // pole-local y of the top end
uniform float bot_y = 158.0;                                 // pole-local y of the bottom end
uniform float clip_top_wy = -1.0e9;                          // WORLD y: nothing drawn above
uniform vec3 stripe_a : source_color = vec3(1.0, 0.953, 0.839);   // #FFF3D6 cream
uniform vec3 stripe_b : source_color = vec3(0.949, 0.702, 0.239); // #F2B33D honey gold
uniform vec3 outline_col : source_color = vec3(0.231, 0.141, 0.106); // #3B241B
uniform float stripe_period = 44.0;
uniform float scroll = 0.0;                                  // stripe offset in periods (+ = up the pole)
uniform vec4 flex = vec4(0.0, 0.0, 70.0, 0.0);               // (centre y local, signed bow px along x, sigma, 0)
uniform float flash = 0.0;
uniform float rim_w = 3.5;                                   // capsule-end chocolate rim (world px)

varying vec2 v_lp;
varying float v_wy;
varying vec4 v_col;

void vertex() {
	v_lp = VERTEX;
	v_wy = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).y;
	v_col = COLOR;
}

void fragment() {
	float half_w = bar_w * 0.5;
	// --- flex: inverse offset, pinned at both ends ---
	float y = v_lp.y;
	float pin = smoothstep(top_y, top_y + 46.0, y) * (1.0 - smoothstep(bot_y - 46.0, bot_y, y));
	float gy = y - flex.x;
	float dx = flex.y * exp(-(gy * gy) / (2.0 * flex.z * flex.z)) * pin;
	vec2 q = vec2(v_lp.x - dx, y);
	float aa = max(fwidth(v_lp.x), 0.5);

	// --- shape mask: straight run + rounded bottom/top ends ---
	float m = 1.0 - smoothstep(half_w - aa, half_w + aa, abs(q.x));
	float rim = 0.0;
	vec2 c_bot = vec2(0.0, bot_y - half_w);
	vec2 c_top = vec2(0.0, top_y + half_w);
	if (q.y > c_bot.y) {
		float d = length(q - c_bot);
		m = 1.0 - smoothstep(half_w - aa, half_w + aa, d);
		rim = smoothstep(half_w - rim_w - aa, half_w - rim_w + aa, d);
	} else if (q.y < c_top.y) {
		float d = length(q - c_top);
		m = 1.0 - smoothstep(half_w - aa, half_w + aa, d);
		rim = smoothstep(half_w - rim_w - aa, half_w - rim_w + aa, d);
	}

	// --- tube texture (uniform scale, the rows are uniform so any y in the run works) ---
	float u = clamp((q.x + half_w) / bar_w, 0.0, 1.0);
	float sc = bar_w / tube_src.z;
	float sy = mod((q.y - top_y) / sc, tube_src.w - 2.0) + 1.0;
	vec2 src = vec2(tube_src.x + u * tube_src.z, tube_src.y + sy);
	vec4 t = texture(tube_tex, src / tex_size);

	// --- candy stripes in local world units, 45 deg ---
	float d45 = (q.x + q.y) * 0.70710678;
	float ph = 6.2831853 * (d45 / stripe_period + scroll);
	float sv = sin(ph);
	float saa = max(fwidth(sv) * 0.75, 0.02);
	float s = smoothstep(-saa, saa, sv);
	vec3 stripe = mix(stripe_a, stripe_b, s);

	// --- net_frame tint_mode 1 gradient map with the stripe colour as the tint ---
	float l = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	vec3 body = stripe * mix(0.78, 1.0, smoothstep(0.70, 0.92, l));
	vec3 col = mix(t.rgb, body, smoothstep(0.22, 0.38, l));
	col = mix(col, vec3(1.0), smoothstep(0.93, 1.0, l) * 0.85);
	col = mix(col, outline_col, rim);
	col = mix(col, vec3(1.0), clamp(flash, 0.0, 1.0));
	float a = max(t.a, rim) * m;
	a *= smoothstep(clip_top_wy - 0.5, clip_top_wy + 0.5, v_wy);
	COLOR = vec4(col * v_col.rgb, a * v_col.a);
}
