// Post-proceso PS1 a pantalla completa: reducción de profundidad de color
// (32 niveles por canal = 15 bits) + dithering ordenado Bayer 4x4.
// Se aplica sobre la resolución interna (320x240), así el patrón queda "gordo".
// Con la locura (ps1_insanity) los colores se degradan, aparece grano, viñeta
// y ondulación; un golpe o susto (ps1_shock) desplaza los canales y tiñe de rojo.
shader_type canvas_item;

global uniform float ps1_insanity;
global uniform float ps1_shock;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float color_levels : hint_range(2.0, 256.0) = 32.0;
// Niveles de color al borde de la locura.
uniform float insane_color_levels : hint_range(2.0, 256.0) = 10.0;
uniform bool dithering = true;
uniform float dither_strength : hint_range(0.0, 2.0) = 1.0;

const float BAYER_4X4[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	// Ondulación de la imagen con la locura.
	uv.x += sin(uv.y * 18.0 + TIME * 2.0) * 0.002 * ps1_insanity;
	// Separación de canales con el susto.
	float split = 0.006 * ps1_shock;
	vec3 color;
	color.r = texture(screen_texture, uv + vec2(split, 0.0)).r;
	color.g = texture(screen_texture, uv).g;
	color.b = texture(screen_texture, uv - vec2(split, 0.0)).b;

	// Desaturación, viñeta y grano.
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(color, vec3(luma), ps1_insanity * 0.6);
	float vignette = smoothstep(0.85, 0.2, length(SCREEN_UV - 0.5));
	color *= mix(1.0, vignette, ps1_insanity * 0.8);
	color += (hash(floor(FRAGCOORD.xy) + fract(TIME) * 100.0) - 0.5) * 0.12 * ps1_insanity;
	color = mix(color, color * vec3(1.4, 0.5, 0.45), ps1_shock * 0.6);

	float steps = mix(color_levels, insane_color_levels, ps1_insanity) - 1.0;
	if (dithering) {
		int x = int(mod(FRAGCOORD.x, 4.0));
		int y = int(mod(FRAGCOORD.y, 4.0));
		float threshold = (BAYER_4X4[y * 4 + x] + 0.5) / 16.0 - 0.5;
		color += threshold * dither_strength / steps;
	}
	color = floor(color * steps + 0.5) / steps;
	COLOR = vec4(clamp(color, 0.0, 1.0), 1.0);
}
