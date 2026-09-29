class_name PS1Materials
## Convierte los materiales estándar de un modelo importado (glTF/FBX) al
## shader PS1, conservando color y textura. Así los assets descargados
## quedan con el mismo look sin editarlos a mano.

const PS1_SHADER := preload("res://shaders/ps1_spatial.gdshader")


## `tint` multiplica el color original (útil para apagar o teñir un asset).
static func apply(root: Node, tint := Color.WHITE) -> void:
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
				cache[source] = _convert(source, tint)
			mesh_instance.set_surface_override_material(surface, cache[source])


static func _convert(source: BaseMaterial3D, tint: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PS1_SHADER
	material.set_shader_parameter(&"albedo_color", source.albedo_color * tint)
	if source.albedo_texture:
		material.set_shader_parameter(&"albedo_texture", source.albedo_texture)
	return material
