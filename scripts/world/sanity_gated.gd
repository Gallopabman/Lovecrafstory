class_name SanityGated
extends Node3D
## Muestra u oculta sus hijos según el estado de cordura (secretos del GDD:
## "cada zona tiene al menos un secreto visible solo con poca cordura").
## Al ocultarse también se desactiva la colisión de los hijos.

enum Mode {
	## Existe solo con poca cordura (símbolos, objetos, pasajes).
	REVEAL_WHEN_INSANE,
	## Existe solo con la mente sana (paredes que "mienten").
	HIDE_WHEN_INSANE,
}

@export var mode := Mode.REVEAL_WHEN_INSANE
## Estado a partir del cual se considera "con poca cordura".
@export_enum("Inquieto:1", "Quebrado:2", "Al borde:3") var threshold := 2


func _ready() -> void:
	Sanity.state_changed.connect(func(new_state: int, _old: int) -> void: _apply(new_state))
	_apply(Sanity.state)


func _apply(state: int) -> void:
	var insane := state >= threshold
	var present := insane if mode == Mode.REVEAL_WHEN_INSANE else not insane
	visible = present
	# Deshabilitar el procesamiento saca a los cuerpos hijos del mundo físico.
	process_mode = Node.PROCESS_MODE_INHERIT if present else Node.PROCESS_MODE_DISABLED
