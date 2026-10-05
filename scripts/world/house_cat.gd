class_name HouseCat
extends Area3D
## Teodoro, el gato del protagonista (pedido del usuario: un macho sin castrar, lleno de
## cicatrices de pelear, que hay que ir a buscar a la veterinaria).
## CAGED: en la veterinaria, hasta que se lo rescata (flag `cat_rescued`).
## HOME: en un refugio; solo está si ya se lo rescató y ese refugio es el activo. Acariciarlo
## baja la locura (con un rato de espera entre caricias) y, mientras está, el refugio
## calma más rápido (Shelter.cat_recovery_bonus).

enum Mode { CAGED, HOME }

const RESCUED_FLAG := &"cat_rescued"

@export var mode := Mode.HOME
## En modo HOME: el refugio donde vive (`home`, `hospital`, `theater`).
@export var refuge_id: StringName = &"home"
@export var model_scene: PackedScene
@export var model_scale := 1.0
@export var model_yaw := 0.0
@export var tint := Color(0.85, 0.75, 0.62)
@export var anim_idle: StringName = &""
@export var radius := 0.9
## Cordura que devuelve una caricia, y cada cuánto se puede.
@export var pet_relief := 8.0
@export var pet_cooldown := 90.0
@export var rescue_relief := 15.0

const PET_LINES := [
	"Teodoro ronronea como un motor viejo. Por un rato, el mundo se calla.",
	"Le rasco debajo del collar. Cierra los ojos y me empuja la mano con la cabeza.",
	"Me muerde despacio, sin apretar. Es su forma de decir que estoy acá.",
	"Tiene una cicatriz nueva en la nariz. \"Vos también estás peleando, eh\".",
	"Se acuesta arriba de mis pies. No me puedo mover. No quiero moverme.",
]
const TOO_SOON := [
	"Teodoro me mira con cara de \"ya está, humano\". Se lame una pata.",
	"Se va al otro rincón y se hace un bollo. Después, quizás.",
]

## Momento de la última caricia (compartido entre escenas).
static var _last_pet := -1000.0

var _model: Node3D
var _shape: CollisionShape3D
var _line := 0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	_shape = CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	_shape.shape = sphere
	_shape.position = Vector3.UP * 0.3
	add_child(_shape)
	if model_scene:
		_model = model_scene.instantiate()
		_model.scale = Vector3.ONE * model_scale
		_model.rotation_degrees.y = model_yaw
		add_child(_model)
		PS1Materials.apply(_model, tint)
		var anim := _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim and anim_idle != &"" and anim.has_animation(anim_idle):
			anim.get_animation(anim_idle).loop_mode = Animation.LOOP_LINEAR
			anim.play(anim_idle)
	GameState.flag_set.connect(func(_f: StringName) -> void: _refresh())
	Shelter.moved.connect(func(_r: StringName) -> void: _refresh())
	_refresh()


func is_present() -> bool:
	var rescued := GameState.has_flag(RESCUED_FLAG)
	if mode == Mode.CAGED:
		return not rescued
	return rescued and Shelter.is_active(refuge_id)


func _refresh() -> void:
	var present := is_present()
	visible = present
	_shape.disabled = not present
	if present:
		add_to_group(&"interactable")
	else:
		remove_from_group(&"interactable")


func interact(_player: Player) -> void:
	if not is_present():
		return
	if mode == Mode.CAGED:
		GameState.set_flag(RESCUED_FLAG)
		Sanity.restore(rescue_relief)
		Audio.play_sfx(&"cat_meow", global_position)
		GameState.post_message("Teodoro me reconoce. Bufa, me araña la mano y después se me tira encima, ronroneando. Lo meto en la transportadora: nos vamos a casa.")
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_pet < pet_cooldown:
		GameState.post_message(TOO_SOON[randi() % TOO_SOON.size()])
		return
	_last_pet = now
	Sanity.restore(pet_relief)
	Audio.play_sfx(&"cat_purr", global_position)
	GameState.post_message(PET_LINES[_line % PET_LINES.size()])
	_line += 1
