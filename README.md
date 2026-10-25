# Fort Control

Un Tower Defense 3D de fantasía medieval, hecho con **Godot 4.6.3 estándar y GDScript**. Construye ballestas en las casillas `+`, mejora tus defensas y protege la fortaleza durante cinco oleadas de esqueletos. El juego funciona sin internet, cuentas ni servicios externos.

## Qué incluye

- Un tablero de 8 × 14 casillas, camino fijo, castillo de piedra con techos azules y ocho posiciones de construcción.
- Ballestas que priorizan al enemigo más avanzado dentro de su alcance, con proyectiles visibles y tres niveles de mejora.
- Esqueletos con vida, movimiento por puntos del camino, recompensa por eliminación y daño al llegar al castillo.
- 300 monedas y 20 puntos de vida iniciales; cinco oleadas de dificultad creciente.
- Cámara isométrica ortográfica, selección, arrastre y zoom con mouse o pantalla táctil.
- Interfaz en español, pausa, victoria, derrota y reinicio.
- Recursos de balance editables y pruebas automatizadas sin ventana.

Todos los modelos provisionales se crean con geometría nativa de Godot. No necesitas Blender, Meshy, plugins ni descargar paquetes de arte para jugar.

<img src="docs/images/fort-control.png" alt="Fort Control: ballestas defendiendo el camino al castillo y panel de mejoras" width="360">

Captura real del MVP con el renderizador Mobile en Linux. No representa una prueba en hardware móvil.

## Jugar en una Mac con Apple Silicon

