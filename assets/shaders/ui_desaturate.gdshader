shader_type canvas_item;
// UI "taken / locked" treatment (WK-18 / lobby review L6): pulls a CanvasItem toward greyscale and dims it a
// touch, so a locked roster medallion reads "taken" from the sofa while keeping its goat colour.
// Set per instance (ShaderMaterial.new() in code) -- never share one material between medallions.
uniform float saturation : hint_range(0.0, 1.0) = 1.0;
uniform float value : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float l = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	COLOR.rgb = mix(vec3(l), COLOR.rgb, saturation) * value;
}
