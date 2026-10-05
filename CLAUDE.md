# Lovacrafstory — contexto del proyecto

Survival horror lovecraftiano en **Godot 4 (GDScript)** con estética **PS1**, referencia principal *Silent Hill 1*.

**GDD** (Claude Doc, se lee con las herramientas de Claude Docs: `read` del proyecto
`212ba42d-bd76-4a44-af99-7b30acedab7e`, tab body `9e7249db-fd89`):
https://claude.ai/code/artifact/212ba42d-bd76-4a44-af99-7b30acedab7e
Es la fuente de verdad del diseño. Si algo no está ahí ni acá, preguntarle al usuario (Gallo)
en vez de inventarlo.

## Resumen del GDD

- **La cordura es todo**: no hay hambre ni sed; comida, refugio y entretenimiento desembocan en un medidor.
  - **Baja**: goteo constante (más lento en el refugio, según su nivel "cozy"), ver horrores
    (sobre todo por primera vez), recibir daño, eventos perturbadores.
  - **Sube**: comida (consumible, cocinada rinde más), cómics/libros (reutilizables, rinden menos
    al releer), películas/música (reutilizables, requieren electricidad), **cartas** (únicas: llenan
    la barra **y aumentan la cordura máxima**, cuentan el lore), y el bono de llegar a casa.
  - **Estados** (% de la cordura máxima): Lúcido 100–70, Inquieto 70–40, Quebrado 40–15,
    Al borde 15–1, Perdido 0. Menos cordura = más horrores, niebla, oscuridad y revelaciones;
    parte de los horrores extra son alucinaciones inofensivas.
- **Cordura 0 fuera de casa** → el personaje se convierte en **el Perdido** (mini-jefe que vaga por
  la zona donde cayó, con lo que llevaba encima y habilidades según cómo se jugó) y un nuevo
  sobreviviente empieza en el mismo refugio. Se conservan refugio y mundo; se pierde el inventario.
- **Cordura 0 dentro del refugio** (decisión del usuario, no está en el GDD) → muere de un ataque
  cardíaco y **el cuerpo queda en el piso** con todo lo que llevaba; el siguiente puede revisarlo.
- **Inventario estilo Resident Evil**: mochila en cuadrícula (6x4), cada objeto ocupa su tamaño y
  se puede mover, girar y tirar. Las cartas van en una lista aparte y no ocupan lugar.
- **Combate** (decisión del usuario, responde la pregunta abierta del GDD): armas de fuego y cuerpo a
  cuerpo. Fuego: apuntar deja quieto, auto-apuntado al enemigo más cercano (estilo SH1), cargador +
  munición en la mochila, los disparos atraen enemigos, **la locura abre la dispersión**. Cuerpo a
  cuerpo: golpe en arco; sin arma, trompadas. Los enemigos muertos no reaparecen.
  **Las armas no se gastan** (por ahora) y **matar un horror devuelve un poco de cordura** (+5).
- **Refugio**: blueprints de slots fijos (fuego, electricidad, cama, decoración, ventanas,
  estaciones). Un solo refugio activo; mudarse es una decisión. Bono de llegada según logros de la salida.
- **Mundo interconectado** ("lineal abierto", atajos estilo RE2/Dark Souls). Primer tramo:
  refugio → edificio → calle → teatro. Hoy: **casa** (refugio inicial) → el barrio (la plaza) → hospital →
  avenida → teatro. Cada zona tiene un secreto visible solo con poca cordura.
- **Cámaras**: fijas en interiores, libre en exteriores (pendiente).
- **HUD** (cambio del usuario, antes no había): barras de **vida** y **locura** siempre visibles arriba a la
  izquierda, y la dificultad cuando no es Normal ([scripts/ui/hud.gd](scripts/ui/hud.gd), nodo `Hud` de game_ui).

## Decisiones técnicas

- Godot **4.7**, renderer **Forward+**. Sin C#: todo en GDScript.
- Resolución interna **640x480** ("PS1 mejorado", elegido por el usuario: `stretch/mode="viewport"`,
  escala entera, 4:3). Ventana 1280x960. La UI está diseñada en 320x240 y su CanvasLayer escala x2
  (los paneles de pantalla completa son de 320x240 fijo, no anclados). Jitter a 640x480 (160x120 al
  borde), post-proceso 64 niveles de color (12 al borde). Texturas de ambiente a 128 px, de props a 256.
- **Look PS1**:
  - [shaders/ps1_spatial.gdshader](shaders/ps1_spatial.gdshader): vertex snapping, mapeo afín,
    texturas nearest, luz por vértice, niebla propia (`FOG`), texturas que "respiran" con la locura.
    Usarlo para **toda** la geometría. Para modelos importados: `PS1Materials.apply(nodo)`
    ([scripts/world/ps1_materials.gd](scripts/world/ps1_materials.gd)) convierte sus materiales.
  - [shaders/ps1_post_process.gdshader](shaders/ps1_post_process.gdshader): color 15 bits + dithering;
    con la locura degrada color, desatura, viñeta, grano y ondula; con un susto separa canales.
    CanvasLayer 100 ([scenes/effects/ps1_post_process.tscn](scenes/effects/ps1_post_process.tscn)).
  - Globales de shader (`[shader_globals]` en `project.godot`): `ps1_fog_color`, `ps1_fog_start`,
    `ps1_fog_end`, `ps1_snap_resolution`, `ps1_insanity` (0..1), `ps1_shock` (0..1).
    Los escribe **solo** `Atmosphere` ([scripts/world/atmosphere.gd](scripts/world/atmosphere.gd)),
    que interpola entre valores "Lúcido" y "Al borde" según `Sanity.insanity()`.
