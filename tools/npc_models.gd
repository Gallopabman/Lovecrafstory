extends RefCounted
## Modelos de los NPC (el Flaco, el Dr. Ferreyra, el mendigo): archivo, escala, color y
## animaciones. Lo usan los generadores (helper `_npc` de build_hospital.gd y build_street.gd).
## Los tres son del "Ultimate Modular Men" de Quaternius (CC0, el mismo rig que el sobreviviente),
## con piezas combinadas: miran a +Z y traen las mismas 24 animaciones.

const DIR := "res://assets/models/characters/npcs/"
const ROLES := {
	"flaco": {"model": "flaco.glb", "model_scale": 0.95, "tint": Color(0.8, 0.78, 0.76),
		"anim_idle": &"CharacterArmature|Idle_Neutral"},
	"ferreyra": {"model": "ferreyra.glb", "model_scale": 0.95, "tint": Color(0.85, 0.85, 0.83),
		"anim_idle": &"CharacterArmature|Idle", "anim_run": &"CharacterArmature|Run"},
	## Duerme en la pose final de Death: boca arriba, con los pies en el origen y la cabeza hacia -Z
	## (se centra con `model_offset`).
	"mendigo": {"model": "mendigo.glb", "model_scale": 0.95, "tint": Color(0.55, 0.5, 0.44),
		"anim_pose": &"CharacterArmature|Death", "model_offset": Vector3(0, 0, 0.66)},
}


static func configure(npc: Node, role: String) -> void:
	var r: Dictionary = ROLES.get(role, {})
	var path: String = DIR + String(r.get("model", ""))
	if r.is_empty() or not ResourceLoader.exists(path):
		return
	npc.set("model_scene", load(path))
	for k: String in r:
		if k != "model":
			npc.set(k, r[k])
