extends SceneTree
## Busca z-fighting (superficies superpuestas en el mismo plano o casi) en los niveles:
## caras de las GreyBox (pisos, losas, paredes, cielorrasos) y planos chatos de los Prop
## (calles, sendas, manchas, alfombras). Imprime los pares que se superponen a menos de
## TOLERANCE metros con la misma orientación.
## Uso: <godot> --path . -s res://tools/find_zfight.gd [-- escena1.tscn escena2.tscn ...]

const TOLERANCE := 0.03
const MIN_AREA := 0.02
const LEVELS := [
	"res://scenes/levels/home.tscn", "res://scenes/levels/park_street.tscn", "res://scenes/levels/hospital.tscn",
	"res://scenes/levels/hospital_basement.tscn", "res://scenes/levels/street.tscn",
	"res://scenes/levels/police_station.tscn", "res://scenes/levels/church.tscn", "res://scenes/levels/theater.tscn",
	"res://scenes/levels/street_houses/ibarra.tscn", "res://scenes/levels/street_houses/almacen.tscn",
	"res://scenes/levels/street_houses/relojeria.tscn", "res://scenes/levels/street_houses/pension.tscn",
	"res://scenes/levels/street_houses/ferreyra.tscn",
]
const SKIP_GROUPS := ["Enemies", "Items", "Player", "GameUI", "PS1PostProcess"]

var grey_script: Script
var solids: Array = []


func _initialize() -> void:
	grey_script = load("res://scripts/world/grey_box.gd")
	var levels: Array = LEVELS
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		levels = args
	var total := 0
	for path: String in levels:
		change_scene_to_file(path)
		for i in 5:
			await process_frame
		var issues := _analyze(current_scene)
		total += issues.size()
		print("== %s: %d" % [path, issues.size()])
		for line: String in issues:
			print("   " + line)
	print("TOTAL: %d" % total)
	quit()


## Cara: {n: eje de la normal (0 x, 1 y, 2 z), s: signo, d: coordenada del plano, r: Rect2 en
## las otras dos coordenadas, node: ruta}
func _analyze(scene: Node) -> Array:
	var faces: Array = []
	_collect(scene, scene, faces)
	solids.clear()
	for fc: Dictionary in faces:
		if fc.has("box"):
			solids.append([fc.node, fc.box])
	var buckets := {}
	for i in faces.size():
		var f: Dictionary = faces[i]
		var key := "%d_%d_%d" % [f.n, f.s, floori(f.d / 0.05)]
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(i)
	var issues: Array = []
	var seen := {}
	for i in faces.size():
		var f: Dictionary = faces[i]
		var b := floori(f.d / 0.05)
		for db in [-1, 0, 1]:
			var key := "%d_%d_%d" % [f.n, f.s, b + db]
			if not buckets.has(key):
				continue
			for j: int in buckets[key]:
				if j <= i:
					continue
				var g: Dictionary = faces[j]
				if g.node == f.node:
					continue
				var dd: float = absf(f.d - g.d)
				if dd > TOLERANCE:
					continue
				var inter: Rect2 = (f.r as Rect2).intersection(g.r)
				if inter.get_area() < MIN_AREA:
					continue
				if _hidden(f, inter) or _hidden(g, inter):
					continue
				var pair := "%s|%s" % [f.node, g.node] if String(f.node) < String(g.node) else "%s|%s" % [g.node, f.node]
				if seen.has(pair):
					continue
				seen[pair] = true
				issues.append("%s%s Δ%.3f área %.2f  %s  <->  %s" % ["xyz"[f.n], "+" if f.s > 0 else "-", dd,
					inter.get_area(), f.node, g.node])
	return issues


func _collect(node: Node, scene: Node, faces: Array) -> void:
	if node.get_parent() == scene and SKIP_GROUPS.has(String(node.name)):
		return
	if node.get_script() == grey_script and node.get("mesh_visible"):
		_box_faces(node as Node3D, scene, faces)
		return
	if node is MeshInstance3D and node.is_visible_in_tree() and not _inside_grey(node):
		var mi := node as MeshInstance3D
		if mi.mesh:
			var aabb: AABB = (mi.global_transform * mi.get_aabb()).abs()
			if aabb.size.y < 0.06 and aabb.size.x * aabb.size.z > MIN_AREA:
				faces.append({"n": 1, "s": 1, "d": aabb.end.y, "r": Rect2(aabb.position.x, aabb.position.z, aabb.size.x, aabb.size.z),
					"node": scene.get_path_to(mi)})
	for c in node.get_children():
		_collect(c, scene, faces)


func _inside_grey(node: Node) -> bool:
	var p := node.get_parent()
	return p != null and p.get_script() == grey_script


func _box_faces(box: Node3D, scene: Node, faces: Array) -> void:
	var size: Vector3 = box.get("size")
	var xf := box.global_transform
	# Solo cajas alineadas a los ejes (las rampas giradas se saltean).
	var b := xf.basis.orthonormalized()
	for axis in 3:
		var v := b[axis]
		if not (is_equal_approx(absf(v.x), 1.0) or is_equal_approx(absf(v.y), 1.0) or is_equal_approx(absf(v.z), 1.0)):
			return
	var aabb := (xf * AABB(-size / 2, size)).abs()
	var path := scene.get_path_to(box)
	var lo := aabb.position
	var hi := aabb.end
	for n in 3:
		var u := (n + 1) % 3
		var w := (n + 2) % 3
		var r := Rect2(lo[u], lo[w], hi[u] - lo[u], hi[w] - lo[w])
		if r.get_area() < MIN_AREA:
			continue
		faces.append({"n": n, "s": 1, "d": hi[n], "r": r, "node": path, "box": aabb})
		faces.append({"n": n, "s": -1, "d": lo[n], "r": r, "node": path, "box": aabb})


## Una cara está tapada si justo delante de ella (en el centro de la zona en conflicto)
## hay otro sólido visible.
func _hidden(f: Dictionary, inter: Rect2) -> bool:
	var c := inter.get_center()
	var p := Vector3.ZERO
	var n: int = f.n
	p[n] = f.d + f.s * 0.012
	p[(n + 1) % 3] = c.x
	p[(n + 2) % 3] = c.y
	for s: Array in solids:
		if s[0] == f.node:
			continue
		var b: AABB = s[1]
		if b.grow(-0.001).has_point(p):
			return true
	return false