- **Autoloads**:
  - `Sanity` ([scripts/autoload/sanity_manager.gd](scripts/autoload/sanity_manager.gd)): por dentro, la
    cordura (`current`, estados, refugios, horrores vistos, `lost` + `lost_in_refuge`); **en pantalla es la
    locura** (`madness()` = 1 - cordura, pedido del usuario): afuera sube con el goteo, en el refugio activo
    baja (`refuge_recovery_per_second` x `RefugeZone.current_recovery_multiplier()`, que en los refugios sale
    del cozy: x1 pelado → x3 completo). `add_madness()` = susto/grito. `take_hit()` = golpe físico: lo pasa a
    `Health`. **Dificultad** según la locura (`difficulty`, señal `difficulty_changed`): Normal < 50 %, Difícil
    50-75 %, Insane > 75 % (el usuario escribió los rangos al revés, en términos de cordura; se interpretó así).
    `player_damage_multiplier()` [1, 0.8, 0.6] y `damage_taken_multiplier()` [1, 1.35, 1.75].
  - `Health` ([scripts/autoload/health.gd](scripts/autoload/health.gd)): la vida (100). `take_damage` aplica
    la dificultad; en 0, `died` (el cuerpo queda donde cayó, con lo que llevaba, siempre) y `Sanity.end_life()`.
    Cura con comida (`health_restore`), remedios (kind MEDICINE: vendas, botiquín) y descansando (`rest_health`).
  - `Inventory` ([scripts/autoload/inventory.gd](scripts/autoload/inventory.gd)): cuadrícula
    `grid_size`, entradas `{item, cell, rotated}`, `letters` aparte; `add()` devuelve false si no
    entra; `use(item, entry)`, `move`, `drop` (emite `item_dropped`).
  - `Shelter` ([scripts/autoload/shelter.gd](scripts/autoload/shelter.gd)): el refugio como hogar.
    Blueprint `SLOTS` (fuego, electricidad, cama, ventanas, decoración; 2 niveles cada uno, costo en
    materiales, +1 cozy por nivel), `stock` de materiales, `cozy()` → `drain_multiplier()` (x0.6 pelado
    → x0.1 completo), `has_electricity()` (generador), estaciones `cook()` / `rest()` / `play_radio()`,
    `discover(place)` y el bono de llegar a casa (lugares nuevos + objetos + cartas de la salida, tope
    30). Persiste entre sobrevivientes.
    **Alijo** (pedido del usuario): nada se guarda solo al llegar; hay que dejarlo en el alijo
    (`ShelterStation` kind STASH → `StashMenu`, [scripts/ui/stash_menu.gd](scripts/ui/stash_menu.gd): mochila a la
    izquierda, alijo a la derecha, E pasa, X deja todos los materiales). `Shelter.stash` (entradas sin
    celda; las pilas ocupan un lugar), `store()`, `take()` (usa `Inventory.add_entry`, todo o nada),
    `store_materials()`. Los materiales van al depósito de construcción (`stock`), no ocupan lugar. Espacio
    `stash` del plano: caja de cartón (8) → baúl (16) → armario con candado (28) (`stash_capacity`, no suma
    cozy). Hay uno solo: se usa en el refugio activo, viaja al mudarse y sobrevive a la muerte.
    **Varios refugios** (`REFUGES`: `home` (el inicial), `hospital`, `theater`), uno solo `active`: cada uno tiene sus mejoras
    (`refuge_levels`; casi todas las funciones aceptan `refuge`, vacío = el activo). `move_to()` = mudarse
    (se decide desde el plano de un refugio que no es el activo; los materiales viajan). `RefugeZone`,
    `ShelterSlot` y `ShelterStation` tienen `refuge_id`; la zona solo cuenta como refugio si es el activo.
    Los sobrevivientes nuevos llegan a `refuge_scene()` en el SpawnPoint `refuge`.
  - `GameState` ([scripts/autoload/game_state.gd](scripts/autoload/game_state.gd)): persiste entre
    sobrevivientes (pickups recogidos por ruta de nodo, objetos tirados, cuerpos y `lost_ones`, los tres
    **por escena**; enemigos muertos, `flags` del mundo, número de sobreviviente) y `post_message()`.
    `playstyle` junta estadísticas del sobreviviente actual (`track(&"shots")`, `melee`, `run_time`,
    `crouch_time`) para el Perdido. Viajes: `travel(escena, spawn)` + `next_spawn`; `new_survivor()`
    carga el refugio activo de `Shelter` (o `refuge_scene` si no está vacía: los tests usan la sala de prueba); `new_game()` reinicia todo. `change_scene()`
    hace un fundido a negro (lo usan todos los cambios de escena del juego); `pending_player` = posición al cargar.
  - `Audio` ([scripts/autoload/audio.gd](scripts/autoload/audio.gd)): busca sonidos **por nombre** en
    `assets/audio/{sfx,ambience,music}/` (`step` = `step.ogg` o variantes `step_1`, `step_2`... al azar;
    si no existe, no suena y no falla). `play_sfx(nombre, posición 3D opcional)`, `play_ui`,
    `set_ambience`, `play_music`, latido automático desde Quebrado, susto al ver un horror nuevo.
    Buses Master / Music / SFX / Ambience (se crean en runtime). Volumen general en `user://settings.cfg`.
  - `SaveGame` ([scripts/autoload/save_game.gd](scripts/autoload/save_game.gd)): **guardado a disco**, un solo
    espacio en `user://save.dat` (texto de `var_to_str`; objetos por ruta de recurso). Junta `save_data()` /
    `load_data()` de GameState, Inventory, Sanity y Shelter + escena + posición del jugador. Manual desde la
    pausa; automático al llegar a otra zona (`Player._place_at_spawn`) y al entrar al refugio. `new_game()`
    reinicia todo. **Los tests usan `path = "user://test_save.dat"`** para no pisar la partida del usuario.
