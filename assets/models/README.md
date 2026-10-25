# Modelos de Fort Control

Esta carpeta contiene las versiones de juego de los cuatro modelos facilitados por el propietario del proyecto. Los nombres de los archivos originales identifican su procedencia como exportaciones de Meshy. Las texturas están integradas en los GLB y no se necesita acceso a Drive, Meshy ni otro servicio para ejecutar o exportar el juego.

Godot importa estos archivos al abrir el proyecto. También se incluyen las texturas que el importador extrae junto al GLB y sus ajustes `.import`. No necesitas Blender para jugar. La caché `.godot/` y los originales de trabajo no se incluyen en esta carpeta.

## Recursos incluidos

Las cifras corresponden al contenido de los GLB preparados, antes de la importación de Godot. Los tamaños son bytes de archivo, no consumo de memoria gráfica ni mediciones de rendimiento.

| Modelo | Archivo de juego | Triángulos originales → juego | Bytes originales → juego | Texturas de juego |
| --- | --- | --- | --- | --- |
| Ballesta | `tower/crossbow.glb` | 1.236.810 → 16.312 | 43.954.308 → 1.662.968 | 3 JPEG de 1024 × 1024 |
| Esqueleto | `skeleton/warrior.glb` | 1.915 → 1.915 | 7.588.248 → 1.568.088 | 3 JPEG de 1024 × 1024 |
| Espada | `sword/shardblade.glb` | 412 → 412 | 5.491.600 → 148.036 | 3 JPEG de 512 × 512 |
| Flecha | `arrow/crystal_arrow.glb` | 524 → 524 | 5.452.436 → 279.384 | 3 PNG de 256 × 256 |

Los cuatro archivos pasan de 62.486.592 a 3.658.476 bytes en conjunto. La torre concentra la reducción de geometría; el esqueleto, la espada y la flecha conservan su geometría original. Todas las texturas originales eran de 2048 × 2048.

Los archivos originales recibidos son:

- `Meshy_AI_Fortress_Crossbow_1025175016_texture.glb`
- `Meshy_AI_Glowing_Skull_Warrior_All_Animations.glb`
- `Meshy_AI_Shardblade_1025041943_texture.glb`
- `Meshy_AI_Crystal_Arrow_1025174840_texture.glb`

## Adaptación al juego

### Ballesta

La preparación separa la torre monolítica en una base fija `TowerBase` y un arma bajo `AimHead`, con su boca de disparo `Muzzle`. Simplifica la geometría antes de importarla y conserva la textura del modelo.

`scripts/combat/tower_visual.gd` orienta el arma hacia el objetivo y aplica su retroceso. La base permanece fija. La mejora conserva la dirección del arma y distingue los niveles mediante la altura del pedestal, remates y marcas: azul en nivel 2 y dorado en nivel 3.

### Esqueleto y espada

La preparación conserva los datos de geometría, skin y animaciones del esqueleto. El GLB incluye `Running`, `Walking` y `Right_Hand_Sword_Slash`; el juego utiliza `Walking`, cuyo ritmo sigue la velocidad del enemigo. Los otros clips quedan disponibles en el recurso sin añadir reglas de ataque cuerpo a cuerpo.

`scripts/combat/enemy_visual.gd` gira el modelo original hacia `-Z` y lo escala de 1,7 a 1,15 unidades de altura. La animación de caminar ya es un ciclo en el sitio: conserva su oscilación de cadera, pero no traslada al nodo lógico del enemigo. Su avance pertenece a `FortEnemy`, que sigue los puntos del camino. La pausa detiene el avance de la pose.

La espada se une a la mano derecha mediante `BoneAttachment3D`. El envoltorio de reacción al golpe y la barra de vida están separados, de modo que el golpe no deforma la barra. La muerte lógica sigue resolviéndose inmediatamente, con un único premio y el efecto de eliminación existente; no se añade una animación de muerte al recurso.

### Flecha

`scripts/combat/projectile.gd` instancia la flecha con una longitud de 0,62 unidades y transforma su eje original `+Y` al eje de disparo `-Z`. La presentación no altera su seguimiento, velocidad, validación de objetivo ni impacto único.

## Reproducir la preparación

Los siguientes comandos son herramientas de trabajo para rehacer los GLB a partir de los originales. Los archivos listos para el juego ya están incluidos. Ejecuta desde la raíz del repositorio, con Godot y Blender en el `PATH`, y sustituye las rutas de origen por las de tus archivos.

Torre, preparada con Blender 4.3.2:

```bash
blender --background --threads 4 --python tools/assets/prepare_tower.py -- \
  --source "/ruta/Meshy_AI_Fortress_Crossbow_1025175016_texture.glb" \
  --output assets/models/tower/crossbow.glb
```

Esqueleto y espada, preparados con Godot 4.6.3:

```bash
godot --headless --script tools/assets/prepare_character.gd -- \
  "/ruta/Meshy_AI_Glowing_Skull_Warrior_All_Animations.glb" \
  "/ruta/Meshy_AI_Shardblade_1025041943_texture.glb" \
  assets/models
```

Flecha, preparada con Godot 4.6.3:

```bash
godot --headless --script tools/assets/prepare_arrow.gd -- \
  "/ruta/Meshy_AI_Crystal_Arrow_1025174840_texture.glb" \
  assets/models/arrow/crystal_arrow.glb
```

Las herramientas de personaje y flecha recomponen el GLB después de reducir sus texturas; conservan los datos de geometría. Las de personaje también conservan el skin y las pistas de animación. Si cambias los archivos de origen, vuelve a revisar los supuestos de orientación, escala, nodos y materiales de cada herramienta.

Después de regenerar recursos, deja que Godot los importe, ejecuta `bash scripts/run_tests.sh --gameplay` y revisa una partida desde la cámara real del juego. Para comprobarlos en iPhone, vuelve a exportar el proyecto iOS y ejecútalo desde Xcode en el dispositivo físico. Los resultados de la validación y sus límites se registran en [`docs/validation.md`](../../docs/validation.md).
