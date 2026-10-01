class_name DifficultySpawn
extends Marker3D
## Un enemigo extra que solo existe desde cierta dificultad (pedido del usuario: "más
## enemigos" en Difícil e Insane). Se instancia al cargar la zona si ya se está en esa
## dificultad; si se llega a ella estando en la zona, aparece cuando el jugador está
## lejos (para que no salga de la nada adelante de él). Una vez que apareció, se queda
## hasta salir de la zona. Si se lo mata, no vuelve (la ruta del nodo es fija).

@export var enemy_scene: PackedScene
@export_enum("Difícil:1", "Insane:2") var min_difficulty := 1
@export var wander_radius := 4.0
## Distancia mínima al jugador para aparecer en medio de la visita.
@export var min_spawn_distance := 12.0

var _spawned := false
var _waiting := false


func _ready() -> void:
	if Sanity.difficulty >= min_difficulty:
		_spawn()
	else:
		Sanity.difficulty_changed.connect(_on_difficulty_changed)


func _process(_delta: float) -> void:
	if not _waiting:
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null or player.global_position.distance_to(global_position) >= min_spawn_distance:
		_waiting = false
		_spawn()


func _on_difficulty_changed(level: int, _previous: int) -> void:
	if level >= min_difficulty and not _spawned:
		_waiting = true


func _spawn() -> void:
	if _spawned or enemy_scene == null:
		return
	_spawned = true
	var enemy := enemy_scene.instantiate()
	enemy.name = "Enemy"
	enemy.set(&"wander_radius", wander_radius)
	add_child(enemy)