- **Objetos**: `ItemData` ([scripts/items/item_data.gd](scripts/items/item_data.gd)), un `.tres` por
  objeto en `assets/items/` (`grid_size`, `short_name` de 3 letras para la cuadrícula).
  En el mundo: [scenes/world/pickup.tscn](scenes/world/pickup.tscn), con su modelo `world_scene`
  ([assets/models/items/](assets/models/items/)) a `world_size` metros (lo más largo), `world_rotation` y
  `world_tint` (el cómic y la revista comparten modelo). Los objetos chicos van un poco agrandados para que
  se lean. Sin `world_scene`: armas con `held_scene`; si no, una caja del color `world_color`.
- **Componentes de mundo** (`scripts/world/`): `GreyBox` (blockout con malla subdividida),
  `RefugeZone` (Area3D: goteo reducido + electricidad), `SanityGated` (muestra/oculta hijos
  y su colisión según el estado), `HorrorSighting` (baja cordura la primera vez que se ve),
  `WorldPersistence` (reconstruye objetos tirados y cuerpos al cargar), `Corpse`,
  `RuntimeNavBake` (hornea el navmesh al cargar desde el grupo `nav_source`).
- **Enemigos** (`scripts/enemies/`): `Stalker` — deambula, persigue si ve, oye correr u oye un
  disparo (`hear_noise`), golpea la cordura; tiene vida (`take_damage`), se tambalea, destella en rojo
  y muere (queda el cuerpo, `GameState.mark_killed`). Grupo `enemies`. Usa NavigationAgent3D.
  Sonidos por export (`sound_idle`, `sound_alert`...). Hooks para subclases: `_start_attack(anim)`,
  `_attack_connects()`, `_chase`, `_attack`, `_die`, `_key`.
- **El Perdido** ([scripts/enemies/lost_one.gd](scripts/enemies/lost_one.gd), `LostOne extends Stalker`,
  [scenes/enemies/lost_one.tscn](scenes/enemies/lost_one.tscn)): el Adventurer oscurecido con ojos rojos,
  220 de vida, +20 de cordura al matarlo. Lo crea `WorldPersistence` donde cayó el sobreviviente; lleva el
  arma que tenía en la mano. Estilo según `playstyle` (`dominant_style`): **tirador** (dispara de lejos si
  tenía arma de fuego), **bruto** (pega fuerte y seguido), **corredor** (persigue a 4.2 m/s), **sigiloso**
  (sin ruido, solo se ve de cerca), **errante** (nada especial). Al morir suelta todo lo que llevaba.
- **Jefes** ([scripts/enemies/boss.gd](scripts/enemies/boss.gd), `Boss extends Stalker`): duermen invisibles hasta
  `awaken()` (un `BossTrigger` o recibir daño), no se tambalean hasta acumular `stagger_threshold`, gritan
  a distancia media (baja cordura), se enfurecen a la mitad de la vida, música `boss_music`. Al morir marcan
  `death_flag`. `FlagGate`: bloqueo que desaparece cuando se marca un flag (`GameState.flag_set`).
- **Combate** ([scripts/player/player_combat.gd](scripts/player/player_combat.gd), nodo `Combat` hijo
  del jugador; su `setup()` lo llama Player): apuntar/disparar/recargar, cuerpo a cuerpo, arma en la
  mano vía BoneAttachment3D en `hand_r`. Las escenas `scenes/weapons/*_held.tscn` están en metros en
  el espacio del hueso (si el esqueleto viene escalado se compensa al equipar).
  Armas = `ItemData` kind WEAPON (grupo "Arma": `is_ranged`, `damage`, `magazine_size`, `ammo_item`,
  `noise_radius`, `held_scene`, `pellets` + `pellet_spread` para la escopeta, `shot_sound`, `reload_sound`);
  munición = kind AMMO con `max_stack`. Escopeta: 7 perdigones de 11, 2 cartuchos, 14 m; los perdigones
  que pegan en el mismo enemigo se suman en un solo golpe. Kind KEY = llaves (`key_theater`).
- **Capas de colisión**: 1 escenario + jugador, 2 enemigos, 3 interactuables.
- **Interacción**: el jugador busca Areas del grupo `interactable` (capa 3) y llama `interact(player)`.
- **UI** ([scenes/ui/game_ui.tscn](scenes/ui/game_ui.tscn), CanvasLayer 50): menú de inventario (pausa
  el juego; entrada propia en `_input`): barras de encabezado y pie, paneles Mochila / Cartas / Cordura
  (estado con color y una frase) / Detalle (vista previa grande del objeto), ayudas de teclas con color.
  La cuadrícula `InventoryGrid` dibuja celdas con bisel, cursor que late e **íconos** hechos con
  primitivas (`ItemIcon.draw_icon`, [scripts/ui/item_icon.gd](scripts/ui/item_icon.gd): lata, botella,
  cómic, VHS, carta, pistola, barreta, balas, materiales). Lector de cartas en papel, avisos, muerte.
  Layout (320x240): título "SOBREVIVIENTE #N" y zona arriba; mochila y cartas a la izquierda; cordura y
  detalle a la derecha (los datos del arma van debajo del nombre para dejarle lugar a la descripción); el
  resultado de usar algo reemplaza unos segundos a la ayuda del pie. Las posiciones están fijas en el .tscn:
  al tocarlas con scripts, cuidar de no pisar las de otros nodos (ya pasó una vez).
  Tema global [assets/ui/ps1_theme.tres](assets/ui/ps1_theme.tres), Pixel Operator 8px (botones y sliders
  incluidos).
