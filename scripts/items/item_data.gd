class_name ItemData
extends Resource
## Definición de un objeto (ver "Objetos de esperanza" del GDD, más armas y munición).
## Crear nuevos objetos como .tres en assets/items/.

## MATERIAL: para las mejoras del refugio (se descarga solo al llegar a casa).
## KEY: abre algo del mundo (ZoneDoor.required_item); no se "usa" desde la mochila.
enum Kind { FOOD, COMIC, MOVIE, LETTER, WEAPON, AMMO, MATERIAL, KEY }

@export var id: StringName
@export var display_name := ""
## Abreviatura que se dibuja dentro de la cuadrícula del inventario.
@export var short_name := ""
@export_multiline var description := ""
@export var kind := Kind.FOOD
## Celdas que ocupa en la mochila (ancho x alto). Las cartas no ocupan lugar.
@export var grid_size := Vector2i(1, 1)
## Cuántos se apilan en un mismo lugar de la mochila (munición).
@export var max_stack := 1

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

@export_group("Arma")
## De fuego (se apunta y dispara) o cuerpo a cuerpo.
@export var is_ranged := false
@export var damage := 20.0
@export var attack_range := 1.8
## Segundos mínimos entre ataques.
@export var attack_cooldown := 0.6
## Armas de fuego: balas por cargador y qué objeto usa como munición.
@export var magazine_size := 0
@export var ammo_item: ItemData
## Radio en metros en el que los enemigos oyen el ataque (disparos).
@export var noise_radius := 0.0
## Perdigones por disparo (escopeta) y su abanico en grados. `damage` es por perdigón.
@export var pellets := 1
@export var pellet_spread := 0.0
## Sonidos del disparo y de la recarga (Audio, por nombre).
@export var shot_sound: StringName = &"gunshot"
@export var reload_sound: StringName = &"reload"
## Modelo que se sostiene en la mano (y se muestra en el piso como pickup).
@export var held_scene: PackedScene

@export_group("Mundo")
## Color del placeholder en el mundo y en la mochila hasta tener modelos e íconos.
@export var world_color := Color(0.6, 0.6, 0.6)
## Modelo del objeto tirado en el piso (si no hay, se usa `held_scene` o una caja de color).
@export var world_scene: PackedScene
## Tamaño en metros de su dimensión más grande en el piso.
@export var world_size := 0.25
## Rotación del modelo en el piso (para acostarlo o ponerlo de frente).
@export var world_rotation := Vector3.ZERO
## Colores por material del modelo del piso (p. ej. el cómic en otro color que la revista).
@export var world_tint := Color.WHITE
## Rotación del modelo "held" cuando está tirado en el piso como pickup.
@export var pickup_rotation := Vector3.ZERO


func is_letter() -> bool:
	return kind == Kind.LETTER


func is_weapon() -> bool:
	return kind == Kind.WEAPON


func is_material() -> bool:
	return kind == Kind.MATERIAL
