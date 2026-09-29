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
- **Refugio**: blueprints de slots fijos (fuego, electricidad, cama, decoración, ventanas,
  estaciones). Un solo refugio activo; mudarse es una decisión. Bono de llegada según logros de la salida.
- **Mundo interconectado** ("lineal abierto", atajos estilo RE2/Dark Souls). Primer tramo:
  refugio → edificio → calle → teatro. Cada zona tiene un secreto visible solo con poca cordura.
- **Cámaras**: fijas en interiores, libre en exteriores (pendiente).
- **Sin HUD**: la cordura solo se ve en el menú de estado/inventario (Tab).

## Decisiones técnicas

- Godot **4.7**, renderer **Forward+**. Sin C#: todo en GDScript.
- Resolución interna **320x240** (`stretch/mode="viewport"`, escala entera, 4:3). Ventana 1280x960.
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
  - `GameState` ([scripts/autoload/game_state.gd](scripts/autoload/game_state.gd)): persiste entre
    sobrevivientes (pickups recogidos por ruta de nodo, objetos tirados, cuerpos, `lost_ones` para el
    Perdido, número de sobreviviente) y `post_message()` para avisos. Todavía no guarda a disco.
- **Objetos**: `ItemData` ([scripts/items/item_data.gd](scripts/items/item_data.gd)), un `.tres` por
  objeto en `assets/items/` (`grid_size`, `short_name` de 3 letras para la cuadrícula).
  En el mundo: [scenes/world/pickup.tscn](scenes/world/pickup.tscn).
- **Componentes de mundo** (`scripts/world/`): `GreyBox` (blockout con malla subdividida),
  `RefugeZone` (Area3D: goteo reducido + electricidad), `SanityGated` (muestra/oculta hijos
  y su colisión según el estado), `HorrorSighting` (baja cordura la primera vez que se ve),
  `WorldPersistence` (reconstruye objetos tirados y cuerpos al cargar), `Corpse`,
  `RuntimeNavBake` (hornea el navmesh al cargar desde el grupo `nav_source`).
- **Enemigos** (`scripts/enemies/`): `Stalker` — deambula, persigue si ve u oye correr, golpea la
  cordura; se escapa corriendo (no hay combate: pregunta abierta del GDD). Usa NavigationAgent3D.
- **Capas de colisión**: 1 escenario + jugador, 2 enemigos, 3 interactuables.
- **Interacción**: el jugador busca Areas del grupo `interactable` (capa 3) y llama `interact(player)`.
- **UI** ([scenes/ui/game_ui.tscn](scenes/ui/game_ui.tscn), CanvasLayer 50): menú (pausa el juego;
  entrada propia en `_input`), cuadrícula `InventoryGrid`, lector de cartas, avisos breves, pantalla de
  muerte. Tema global [assets/ui/ps1_theme.tres](assets/ui/ps1_theme.tres), Pixel Operator 8px.
- **Input**: `move_*`, `look_*` (stick der.), `run`, `interact` (E), `flashlight` (F), `menu`
  (Tab / I / Back), `pause` (Esc), `inventory_move` (R), `inventory_rotate` (Q), `inventory_drop` (X).
  Debug: F3 overlay, F9 golpe, F10 −25 %, F11 +25 %.
- Assets de terceros: registrar siempre en [CREDITS.md](CREDITS.md) (preferir CC0).

## Estructura

```
assets/      modelos, texturas, materiales, items (.tres), fuentes, ui
scenes/      .tscn por dominio (player, levels, world, enemies, effects, ui)
scripts/     .gd por dominio (player, world, items, ui, autoload)
shaders/     .gdshader
tests/       scripts de test (extends SceneTree)
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
- Los parámetros globales tipo `color` llegan al shader en sRGB: convertir a lineal antes de usarlos.
- PowerShell 5 escribe UTF-8 **con BOM** (`Set-Content -Encoding utf8`): para archivos de Godot usar
  la herramienta Write o `[IO.File]::WriteAllText` con `UTF8Encoding($false)`.
- El test no puede usar `class_name` del juego (compila antes que los autoloads) y el mouse sobre la
  ventana lo altera.
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

Pendiente / preguntas abiertas:
- ¿Combate o solo esconderse y huir? (GDD). Hoy el acechador solo se esquiva corriendo.
- El Perdido (ya se registran posición e inventario en `GameState.lost_ones`), alucinaciones
  inofensivas "de verdad", cámaras fijas en interiores, bono de llegar a casa, guardado a disco.
- Íconos de objetos para la cuadrícula (hoy: color + abreviatura).
- **Prototipo 3** (GDD): refugio con un slot de mejora y el bono de llegar a casa.