- **Menú de inicio** ([scenes/ui/main_menu.tscn](scenes/ui/main_menu.tscn), **escena principal**): niebla
  animada ([shaders/menu_fog.gdshader](shaders/menu_fog.gdshader)), Continuar (si hay partida, con un
  resumen), Jugar (partida nueva → la casa), Opciones (solo volumen general, pedido del usuario) y Salir.
  Música `menu_music`. Las opciones son una escena aparte ([scenes/ui/options_panel.tscn](scenes/ui/options_panel.tscn),
  `OptionsPanel`) que también usa la pausa.
- **Menú de pausa** (`PauseMenu` en `game_ui.tscn`, Esc / Start): Continuar, Guardar partida, Opciones,
  Menú principal, Salir del juego. No se abre con otro menú abierto ni muerto.
- **Dificultad en el mundo**: `DifficultySpawn` ([scripts/world/difficulty_spawn.gd](scripts/world/difficulty_spawn.gd)): un
  enemigo extra desde Difícil o Insane (se instancia al cargar, o lejos del jugador si se llega a esa dificultad
  en la zona). Todos los niveles tienen `ExtraHard*` / `ExtraInsane*` (helper `_extra_enemy` de los
  generadores). `SanityGated.use_difficulty`: secretos y recompensas por dificultad (helper `_difficulty_gate`):
  la **armería del hospital** detrás de Seguridad (Difícil: escopeta, cartuchos, botiquín), la **pistola en la
  fuente de la plaza** (Insane: el portón deja de existir), el depósito de evidencias de la comisaría (Difícil),
  el calabozo 3 (Insane) y la cripta de la iglesia (Insane).
- **Puertas visibles** (pedido del usuario: que se note cuáles se pueden cruzar): [assets/models/doors/](assets/models/doors/)
  (`door_wood_open`, `door_metal_open` entreabiertas con una ranura oscura; `door_boarded` tapiada;
  `door_chained` con cadenas y candado). Una `ZoneDoor` muestra sus hijos `OpenDoor` / `LockedDoor` según esté
  abierta (helper `_zone_door_visuals`; con `facade` la hoja se abre hacia afuera y atrás hay un hueco oscuro,
  para fachadas sin abertura real). `FlagGate.open_model` aparece al abrirse. Las puertas que no se cruzan
  están tapiadas o encadenadas. Los SpawnPoint quedan a ~2.5 m de la puerta (si no, la cámara queda contra el modelo).
- **Zonas y puertas**: `ZoneDoor` (Area3D interactuable: `target_scene`, `target_spawn`, opcionalmente
  `required_item` + `unlock_flag` para forzarla una vez) y `SpawnPoint` (Marker3D con `spawn_id`; el
  jugador aparece mirando a su -Z). `LevelAudio` fija el ambiente, los pasos y un zumbido que crece con la
  locura; `LoopSound` es un sonido en loop en un punto (fuego, generador).
- **Input** (teclado / gamepad): `move_*`, `look_*` (stick der.), `run` (Shift / B), `jump`
  (Espacio / A), `crouch` (C o Ctrl / L3, alterna), `interact` (E / X), `flashlight` (F / cruceta arriba), `reload` (R / Y),
  `aim` (clic der. / L2), `attack` (clic izq. / R2), `menu` (Tab o I / Back), `pause` (Esc / Start).
  En el menú: usar (E, Enter / A), `inventory_move` (R / X), `inventory_rotate` (Q / RB),
  `inventory_drop` (X / Y). En el menú "usar" solo acepta la E del teclado, no `interact` del gamepad.
- **Personajes**:
  - Superviviente: el Adventurer de Quaternius ([assets/models/characters/survivor/survivor.glb](assets/models/characters/survivor/survivor.glb)).
    Se probó un modelo realista (cabeza UBC + ropa "Peasant" + Universal Animation Library) y **el usuario lo
    rechazó por medieval**; tampoco sirvió el "survival character" de Daren (malla y rig desalineados).
    `SurvivorRig.setup(model)` ([scripts/player/survivor_rig.gd](scripts/player/survivor_rig.gd)) completa las
    animaciones: salto y "Duck" copiados del rig del alien (mismo rig Quaternius), `CrouchIdle` y `CrouchWalk`
    generados. Todos los nombres de clips y el hueso de la mano (`Wrist.R`) están en `SurvivorRig`.
    `tools/blender/build_survivor.py` queda como referencia de cómo armar un personaje con Blender headless.
  - Enemigo: Thin Zombie (Rosswet Mobile, **CC-BY**) a escala 0.27 (el glb mide 8.4 m), textura aparte
    (`Stalker.albedo_texture`); los nombres de sus animaciones son exports del `Stalker`.
- **Agacharse / sigilo**: `Player.set_crouching()` (cápsula 1.2 m, 1.2 m/s, cámara baja; no se para
  con techo bajo; correr, saltar o apuntar lo pone de pie). `Player.visibility()` (agachado x0.5, linterna x1.4) escala
  la vista del `Stalker`; agachado te nota de 1 m en vez de 2.5; mira a `Player.eye_height()` (1.4 / 0.85),
  así que agacharse detrás de algo bajo (mostrador, cama, escritorio) corta la línea de visión.
  Debug: F3 overlay, F9 golpe, F10 −25 %, F11 +25 %.
