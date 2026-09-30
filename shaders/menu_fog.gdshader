shader_type canvas_item;
// Fondo del menú de inicio: niebla que se arrastra, viñeta y grano.

uniform vec4 fog_color : source_color = vec4(0.55, 0.55, 0.57, 1.0);
uniform vec4 dark_color : source_color = vec4(0.03, 0.025, 0.025, 1.0);
uniform float speed = 0.02;
uniform float grain = 0.06;
uniform vec2 pixel_size = vec2(320.0, 240.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		value += amplitude * noise(p);
		p *= 2.03;
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	// Baja resolución, como todo lo demás.
	vec2 uv = floor(UV * pixel_size) / pixel_size;
	float t = TIME * speed;
	float fog = fbm(uv * vec2(3.0, 5.0) + vec2(t * 3.0, t * 0.6));
	fog = fog * 0.6 + fbm(uv * vec2(6.0, 9.0) - vec2(t * 5.0, 0.0)) * 0.4;
	// Más espesa abajo, como un piso de niebla.
	fog *= mix(0.45, 1.1, uv.y);
	vec3 color = mix(dark_color.rgb, fog_color.rgb, clamp(fog, 0.0, 1.0));
	float vignette = smoothstep(0.85, 0.25, distance(UV, vec2(0.5, 0.55)));
	color *= mix(0.25, 1.0, vignette);
	color += (hash(uv + fract(TIME)) - 0.5) * grain;
	COLOR = vec4(color, 1.0);
}
