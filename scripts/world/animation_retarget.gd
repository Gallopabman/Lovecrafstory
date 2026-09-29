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


## Crea una animación en loop que sostiene la pose de `source` en el instante `time`.
static func make_pose(player: AnimationPlayer, source: StringName, time: float, new_name: StringName) -> void:
	var library := player.get_animation_library(&"")
	if library.has_animation(new_name):
		return
	var src := player.get_animation(source)
	var pose := Animation.new()
	pose.length = 1.0
	pose.loop_mode = Animation.LOOP_LINEAR
	for i in src.get_track_count():
		if src.track_get_type(i) != Animation.TYPE_ROTATION_3D:
			continue
		var t := pose.add_track(Animation.TYPE_ROTATION_3D)
		pose.track_set_path(t, src.track_get_path(i))
		pose.rotation_track_insert_key(t, 0.0, src.rotation_track_interpolate(i, time))
	library.add_animation(new_name, pose)


## Crea `new_name` = `base` con cada rotación mezclada hacia la pose de `pose_anim`
## en `pose_time` (0 = base, 1 = la pose). P. ej. caminar + pose agachada = caminar agachado.
static func make_blend(player: AnimationPlayer, base: StringName, pose_anim: StringName, pose_time: float,
		weight: float, new_name: StringName) -> void:
	var library := player.get_animation_library(&"")
	if library.has_animation(new_name):
		return
	var anim := player.get_animation(base).duplicate(true) as Animation
	var pose := player.get_animation(pose_anim)
	var pose_tracks := {}
	for i in pose.get_track_count():
		if pose.track_get_type(i) == Animation.TYPE_ROTATION_3D:
			pose_tracks[pose.track_get_path(i)] = pose.rotation_track_interpolate(i, pose_time)
	for i in anim.get_track_count():
		if anim.track_get_type(i) != Animation.TYPE_ROTATION_3D:
			continue
		var path := anim.track_get_path(i)
		if not pose_tracks.has(path):
			continue
		var target: Quaternion = pose_tracks[path]
		for k in anim.track_get_key_count(i):
			var q: Quaternion = anim.track_get_key_value(i, k)
			anim.track_set_key_value(i, k, q.slerp(target, weight))
	library.add_animation(new_name, anim)
