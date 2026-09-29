class_name ItemData
extends Resource
## Definición de un objeto de esperanza (ver tabla "Objetos de esperanza" del GDD).
## Crear nuevos objetos como .tres en assets/items/.

enum Kind { FOOD, COMIC, MOVIE, LETTER }

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var kind := Kind.FOOD

@export_group("Cordura")
## Cuánto sube la cordura al usarlo (no aplica a cartas: llenan la barra).
@export var sanity_restore := 10.0
## Reutilizables: cada nuevo uso rinde este factor del anterior.
@export_range(0.0, 1.0) var reuse_falloff := 0.6
## Cartas: cuánto aumenta la cordura máxima la primera lectura.
@export var max_sanity_bonus := 10.0
@export var requires_electricity := false

@export_group("Carta")
@export_multiline var letter_text := ""

@export_group("Mundo")
## Color del placeholder en el mundo hasta tener modelos.
@export var world_color := Color(0.6, 0.6, 0.6)


func is_consumable() -> bool:
	return kind == Kind.FOOD


func is_stackable() -> bool:
	return kind == Kind.FOOD
