class_name SurvivorRig
## Animaciones del superviviente (Adventurer de Quaternius, rig "CharacterArmature").
## El modelo trae casi todo; lo que falta se completa en runtime:
## - salto: Jump / Jump_Idle / Jump_Land del alien de Quaternius (mismo rig, solo rotaciones)
## - agacharse: pose del primer cuadro del "Duck" del alien, y la caminata agachada
##   mezclando Walk con esa pose.
## Lo usan el jugador y los cuerpos que quedan en el refugio.

const EXTRA_SOURCE := preload("res://assets/models/enemies/tentacled/tentacled.glb")

const IDLE := &"CharacterArmature|Idle"
const WALK := &"CharacterArmature|Walk"
const RUN := &"CharacterArmature|Run"
const CROUCH_IDLE := &"CrouchIdle"
const CROUCH_WALK := &"CrouchWalk"
const JUMP := &"CharacterArmature|Jump"
const AIRBORNE := &"CharacterArmature|Jump_Idle"
const LAND := &"CharacterArmature|Jump_Land"
const HIT := &"CharacterArmature|HitRecieve"
const INTERACT := &"CharacterArmature|Interact"
const DEATH := &"CharacterArmature|Death"
const AIM := &"CharacterArmature|Idle_Gun_Pointing"
const SHOOT := &"CharacterArmature|Gun_Shoot"
const RELOAD := &"CharacterArmature|Interact"
const MELEE := &"CharacterArmature|Sword_Slash"
const PUNCH := &"CharacterArmature|Punch_Right"
## Hueso de la mano derecha (las escenas scenes/weapons/*_held.tscn están en su espacio).
const HAND_BONE := "Wrist.R"

const DUCK := &"CharacterArmature|Duck"
const LOOPING: Array[StringName] = [IDLE, WALK, RUN, AIRBORNE, CROUCH_WALK, CROUCH_IDLE]
## Cuánto de la pose agachada se mezcla en la caminata agachada.
const CROUCH_WALK_BLEND := 0.7


## Devuelve el AnimationPlayer del modelo con todas las animaciones listas.
static func setup(model: Node3D) -> AnimationPlayer:
	var player := model.find_child("AnimationPlayer") as AnimationPlayer
	var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	AnimationRetarget.import_animations(EXTRA_SOURCE, [JUMP, AIRBORNE, LAND, DUCK], player, skeleton)
	AnimationRetarget.make_pose(player, DUCK, 0.0, CROUCH_IDLE)
	AnimationRetarget.make_blend(player, WALK, DUCK, 0.0, CROUCH_WALK_BLEND, CROUCH_WALK)
	for clip in LOOPING:
		player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	return player
