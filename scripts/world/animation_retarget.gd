class_name AnimationRetarget
## Copia animaciones entre modelos con esqueletos de nombres compatibles (los
## rigs "CharacterArmature" de Quaternius). Solo se copian las pistas de
## rotación de huesos que existen en el destino: las traslaciones dependen de
## las proporciones de cada modelo y se descartan.


static func import_animations(source: PackedScene, names: Array[StringName],
		target_player: AnimationPlayer, target_skeleton: Skeleton3D) -> void:
	var source_root := source.instantiate()
	var source_player := source_root.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var target_root := target_player.get_node(target_player.root_node)
	var skeleton_path := String(target_root.get_path_to(target_skeleton))
	var library := target_player.get_animation_library(&"")
	for anim_name in names:
		if not source_player.has_animation(anim_name) or library.has_animation(anim_name):
			continue
		var anim := source_player.get_animation(anim_name).duplicate(true) as Animation
		for i in range(anim.get_track_count() - 1, -1, -1):
			var bone := anim.track_get_path(i).get_concatenated_subnames()
			if anim.track_get_type(i) != Animation.TYPE_ROTATION_3D or target_skeleton.find_bone(bone) < 0:
				anim.remove_track(i)
			else:
				anim.track_set_path(i, NodePath("%s:%s" % [skeleton_path, bone]))
		library.add_animation(anim_name, anim)
	source_root.free()
