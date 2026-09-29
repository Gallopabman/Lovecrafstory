class_name RuntimeNavBake
extends NavigationRegion3D
## Hornea el navmesh al cargar el nivel, a partir de las colisiones de los nodos
## del grupo configurado en el NavigationMesh (las GreyBox generan su colisión
## en runtime, así que no alcanza con hornearlo en el editor).


func _ready() -> void:
	bake_navigation_mesh.call_deferred(false)