1. Descarga **Godot 4.6.3 Standard para macOS, Universal** desde el [archivo oficial de versiones](https://godotengine.org/download/archive/4.6.3-stable/). No necesitas la edición .NET.
2. Descomprime la descarga y arrastra **Godot.app** a **Aplicaciones**. Ábrela desde Finder. Si macOS pide confirmar la apertura, usa la opción que ofrece el sistema para esa aplicación; no desactives las comprobaciones de seguridad globales.
3. Abre **Terminal**. Si todavía no tienes Git, ejecuta `xcode-select --install` y termina la instalación de las herramientas de Apple.
4. Clona el proyecto y entra en su carpeta:

   ```bash
   git clone https://github.com/Dabot11/Fort_Control.git
   cd Fort_Control
   ```

5. En el administrador de proyectos de Godot, pulsa **Importar**, selecciona el archivo `project.godot` de esa carpeta y confirma **Importar y editar**.
6. Espera la primera importación. Pulsa **F5** o el botón triangular **Ejecutar proyecto**. Si el teclado usa F5 para otra función, pulsa **Fn + F5**.
7. Selecciona una casilla `+`, pulsa **Construir** y coloca tus primeras ballestas. Pulsa **Iniciar oleada** cuando estés preparado. Selecciona una torre para consultar sus estadísticas y mejorarla.

La escena principal es `scenes/main/main.tscn`. Para ejecutar únicamente esa escena abierta en el editor puedes usar **F6**; para una partida normal usa **F5**.

También puedes abrir o ejecutar el proyecto desde Terminal:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . --editor
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

El proyecto usa el renderizador **Mobile**. Si tu equipo presenta un problema de controlador gráfico, prueba **Compatibility** sin modificar la configuración del repositorio:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . --rendering-method gl_compatibility
```

## Controles y reglas

| Acción | Mouse y teclado | Pantalla táctil |
| --- | --- | --- |
| Seleccionar casilla o torre | Clic corto | Toque corto |
| Mover cámara | Arrastrar con botón izquierdo | Arrastrar con un dedo |
| Acercar o alejar | Rueda del mouse | Pellizcar con dos dedos |
| Construir o mejorar | Botón del panel contextual | Botón del panel contextual |
| Iniciar siguiente oleada | Botón, Espacio o Enter | Botón inferior |
| Pausar o continuar | Botón, Escape o P | Botón de pausa |
| Reiniciar | Botón del menú | Botón del menú |

Arrastrar la cámara no construye una torre: la construcción siempre requiere confirmar en el panel. La siguiente oleada se habilita cuando termina la anterior. Puedes construir y mejorar durante una oleada si tienes oro. Las casillas del camino no permiten construir.

Cada esqueleto eliminado entrega 25 monedas una sola vez. Cada esqueleto que llega al final del camino resta una vida y no entrega monedas. Ganas al resolver los enemigos de las cinco oleadas con vida restante; pierdes cuando la vida llega a cero. Reiniciar comienza una partida limpia.

## Modificar el balance

Los parámetros están en archivos JSON de texto. Puedes editarlos desde Godot o cualquier editor. Después **detén la ejecución con F8 y vuelve a ejecutar con F5** para cargar los archivos modificados; el botón Reiniciar conserva los datos cargados al abrir el juego. Conserva comas, comillas y corchetes válidos; usa punto decimal, por ejemplo `1.25`.

| Archivo | Contenido |
| --- | --- |
| [`resources/balance/default.json`](resources/balance/default.json) | Oro inicial, vida del castillo, recompensas, daño al castillo, velocidad de proyectiles y estadísticas por nivel de torre |
| [`resources/waves/default.json`](resources/waves/default.json) | Cantidad, vida, velocidad e intervalo de aparición de cada oleada |
| [`resources/maps/meadow.json`](resources/maps/meadow.json) | Dimensiones, tamaño de casilla, camino, posiciones de construcción y castillo |

La referencia completa de campos y valores iniciales está en [`docs/balance.md`](docs/balance.md). No necesitas cambiar scripts para ajustar esos valores.

## Sustituir el esqueleto por un GLB de Meshy

La lógica de movimiento y combate vive en `scripts/combat/enemy.gd`; la representación provisional está separada en `scripts/combat/enemy_visual.gd`.

1. Exporta el modelo como `.glb`, comprueba su licencia y coloca el archivo en `assets/characters/`. No incluyas claves de Meshy ni archivos privados de tu cuenta.
2. Deja que Godot lo importe. Abre el modelo para revisar escala, materiales y animaciones. Ajusta la escala de su nodo visual, sin cambiar las coordenadas del enemigo ni las casillas del mapa.
3. Crea una escena visual propia que instancie el GLB. El enemigo mira hacia el eje local `-Z` y sus pies deben quedar cerca del origen.
4. Adapta el nodo `Visual` creado por `enemy.gd`, conservando los métodos `animate_walk(delta, speed)` y `set_health_ratio(ratio)` que usa la lógica. Puedes implementarlos en un script envoltorio para el modelo importado, sin modificar los archivos generados por el importador.
5. Si el GLB tiene `AnimationPlayer`, asigna sus clips a **Idle**, **Walk**, **Attack** y **Death**. Verifica los nombres reales: no todos los modelos exportan esas pistas ni usan los mismos nombres.
6. Repite las pruebas y juega una oleada para confirmar orientación, escala, animación y legibilidad desde la cámara.

En este MVP el esqueleto camina y desaparece al morir o llegar al castillo. **Attack** no se utiliza porque no hay combate cuerpo a cuerpo. Para reproducir **Death** completo, conserva inmediatamente el estado lógico de enemigo muerto y reproduce una copia visual sin colisiones antes de retirarla; la animación nunca debe volver a entregar oro ni retrasar el estado lógico de la oleada.

## Ejecutar las pruebas

Desde la raíz del repositorio en macOS:

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot bash scripts/run_tests.sh
```

En Linux o si `godot` ya está en tu `PATH`:

```bash
bash scripts/run_tests.sh
```

El script importa el proyecto y ejecuta la suite sin ventana. Un error de importación o una prueba fallida produce un código de salida distinto de cero. Los resultados de una ejecución concreta y la cobertura manual pendiente se registran en [`docs/validation.md`](docs/validation.md).

Para ejecutar también las simulaciones completas de balance —primera oleada con una ballesta y victoria mediante compras y mejoras—:

```bash
bash scripts/run_tests.sh --gameplay
```

En macOS puedes anteponer `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot` al mismo comando.

Para comprobar solo la importación:

```bash
godot --headless --path . --editor --import --quit
```

Si usas el ejecutable de macOS sin alias, sustituye `godot` por `/Applications/Godot.app/Contents/MacOS/Godot`. La primera importación genera `.godot/`; esa caché no se versiona. Las pruebas headless verifican la lógica y la carga de escenas, pero no prueban el rendimiento gráfico ni los gestos en hardware móvil.

## Primeras pruebas en iPhone o iPad

Necesitas una Mac, **Xcode**, un dispositivo físico y la configuración de firma de tu propia cuenta de Apple. La preparación detallada está en [`docs/mobile-export.md`](docs/mobile-export.md).

1. Abre Xcode, acepta sus condiciones e instala los componentes que solicite. Añade tu cuenta en sus ajustes y conecta el iPhone por cable.
2. En Godot, abre **Editor → Administrar plantillas de exportación** e instala las plantillas que coincidan exactamente con **4.6.3**.
3. En **Proyecto → Exportar**, selecciona el preset **iOS** incluido. Configura tu **Team ID** y un **Bundle Identifier** propio, selecciona iPhone/iPad y conserva la orientación vertical. En **Resources**, conserva `*.json` en el filtro de archivos que no son recursos para empaquetar mapa, balance y oleadas.
4. Exporta el proyecto Xcode a una carpeta local ignorada, por ejemplo `build/ios/`. Si la salida es `.zip`, descomprímela.
5. Abre el proyecto exportado en Xcode, selecciona tu equipo de firma y tu dispositivo. Activa **Developer Mode** en el iPhone si el sistema lo solicita y ejecuta **Run**.
6. Revisa notch, zona segura inferior, selección, arrastre, pellizco, pausa y una partida completa. Usa la lista de [`docs/validation.md`](docs/validation.md).

No se incluyen certificados, perfiles ni identificadores de firma. La cuenta de Apple y sus restricciones determinan las posibilidades de instalación o distribución. La exportación y el funcionamiento en dispositivos físicos deben comprobarse en ese hardware.

## Preparar Android

Instala **OpenJDK 17**, Android Studio y los componentes del SDK indicados en [`docs/mobile-export.md`](docs/mobile-export.md). Configura las rutas de Java y Android en los ajustes del editor de Godot, instala las plantillas **4.6.3**, completa el identificador de aplicación del preset **Android** incluido, conserva `*.json` en el filtro de archivos de **Resources** y exporta un APK de depuración a `build/android/` para la primera prueba en un teléfono con depuración USB.

No necesitas permisos de internet para el juego. No guardes contraseñas de firma ni keystores dentro del repositorio. Una publicación en Google Play requiere preparar y firmar su propio AAB; no forma parte de esta entrega.

## Organización

| Carpeta o archivo | Responsabilidad |
| --- | --- |
| `project.godot` | Motor, escena inicial, ventana vertical y renderizador |
| `export_presets.cfg` | Preparación para macOS, Android, iOS y validación del paquete de recursos |
| `scenes/main/main.tscn` | Punto de entrada del juego |
| `scripts/core/` | Coordinación de la partida y estado general |
| `scripts/systems/` | Economía, vida y oleadas |
| `scripts/world/` | Tablero, casillas y escenario |
| `scripts/combat/` | Enemigos, torres, proyectiles y modelos provisionales |
| `scripts/camera/` | Cámara ortográfica y gestos |
| `scripts/ui/` | HUD, selección y menús |
| `resources/` | Configuración del mapa y balance |
| `tests/` | Verificaciones automatizadas |
| `docs/` | Balance, arquitectura, exportación y validación |

Consulta [`docs/architecture.md`](docs/architecture.md) para entender cómo se conectan los sistemas y [`AGENTS.md`](AGENTS.md) para las convenciones de futuras tareas.

## Limitaciones y próximos pasos

- Un mapa, un tipo de torre y un tipo de enemigo. No hay guardado, audio, backend, anuncios ni compras.
- El arte es provisional y se genera con nodos nativos; los efectos y animaciones son sencillos.
- El balance inicial requiere sesiones de juego con personas para ajustar dificultad y ritmo.
- La orientación móvil es vertical. La interfaz se adapta a otras proporciones de ventana, pero su experiencia principal es portrait.
- El soporte de gestos está implementado; compatibilidad, zonas seguras, consumo y rendimiento en iPhone, iPad y Android físicos necesitan validación posterior.

La siguiente tarea recomendada es **probar una partida completa en un iPhone y un Android de gama media**, medir tiempos de fotograma y ajustar legibilidad, controles y balance con esos resultados. Después se pueden sustituir los modelos provisionales manteniendo la lógica actual.
