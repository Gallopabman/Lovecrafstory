class_name PS1Materials
## Convierte los materiales estándar de un modelo importado (glTF/FBX) al
## shader PS1, conservando color y textura. Así los assets descargados
## quedan con el mismo look sin editarlos a mano.

const PS1_SHADER := preload("res://shaders/ps1_spatial.gdshader")


## `tint` multiplica el color original (útil para apagar o teñir un asset).
## `colors` reemplaza el color de materiales puntuales por nombre.
## Devuelve los materiales creados (p. ej. para hacerlos destellar al recibir daño).
## `texture` se usa en los materiales que no traen textura propia (modelos con la textura aparte).
static func apply(root: Node, tint := Color.WHITE, colors: Dictionary = {},
		texture: Texture2D = null) -> Array[ShaderMaterial]:
	var cache: Dictionary = {}
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.get_active_material(surface) as BaseMaterial3D
			if source == null:
				continue
			if not cache.has(source):
				cache[source] = _convert(source, tint, colors)
				if texture and source.albedo_texture == null:
					cache[source].set_shader_parameter(&"albedo_texture", texture)
					cache[source].set_shader_parameter(&"albedo_color", tint)
			mesh_instance.set_surface_override_material(surface, cache[source])
	var materials: Array[ShaderMaterial] = []
	materials.assign(cache.values())
	return materials


static func _convert(source: BaseMaterial3D, tint: Color, colors: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PS1_SHADER
	var color: Color = colors.get(source.resource_name, source.albedo_color)
	material.set_shader_parameter(&"albedo_color", color * tint)
	if source.albedo_texture:
		material.set_shader_parameter(&"albedo_texture", source.albedo_texture)
	return material
