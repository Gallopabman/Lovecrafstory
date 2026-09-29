class_name SurvivorRig
## Animaciones del superviviente: el modelo (Quaternius, esqueleto UE-mannequin) no
## trae animaciones; se cargan de la Universal Animation Library (CC0), que usa el
## mismo esqueleto. Lo usan el jugador y los cuerpos que quedan en el refugio.

const UAL1 := preload("res://assets/animations/ual/UAL1_Standard.glb")

const IDLE := &"Idle"
const WALK := &"Walk"
const RUN := &"Jog_Fwd"
const CROUCH_IDLE := &"Crouch_Idle"
const CROUCH_WALK := &"Crouch_Fwd"
## El impulso (Jump_Start) dura 1.3 s: el salto arranca directo en la pose en el aire.
const JUMP := &"Jump"
const AIRBORNE := &"Jump"
const LAND := &"Jump_Land"
const HIT := &"Hit_Chest"
## "Interact" dura 2 s; agarrar algo de una mesa es más ágil (0.8 s).
const INTERACT := &"PickUp_Table"
const DEATH := &"Death01"
const AIM := &"Pistol_Aim_Neutral"
const SHOOT := &"Pistol_Shoot"
const RELOAD := &"Pistol_Reload"
const MELEE := &"Sword_Attack"
const PUNCH := &"Punch_Jab"

const CLIPS: Array[StringName] = [IDLE, WALK, RUN, CROUCH_IDLE, CROUCH_WALK, JUMP, AIRBORNE, LAND,
	HIT, INTERACT, DEATH, AIM, SHOOT, RELOAD, MELEE, PUNCH]
const LOOPING: Array[StringName] = [IDLE, WALK, RUN, CROUCH_IDLE, CROUCH_WALK, AIRBORNE, AIM]
## La raíz y la pelvis también se mueven (agacharse baja el cuerpo, caminar tiene rebote).
const POSITION_BONES: Array[StringName] = [&"root", &"pelvis"]


## Devuelve el AnimationPlayer del modelo (lo crea si hace falta) con todas las animaciones.
static func setup(model: Node3D) -> AnimationPlayer:
	var player := model.find_child("AnimationPlayer") as AnimationPlayer
	if player == null:
		player = AnimationPlayer.new()
		player.name = "AnimationPlayer"
		model.add_child(player)
		player.root_node = NodePath("..")
	if not player.has_animation_library(&""):
		player.add_animation_library(&"", AnimationLibrary.new())
	var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	AnimationRetarget.import_animations(UAL1, CLIPS, player, skeleton, POSITION_BONES)
	for clip in LOOPING:
		player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	return player