- Assets de terceros: registrar siempre en [CREDITS.md](CREDITS.md) (preferir CC0; los CC-BY
  necesitan atribución en los créditos del juego).

## Zona 0: la casa y el barrio (el comienzo)

**Historia** (del usuario): el protagonista era adicto a las drogas por una depresión severa y está en
recuperación. Su madre es médica (en el juego, "Dra. M. Ibáñez", guardia del San Judas: el nombre lo
inventé yo, confirmarlo con el usuario) y guardó sus insumos médicos bajo llave en el ático para que él no
recaiga. La nota de mamá dice que la llamaron del San Judas por la niebla: eso lleva al hospital.
- **Casa** ([scenes/levels/home.tscn](scenes/levels/home.tscn), [tools/build_home.gd](tools/build_home.gd)): refugio
  inicial `home` (13 x 10 m): pieza (cama y alijo), baño (la cajita azul), living (hogar = fuego, tele, radio,
  ventanas), cocina (plano en el corcho, la nota de mamá) y la escalera al ático. El ático (x 0-7.5, piso a
  2.9 m) está cerrado: `FlagGate` con el flag `attic_open`, que nadie marca todavía. Mensaje (texto del
  usuario, ajustado): "No puedo entrar ahí. Mi madre se llevó la llave cuando guardó sus estúpidos
  medicamentos. Piensa que voy a recaer." Adentro: cajas, sueros, oxígeno, jeringas, una cama de hospital y
  el **jefe del ático** (`Enemies/AtticThing`, [scenes/enemies/attic_boss.tscn](scenes/enemies/attic_boss.tscn),
  dormido, flag de muerte `attic_boss_dead`). Modelo: 3D Horror Game Monster (CC0, sin cara, boca vertical);
  no trae ataque ni muerte: se arman con `Stalker.generated_animations` (`AnimationRetarget.make_sequence`):
  ataque con dos cuadros de `Poses`, muerte = `Jump` al revés (se hunde en el piso), `Jump` = aparición.
- **El barrio** ([scenes/levels/park_street.tscn](scenes/levels/park_street.tscn),
  [tools/build_park.gd](tools/build_park.gd), extiende build_street.gd; escena `ParkStreet`). Pedido del usuario:
  "por lo menos 10 veces más grande" que la cuadra original y con los objetos espaciados. Cuadrícula de calles de
  12 m: **Larrea** (z 0, x 0-180, la de casa), **Rondeau** (z -60, x 24-168) y tres transversales (Sarmiento x 42,
  Moreno x 96, Pichincha x 150). Un **socavón** corta Larrea en x 103-114: para llegar al hospital hay que subir por
  Moreno o Sarmiento, seguir por Rondeau y bajar por Pichincha. Sin salida: el camión volcado (oeste), escombros en
  las dos puntas de Rondeau, el estacionamiento del Autoservicio Los Andes y el **Pasaje Ombú** (sale de Moreno).
  Manzanas con `_frontage()` (edificios del kit uno al lado del otro, ladrillo en los huecos, límite invisible).
  La plaza (x 0-84, z 6-46) sigue enrejada, con el portón en x 42 (Insane: pistola en la fuente).
  **La guardia del San Judas** (x 180-206): patio de ambulancias con marquesina roja "GUARDIA" sobre columnas,
  andén de 0.45 m con rampas y escalones, vestíbulo de vidrio con puertas corredizas (la `ZoneDoor`), cruz roja,
  carpa de triage, garita con la barrera rota, la ambulancia de mamá (el gafete). Spawn `from_hospital` en el andén.
  **Lore de la recuperación** (el protagonista es ex adicto con depresión): el Centro de Día Renacer (la carta del
  padrino debajo de la puerta), la Farmacia Aldo (le vendía recetas truchas), el cartel de NA en el poste de Moreno
  (reuniones en la parroquia), el banco de la plaza y el Pasaje Ombú, "la esquina del Flaco" (donde compraba):
  "UNA SOLA NO ES NADA" en Inquieto y el Flaco esperándolo en Quebrado. Nombres inventados (Flaco, Don Aldo):
  confirmar con el usuario. Pocos objetos (9), casi todos en rincones sin salida.
  Secretos: una figura en las hamacas (Inquieto), la "Carta a mí mismo" debajo del banco (Quebrado) y "MAMÁ ESTÁ
  ADENTRO" en el vidrio de la guardia (Inquieto).

## Zona 1: Hospital San Judas

[scenes/levels/hospital.tscn](scenes/levels/hospital.tscn) es la segunda zona (se entra por la puerta de guardia, al oeste del pasillo, desde el barrio; la sala de
prueba queda para los tests). La generó [tools/build_hospital.gd](tools/build_hospital.gd), un andamio
de **una sola pasada**: si ya se editó la escena en el editor, no volver a correrlo (pisa los cambios);
modificar la escena a mano o actualizar el script y avisar.
- Planta de 36x20 m, dos pisos de 3.5 m. PB: refugio (sala del personal, NE), farmacia,
  consultorios, seguridad (barreta), hall/recepción/sala de espera, baños. P1: internación (6 camas),
  quirófano, dirección (pistola + carta del Dr. Ferreyra), enfermería, depósito a oscuras, archivo y
  cuarto tapiado (secreto: aparece en Quebrado; carta de Marta).
