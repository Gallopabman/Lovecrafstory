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
  refugio → edificio → calle → teatro. Cada zona tiene un secreto visible solo con poca cordura.
- **Cámaras**: fijas en interiores, libre en exteriores (pendiente).
- **Sin HUD**: la cordura solo se ve en el menú de estado/inventario (Tab).

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
  - `Sanity` ([scripts/autoload/sanity_manager.gd](scripts/autoload/sanity_manager.gd)): cordura,
    estados, goteo, refugios, golpes (`take_hit`), horrores vistos (`register_sighting`), señal `lost`
    + `lost_in_refuge`.
  - `Inventory` ([scripts/autoload/inventory.gd](scripts/autoload/inventory.gd)): cuadrícula
    `grid_size`, entradas `{item, cell, rotated}`, `letters` aparte; `add()` devuelve false si no
    entra; `use(item, entry)`, `move`, `drop` (emite `item_dropped`).
  - `Shelter` ([scripts/autoload/shelter.gd](scripts/autoload/shelter.gd)): el refugio como hogar.
    Blueprint `SLOTS` (fuego, electricidad, cama, ventanas, decoración; 2 niveles cada uno, costo en
    materiales, +1 cozy por nivel), `stock` de materiales, `cozy()` → `drain_multiplier()` (x0.6 pelado
    → x0.1 completo), `has_electricity()` (generador), estaciones `cook()` / `rest()` / `play_radio()`,
    `discover(place)` y el bono de llegar a casa (lugares nuevos + objetos + cartas de la salida, tope
    30). Los materiales se descargan solos de la mochila al entrar. Persiste entre sobrevivientes.
  - `GameState` ([scripts/autoload/game_state.gd](scripts/autoload/game_state.gd)): persiste entre
    sobrevivientes (pickups recogidos por ruta de nodo, objetos tirados, cuerpos y `lost_ones`, los tres
    **por escena**; enemigos muertos, `flags` del mundo, número de sobreviviente) y `post_message()`.
    `playstyle` junta estadísticas del sobreviviente actual (`track(&"shots")`, `melee`, `run_time`,
    `crouch_time`) para el Perdido. Viajes: `travel(escena, spawn)` + `next_spawn`; `new_survivor()`
    carga `refuge_scene` (el hospital; los tests la cambian); `new_game()` reinicia todo. No guarda a disco.
  - `Audio` ([scripts/autoload/audio.gd](scripts/autoload/audio.gd)): busca sonidos **por nombre** en
    `assets/audio/{sfx,ambience,music}/` (`step` = `step.ogg` o variantes `step_1`, `step_2`... al azar;
    si no existe, no suena y no falla). `play_sfx(nombre, posición 3D opcional)`, `play_ui`,
    `set_ambience`, `play_music`, latido automático desde Quebrado, susto al ver un horror nuevo.
    Buses Master / Music / SFX / Ambience (se crean en runtime). Volumen general en `user://settings.cfg`.
- **Objetos**: `ItemData` ([scripts/items/item_data.gd](scripts/items/item_data.gd)), un `.tres` por
  objeto en `assets/items/` (`grid_size`, `short_name` de 3 letras para la cuadrícula).
  En el mundo: [scenes/world/pickup.tscn](scenes/world/pickup.tscn).
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
- **Combate** ([scripts/player/player_combat.gd](scripts/player/player_combat.gd), nodo `Combat` hijo
  del jugador; su `setup()` lo llama Player): apuntar/disparar/recargar, cuerpo a cuerpo, arma en la
  mano vía BoneAttachment3D en `hand_r`. Las escenas `scenes/weapons/*_held.tscn` están en metros en
  el espacio del hueso (si el esqueleto viene escalado se compensa al equipar).
  Armas = `ItemData` kind WEAPON (grupo "Arma": `is_ranged`, `damage`, `magazine_size`, `ammo_item`,
  `noise_radius`, `held_scene`); munición = kind AMMO con `max_stack`.
- **Capas de colisión**: 1 escenario + jugador, 2 enemigos, 3 interactuables.
- **Interacción**: el jugador busca Areas del grupo `interactable` (capa 3) y llama `interact(player)`.
- **UI** ([scenes/ui/game_ui.tscn](scenes/ui/game_ui.tscn), CanvasLayer 50): menú de inventario (pausa
  el juego; entrada propia en `_input`): barras de encabezado y pie, paneles Mochila / Cartas / Cordura
  (estado con color y una frase) / Detalle (vista previa grande del objeto), ayudas de teclas con color.
  La cuadrícula `InventoryGrid` dibuja celdas con bisel, cursor que late e **íconos** hechos con
  primitivas (`ItemIcon.draw_icon`, [scripts/ui/item_icon.gd](scripts/ui/item_icon.gd): lata, botella,
  cómic, VHS, carta, pistola, barreta, balas, materiales). Lector de cartas en papel, avisos, muerte.
  Tema global [assets/ui/ps1_theme.tres](assets/ui/ps1_theme.tres), Pixel Operator 8px (botones y sliders
  incluidos).
- **Menú de inicio** ([scenes/ui/main_menu.tscn](scenes/ui/main_menu.tscn), **escena principal**): niebla
  animada ([shaders/menu_fog.gdshader](shaders/menu_fog.gdshader)), Jugar (partida nueva → hospital),
  Opciones (solo volumen general, pedido del usuario) y Salir. Música `menu_music`.
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

## Zona 1: Hospital San Judas

[scenes/levels/hospital.tscn](scenes/levels/hospital.tscn) es la primera zona y el refugio (la sala de
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
- **Refugio** (sala del personal, PB NE): arranca pelado (colchón en el piso, generador roto, una
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
  guardado, Jugar → hospital).
- Regenerar el hospital / la calle: `<godot> --headless --path . -s res://tools/build_hospital.gd`
  (o `build_street.gd`).
- Una `class_name` nueva no existe para los tests hasta correr `--import` (refresca la caché de clases).
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
- Nadie escuchó los sonidos todavía (se eligieron por descripción): revisar cuáles quedan bien,
  sobre todo los del zombie (gruñido / ataque se asignaron a ojo) y que los loops no corten.
- Teatro Imperio (zona 3), alucinaciones inofensivas "de verdad", cámaras fijas en interiores,
  guardado a disco, volver al menú de inicio desde el juego (hoy Esc solo suelta el mouse).
