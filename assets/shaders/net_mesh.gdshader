shader_type canvas_item;
// WK-66a sports net MESH (docs/briefs/sports_nets_2026-11-15.md section 8). Draws the shared seamless rope
// tile (assets/world/sports/net_mesh.png, mipmapped, repeat) over ONE padded quad and moves it:
//   * ripple (Dropshot net / goal near-miss): horizontal sine displacement travelling vertically out from
//     the contact y, pinned at the posts (pin_x) and at the tape/hem, decaying to 0 over ripple_time.
//   * bulge (goal score): Gaussian push along bulge_dir (toward the back post); the CPU feeds the current
//     damped-spring amplitude in bulge.z.
// The fragment offsets the sample position by the inverse displacement (q = p - D(p)) and masks to the frame
// interior, so cords move but the solid frame (separate sprites) stays rigid. Holes get a flat veil
// (veil.a; Dropshot white 0.10, goal team 0.18, front veil 0). Cords are modulated by the node colour.
// clip_y: nothing is drawn below this WORLD y (DOME: never draw net art under the floor line).

uniform sampler2D mesh_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform vec4 interior = vec4(-28.0, -240.0, 56.0, 480.0);   // local x, y, w, h of the frame interior
uniform vec2 tile_origin = vec2(0.0, 0.0);                  // local point where a tile corner sits
uniform float tile_wpx = 128.0;                             // world px per 256 px tile (32 wpx cell)
uniform vec4 veil = vec4(1.0, 1.0, 1.0, 0.10);              // hole fill (straight alpha)
uniform float clip_y = 1.0e9;
uniform float pin_x = 1.0;                                  // 1 = ripple pinned at the left/right edges
uniform vec4 ripples[4];                                    // (contact y local, age s, signed amp px, 0)
uniform float ripple_time = 0.35;
uniform float ripple_travel = 900.0;                        // wpx/s the wave front runs along the net
uniform float ripple_wavelength = 90.0;
uniform float ripple_falloff = 260.0;                       // wpx e-fold of the wave away from the contact
uniform vec4 bulge = vec4(0.0, 0.0, 0.0, 45.0);             // (centre x, centre y, signed amp px, sigma)
uniform vec2 bulge_dir = vec2(-1.0, 0.0);

varying vec2 v_lp;
varying float v_wy;
varying vec4 v_col;

void vertex() {
	v_lp = VERTEX;
	v_wy = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).y;
	v_col = COLOR;
}

vec2 displacement(vec2 p) {
	float dx = 0.0;
	for (int i = 0; i < 4; i++) {
		vec4 r = ripples[i];
		float life = clamp(1.0 - r.y / max(ripple_time, 0.001), 0.0, 1.0);
		float d = abs(p.y - r.x);
		float front = ripple_travel * r.y;
		float behind = 1.0 - smoothstep(front, front + ripple_wavelength * 0.5, d);
		float atten = exp(-d / max(ripple_falloff, 1.0));
		dx += r.z * life * life * behind * atten * cos(6.2831853 * (d - front) / max(ripple_wavelength, 1.0));
	}
	vec2 uv01 = clamp((p - interior.xy) / max(interior.zw, vec2(1.0)), vec2(0.0), vec2(1.0));
	float pin = mix(1.0, sin(3.1415927 * uv01.x), pin_x);
	float pinv = smoothstep(0.0, 0.05, uv01.y) * (1.0 - smoothstep(0.95, 1.0, uv01.y));
	vec2 D = vec2(dx * pin * pinv, 0.0);
	vec2 g = p - bulge.xy;
	D += bulge_dir * bulge.z * exp(-dot(g, g) / (2.0 * bulge.w * bulge.w));
	return D;
}

void fragment() {
	vec2 q = v_lp - displacement(v_lp);
	vec2 lo = interior.xy;
	vec2 hi = interior.xy + interior.zw;
	float aa = max(fwidth(v_lp.x), 0.5);
	float m = smoothstep(lo.x - aa, lo.x + aa, q.x) * (1.0 - smoothstep(hi.x - aa, hi.x + aa, q.x))
		* smoothstep(lo.y - aa, lo.y + aa, q.y) * (1.0 - smoothstep(hi.y - aa, hi.y + aa, q.y));
	vec4 t = texture(mesh_tex, (q - tile_origin) / tile_wpx);
	float ca = t.a * v_col.a;
	vec3 crgb = t.rgb * v_col.rgb;
	float va = veil.a * v_col.a;
	float a = ca + va * (1.0 - ca);
	vec3 rgb = (crgb * ca + veil.rgb * va * (1.0 - ca)) / max(a, 0.0001);
	float clip = step(v_wy, clip_y);
	COLOR = vec4(rgb, a * m * clip);
}