- Límites reales: ventanas con rejas soldadas, entrada encadenada, ascensor muerto. La **salida de
  emergencia** (PB este, x 36) es un `ZoneDoor` a la calle: se fuerza una vez con la barreta
  (flag `hospital_exit_forced`); volviendo se aparece en `from_street`. Escalera recta con rampa
  invisible + `NavigationLink3D`. Ambiente `hospital`; el fuego y el generador del refugio suenan.
- Lore: el hospital se aisló el día 9 de la niebla; Ferreyra soldó las rejas "para que nadie salga".
  Los `Inspectable` (E) cuentan la historia con textos cortos.
- **Refugio opcional** (sala del personal, PB NE; ya no es el inicial, se puede mudar acá): arranca pelado (colchón en el piso, generador roto, una
  vela). El plano en la pared (`ShelterStation` BLUEPRINT) abre `ShelterMenu`. Cada espacio es un
  `ShelterSlot` cuyos hijos `Only<n>` / `From<n>` se muestran según el nivel (props, luces y estaciones
  COOK / REST / RADIO adentro). Materiales repartidos por el hospital (madera 8, chatarra 5, sábanas 6,
  cables 3): alcanzan para las primeras mejoras, no para todas. `DiscoveryZone` por ambiente.
  La `RefugeZone` usa `use_shelter` (goteo y electricidad salen de `Shelter`).
- Componentes nuevos: `Prop` (@tool, modelo + escala por `fit_height`/`fit_largest` + anchor
  FLOOR/CEILING/WALL + colores por material + colisión de caja), `Inspectable`, `FlickerLight`;
  `GreyBox` ahora tiene `mesh_visible` / `collision_enabled`; el shader PS1 tiene `emission_color`.
- Muebles de Kenney: el frente mira a +Z; escalar por altura real (sus transformaciones internas
  varían). Modelos de Poly Pizza: medirlos dentro de un `Prop`, no a mano (la escala engaña).

## Zona 2: la avenida

[scenes/levels/street.tscn](scenes/levels/street.tscn), generada por [tools/build_street.gd](tools/build_street.gd)
(mismas reglas: una sola pasada). Exterior con niebla clara y espesa (fin a 20 m) y luz de cielo tapado.
- Avenida de dos manos de x 0 (fachada trasera del hospital, ladrillo, puerta de emergencia) a x 65
  (Teatro Imperio: marquesina con lamparitas prendidas, puertas encadenadas: **la próxima zona**).
  Edificios del Downtown City MegaKit (Quaternius) a los dos lados, cada uno con su caja de colisión sin
  el porche. Autos abandonados (Car Kit de Kenney, x1.5), la ambulancia del San Judas chocada,
  faroles casi todos muertos.
- Barricada policial en x ~50 (patrulleros, van, conos, vallas): se pasa solo por la vereda norte.
- Callejón al norte (x 33–38) que lleva a un patio de servicio cerrado con un auto quemado.
- Secreto: en el patio, "ELLA TE ESPERA EN EL IMPERIO" (Inquieto) y un ladrillo flojo que desaparece en
  Quebrado → nicho con la **segunda carta de Marta**. En el patrullero, el **parte del Cabo Ríos**.
  Una revista (Inspector Aguirre), comida, balas y materiales. Cuatro acechadores; alucinación bajo la
  marquesina.
- Piezas modulares con `Prop.anchor = ORIGIN` (respeta el origen del modelo). Paredes de ladrillo con
  piezas de una cara: `_brick_wall` pone otra de espaldas. Los `Label3D` no usan el shader PS1: se
  desvanecen con `visibility_range_end` para no atravesar la niebla.
- **Casas** (pedido del usuario: "pequeñas casas" detrás de las puertas laterales): cuatro puertas de la
  avenida son `ZoneDoor` a escenas chicas en [scenes/levels/street_houses/](scenes/levels/street_houses/),
  generadas por [tools/build_houses.gd](tools/build_houses.gd) (que **extiende build_hospital.gd** para
  reusar muebles y paredes). Depto. de los Ibarra (living y cocina), Almacén La Estrella (un acechador entre
  los estantes), Relojería Kaufmann (relojes parados a las 3:15; texto que aparece en Quebrado) y Pensión
  Doña Rosa, pasando la barricada (pieza del agente Sosa: su cuaderno, y un acechador). Las otras puertas
  son `Inspectable` "cerrada". Spawn en la calle: `house_<id>`; adentro: `inside`.

## Zona 2b: la comisaría y la iglesia (pedido del usuario: "dos zonas nuevas" en la avenida)

Generadas por [tools/build_avenue_places.gd](tools/build_avenue_places.gd) (extiende build_hospital.gd). Se entra por
dos puertas de la avenida (spawn de vuelta `house_comisaria` / `house_iglesia`; adentro, `inside`).
- **Comisaría 12** ([scenes/levels/police_station.tscn](scenes/levels/police_station.tscn)): mesa de entradas (el
  **libro de guardia**: Kaufmann preso el día 3, desaparecido del calabozo 2), oficina del comisario (el expediente
  de Elena de Sosa), sala de guardia (el locker de Sosa), tres calabozos. Secretos: el **depósito de evidencias**
  detrás de la guardia (Difícil: cartuchos, balas, botiquín) y el **calabozo 3** (Insane: "ACÁ ESTUVO TU MADRE").
- **Parroquia San Judas Tadeo** ([scenes/levels/church.tscn](scenes/levels/church.tscn)): nave con bancos y vitrales,
  altar con la imagen del santo, confesionario (alguien respira del otro lado), sacristía (**diario del padre
  Ernesto**). En Insane se abre la trampa frente al altar: escalera a la **cripta** (a -3 m) con la **carta de
  Elena (1979)** (su depresión, su hijo Rodolfo = el agente Sosa), un botiquín y cartuchos. En Inquieto, una
  mujer arrodillada en la primera fila.

