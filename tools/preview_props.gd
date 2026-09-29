extends SceneTree
## Renderiza los modelos de una carpeta en grilla, vistos desde +Z (el frente de un
## Prop debería mirar a la cámara), con una columna de 1 m de referencia.
## Uso: <godot> --path . -s res://tools/preview_props.gd -- <carpeta res://> <salida.png> [columnas] [nombres,separados,por,coma]

func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var folder: String = args[0]
	var out: String = args[1]
	var cols := int(args[2]) if args.size() > 2 else 6
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.22, 0.22, 0.26)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.55)
	world.add_child(env)
	RenderingServer.global_shader_parameter_set(&"ps1_fog_start", 999.0)
	RenderingServer.global_shader_parameter_set(&"ps1_fog_end", 1000.0)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 25, 0)
	world.add_child(sun)
	var names: PackedStringArray = []
	var dir := DirAccess.open(folder)
	for d in dir.get_directories():
		names.append(d)
	for f in dir.get_files():
		if f.ends_with(".glb"):
			names.append(f.get_basename())
	names.sort()
	if args.size() > 3:
		names = args[3].split(",")
	var spacing := 2.6
	for i in names.size():
		var n := names[i]
		var path := folder + n + "/" + n + ".gltf" if dir.dir_exists(n) else folder + n + ".glb"
		var p := Prop.new()
		p.model = load(path)
		world.add_child(p)
		p.position = Vector3((i % cols) * spacing, 0, -(i / cols) * spacing * 1.3)
		var label := Label3D.new()
		label.text = "%s\n%s" % [n, str(snapped(p._local_aabb().size, Vector3.ONE * 0.01))]
		label.pixel_size = 0.004
		label.position = p.position + Vector3(0, -0.25, 0.9)
		world.add_child(label)
		var ref := MeshInstance3D.new()
		ref.mesh = BoxMesh.new()
		(ref.mesh as BoxMesh).size = Vector3(0.04, 1.0, 0.04)
		ref.position = p.position + Vector3(-1.1, 0.5, 0)
		world.add_child(ref)
	var rows := ceili(float(names.size()) / cols)
	var cam := Camera3D.new()
	world.add_child(cam)
	var center := Vector3((cols - 1) * spacing / 2.0, 0.6, -(rows - 1) * spacing * 1.3 / 2.0)
	cam.position = center + Vector3(0, rows * 1.1 + 1.0, rows * 1.9 + cols * 0.9)
	cam.look_at(center)
	cam.fov = 55
	for i in 4:
		await process_frame
	root.get_texture().get_image().save_png(out)
	quit()
