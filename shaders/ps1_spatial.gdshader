// Shader PS1 para geometría del mundo:
// - vertex snapping (jitter) a una grilla de baja resolución
// - mapeo de texturas afín (sin corrección de perspectiva)
// - texturas nearest / baja resolución
// - iluminación por vértice (Gouraud)
// - niebla lineal por vértice controlada por parámetros globales (ver Atmosphere)
shader_type spatial;
render_mode vertex_lighting, diffuse_lambert, specular_disabled, cull_back;

global uniform vec4 ps1_fog_color;
global uniform float ps1_fog_start;
global uniform float ps1_fog_end;
global uniform vec2 ps1_snap_resolution;
// 0 = lúcido, 1 = al borde (ver Atmosphere). Deforma las texturas.
global uniform float ps1_insanity;

uniform vec4 albedo_color : source_color = vec4(1.0);
// Luz propia (tubos fluorescentes, pantallas). Negro = sin emisión.
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_nearest, repeat_enable;
// Fuerza una resolución de textura virtual (texels por unidad UV). 0 = desactivado.
uniform float texture_resolution = 0.0;
uniform vec2 uv_scale = vec2(1.0);
// Proyecta las UV desde el espacio mundo según el eje dominante de la normal.
// Ideal para greybox: la textura mantiene escala sin importar el tamaño de la caja.
uniform bool world_uv = false;
uniform float world_uv_scale = 0.5;
uniform bool vertex_snap = true;
uniform bool affine_mapping = true;
uniform bool fog_enabled = true;

varying vec3 affine_uv;
varying float fog_amount;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	vec2 uv = UV;
	if (world_uv) {
		vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 world_normal = abs(normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz));
		if (world_normal.y >= world_normal.x && world_normal.y >= world_normal.z) {
			uv = world_pos.xz;
		} else if (world_normal.x >= world_normal.z) {
			uv = vec2(world_pos.z, -world_pos.y);
		} else {
			uv = vec2(world_pos.x, -world_pos.y);
		}
		uv *= world_uv_scale;
	}
	uv *= uv_scale;
	UV = uv;

	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (vertex_snap && clip.w > 0.0) {
		vec2 half_res = ps1_snap_resolution * 0.5;
		clip.xy = round(clip.xy / clip.w * half_res) / half_res * clip.w;
	}
	POSITION = clip;

	// Truco clásico: interpolar uv*w y w por separado y dividir en el fragment
	// anula la corrección de perspectiva -> mapeo afín.
	affine_uv = vec3(uv * clip.w, clip.w);

	float dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	fog_amount = clamp((dist - ps1_fog_start) / max(ps1_fog_end - ps1_fog_start, 0.001), 0.0, 1.0);
}

void fragment() {
	vec2 uv = affine_mapping ? affine_uv.xy / affine_uv.z : UV;
	// Locura: las texturas "respiran".
	uv += vec2(sin(uv.y * 5.0 + TIME * 1.3), cos(uv.x * 5.0 + TIME * 0.9)) * ps1_insanity * 0.05;
	if (texture_resolution > 0.0) {
		uv = (floor(uv * texture_resolution) + 0.5) / texture_resolution;
	}
	ALBEDO = albedo_color.rgb * texture(albedo_texture, uv).rgb;
	EMISSION = emission_color.rgb;
	if (fog_enabled) {
		// El global llega en sRGB; FOG se mezcla en espacio lineal.
		FOG = vec4(srgb_to_linear(ps1_fog_color.rgb), fog_amount);
	}
}