## Zona 3: Teatro Imperio

[scenes/levels/theater.tscn](scenes/levels/theater.tscn), generada por [tools/build_theater.gd](tools/build_theater.gd)
(extiende build_hospital.gd). Se entra desde la avenida con la **llave del candado** (en la pieza de Sosa,
pensión); flag `theater_unlocked`.
- Vestíbulo (alfombra roja, araña, boletería, guardarropa, escalera al pullman derrumbada, la gorra de Sosa
  y **la escopeta**), sala con 12 filas de butacas y pasillos, escenario a 1.1 m con rampas, telón, candilejas
  y piano; bambalinas (camarín 2, depósito de utilería con un acechador) y el **camarín principal**.
- **La cantante** (`Enemies/Singer`, [scenes/enemies/boss.tscn](scenes/enemies/boss.tscn)): 700 de vida, despierta
  al acercarse al escenario. Al morir: `theater_boss_dead` → se destraba el camarín principal (`FlagGate`).
- **Segundo refugio** (`theater`): el camarín principal, con sus 5 espacios (brasero/estufa, luces del espejo
  con el grupo electrógeno, cama, ventana, fotos y flores) y su plano. Arranca como "no es mi refugio": el
  plano ofrece mudarse. Última carta de Marta en el tocador.
- Secretos: "FILA 7 / BUTACA 13" (Inquieto) y una sala de ensayo detrás del vestíbulo (Quebrado) con el
  programa de 1979; en Quebrado, figuras paradas en los pasillos y "ELLA CANTA PARA VOS" en el telón.
- Lore: la soprano Elena M. de Sosa (la mamá del agente) cantó "La Paloma" en 1979 y no volvió; el maestro
  Kaufmann (el relojero) la acompañaba. La cantante "se viste con lo que recordamos".

## Estructura

```
assets/      modelos, texturas, materiales, items (.tres), fuentes, ui
scenes/      .tscn por dominio (player, levels, world, enemies, effects, ui)
scripts/     .gd por dominio (player, world, items, ui, autoload)
shaders/     .gdshader
tests/       scripts de test (extends SceneTree)
tools/       generadores de contenido (extends SceneTree, se corren una vez)
```

## Convenciones

- GDScript con **tipado estático**, indentación con **tabs**.
- Archivos y carpetas en `snake_case`; `class_name` en PascalCase (los autoloads no llevan `class_name`).
- Identificadores en inglés; comentarios, textos del juego y documentación en español rioplatense.
- Valores ajustables como `@export`; no hardcodear números de gameplay.
- Los sistemas globales se comunican con señales.

## Correr / verificar

Godot **4.7.2** (no está en el PATH):
`C:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`

- Importar y detectar errores: `<godot> --headless --path . --import`
  (`--check-only` sobre un script da falsos errores porque no carga los autoloads).
- **Test del loop de cordura**: `<godot> --path . -s res://tests/sanity_loop_test.gd` → imprime
  OK/FAIL y guarda capturas en `%APPDATA%\Godot\app_userdata\Lovacrafstory\test_shots\`. Mirar las capturas.
- **Test del hospital**: `<godot> --path . -s res://tests/hospital_tour_test.gd` (carga, escalera,
  navmesh entre pisos, límites, una captura por ambiente en `test_shots\hospital\`).
- **Test del refugio**: `<godot> --path . -s res://tests/shelter_test.gd` (materiales, bono, plano,
  estaciones, persistencia; capturas en `test_shots\shelter\`).
- **Test de la calle**: `<godot> --path . -s res://tests/street_tour_test.gd` (forzar la salida con la
  barreta, spawn, navmesh, barricada, límites, secreto, vuelta al hospital; `test_shots\street\`).
- **Test del menú de inicio**: `<godot> --path . -s res://tests/main_menu_test.gd` (foco, volumen
  guardado, Jugar → casa, Continuar con partida guardada).
- **Test del guardado**: `<godot> --path . -s res://tests/save_test.gd` (pausa, opciones, guardar,
  cargar y comparar todo, guardado automático al cambiar de zona, volver al menú).
- Regenerar el hospital / la calle / las casas: `<godot> --headless --path . -s res://tools/build_hospital.gd`
  (o `build_street.gd`, `build_houses.gd`, `build_theater.gd`, `build_home.gd`, `build_park.gd`,
  `build_avenue_places.gd`). **Antes de regenerar, mirar `git status`**: si el usuario editó la escena en el
  editor, pasar sus cambios al generador primero (pasó con la tele de la casa).
- **Test del comienzo**: `<godot> --path . -s res://tests/home_test.gd` (casa, ático, rejas, socavón, la vuelta por Rondeau, rampa y puerta
  de guardia, el sobreviviente nuevo llega a casa). Los tests del refugio del hospital hacen `move_to(&"hospital")`.
- **Test de la comisaría y la iglesia**: `<godot> --path . -s res://tests/avenue_places_test.gd` (entrada y
  salida, secretos por dificultad, bajar a la cripta).
- **Test del teatro**: `<godot> --path . -s res://tests/theater_test.gd` (llave, escopeta, jefe, camarín,
  mudarse, el sobreviviente nuevo llega al teatro).
- Una `class_name` nueva no existe para los tests hasta correr `--import` (refresca la caché de clases).
- No usar `@export_multiline` en listas (`PackedStringArray`): el editor de Godot 4.7 no lo conserva y borra
  los valores al guardar la escena (pasó con los textos de los `Inspectable`).
- **Al empaquetar un nivel, Godot guarda todas las propiedades de cada escena instanciada** (enemigos,
  pickups) tal como estaban: si se cambia `stalker.tscn`, `boss.tscn`, `attic_boss.tscn`, etc., hay que
  **regenerar los niveles** que las usan (si no, siguen con los valores viejos).
- Muebles de Poly Haven: `powershell -File tools/fetch_polyhaven.ps1 -Ids <id>,...` y revisar escala y
  frente con `<godot> --path . -s res://tools/preview_props.gd -- res://assets/models/props/polyhaven/ salida.png 4 id1,id2`.
  Correcciones por modelo en `upgrades` / `ph_fixes` del generador.
- Copiar archivos de rutas con corchetes (`[Standard]`) en PowerShell: usar `-LiteralPath`.
- Los tests borran los bindings de input al arrancar (`InputMap.action_erase_events`): hay un gamepad
  XInput conectado y cualquier toque movía la cámara.
- Un hook de seguridad bloquea comandos de PowerShell con ciertos patrones (`.Replace(...)` con
  comillas, `Remove-Item`): para editar archivos usar la herramienta Edit.
- Los parámetros globales tipo `color` llegan al shader en sRGB: convertir a lineal antes de usarlos.
- PowerShell 5 escribe UTF-8 **con BOM** (`Set-Content -Encoding utf8`): para archivos de Godot usar
  la herramienta Write o `[IO.File]::WriteAllText` con `UTF8Encoding($false)`.
- La ventana de los tests toma el foco: si el usuario usa teclado o mouse mientras corren, puede
  haber fallas aleatorias (sobre todo en los menús). Volver a correr antes de sospechar del código.
- El test no puede usar `class_name` del juego (compila antes que los autoloads). Ignora la entrada
  real (`isolate_input`) y congela enemigos con `set_physics_process(false)`: `PROCESS_MODE_DISABLED`
  los saca del mundo físico y las balas los atraviesan.
- **Git**: repo https://github.com/Gallopabman/Lovecrafstory (rama `main`), binarios en Git LFS
  (ver `.gitattributes`). Identidad local: `Gallopabman <Gallopabman@users.noreply.github.com>`.
  El PATH de la sesión puede no tener git: refrescarlo con
  `$env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")`.
  Mensajes de commit: escribirlos a un archivo y usar `git commit -F` (los here-strings de PowerShell fallan).

## Estado / roadmap

**Prototipo 1** — hecho: controlador 3ª persona, shader PS1 + niebla, sala de prueba.

**Prototipo 2** — hecho: loop de cordura en [scenes/levels/test_room.tscn](scenes/levels/test_room.tscn).
- [x] Cordura con goteo, refugio (x0.25), golpes, horror nuevo visto, estados del GDD
- [x] Inventario + menú (sin HUD), comida / cómic / VHS (requiere electricidad) / carta
- [x] Niebla, oscuridad, jitter y post-proceso según la locura
- [x] Secretos por cordura (símbolo en Inquieto, pared que desaparece en Quebrado)
- [x] Muerte a 0 → "te perdiste" → nuevo sobreviviente en el refugio (sin Perdido todavía)
- [x] Modelo del superviviente (Quaternius, CC0) con idle/caminar/correr/golpe/interactuar/muerte

**Prototipo 2.5** — hecho: mochila en cuadrícula, muerte en el refugio con cuerpo recuperable,
mundo persistente entre sobrevivientes (en memoria), acechador (Quaternius, CC0), silueta como
alucinación desde Inquieto.

**Prototipo 2.6** — hecho: combate con pistola (Quaternius, CC0) y barreta (CreativeTrio, CC0),
munición apilable, arma equipada, dos acechadores en la sala.

**Zona 1** — hecho: Hospital San Judas (ver arriba), tres acechadores, alucinación en el quirófano.

**Mejora gráfica** — hecha: 640x480, texturas 128, 38 muebles de Poly Haven, arquitectura (marcos,
pasamanos, carteles, mostradores, luminarias) y Thin Zombie. El superviviente volvió a ser el Adventurer
(el realista era "muy medieval"). Quedan low-poly: inodoros, lavatorios, heladera y lámpara de pie de
Kenney; lockers, archiveros, expendedora (Poly Pizza).

**Sonido, Perdido, zona 2, inventario, menú de inicio** — hecho: 66 sonidos (ver CREDITS), el Perdido
con estilos, la avenida, inventario rediseñado con íconos, menú de inicio con volumen.

**Prototipo 3** — hecho: refugio con blueprint (5 espacios x 2 niveles), materiales, nivel cozy,
estaciones (cocinar, descansar, radio, TV con electricidad) y bono de llegar a casa. A afinar con el
usuario: costos, cantidades de materiales, valores de cozy/goteo y de las estaciones. Pendiente del GDD:
mudarse a otro refugio (edificios con más slots), baúl para guardar cosas, mesa de trabajo / biblioteca.

Pendiente / preguntas abiertas:
- ¿Los horrores reaparecen en zonas limpias? (pregunta abierta del GDD; hoy no).
- El usuario escuchó los sonidos: todos bien salvo "uno de disparos" (no sabía cuál). Se sacó el
  22 Magnum recortado (`gunshot_2`); queda `gunshot.wav` (Michel Baradari). Si era el otro, cambiarlo.
- ¿Guardar en cualquier lado o solo en el refugio? Hoy: en cualquier lado desde la pausa (a confirmar).
- Alucinaciones inofensivas "de verdad", cámaras fijas en interiores. ¿Qué hay después del teatro?
