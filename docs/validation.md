# Validación

Motor de referencia: **Godot 4.6.3.stable.official.7d41c59c4**. Los comandos se ejecutan desde la raíz del proyecto.

## Verificación automatizada

```bash
bash scripts/run_tests.sh
```

En macOS, si Godot no está en `PATH`:

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot bash scripts/run_tests.sh
```

La suite debe cubrir importación, escena principal, movimiento, daño, recompensa única, construcción válida e inválida, falta de oro, mejoras hasta nivel 3, oleadas, victoria, derrota y reinicio. Usa siempre el resultado de la ejecución actual: la existencia del script no demuestra que haya pasado.

### Resultados registrados en Linux cloud

| Comprobación | Resultado |
| --- | --- |
| Importación y carga de la escena principal con Godot 4.6.3 headless | Correctas, sin errores de parsing o recursos faltantes |
| Suite principal `tests/test_runner.gd` | **11 grupos, 143 verificaciones, 0 fallos**; código de salida 0 |
| Gestos sintéticos e interfaz `tests/test_input.gd` | **36 verificaciones, 0 fallos**; código de salida 0 |
| Simulación `first_one` | Primera oleada superada con una ballesta; resultado `passed: true` |
| Simulación `strategy` | Victoria tras las cinco oleadas; resultado `passed: true` |
| Exportación `Validation PCK` mediante `--export-pack` | Correcta, código de salida 0; los tres JSON quedaron incluidos |
| Arranque del PCK desde una carpeta vacía fuera del checkout | Correcto con `--main-pack` y `--quit-after 120`, código de salida 0 y sin errores |

Son **179 verificaciones automatizadas** entre lógica y entrada, además de las dos simulaciones de partida y las comprobaciones de empaquetado. La suite principal se ejecutó dos veces con el mismo resultado. El script detecta también errores de motor en el log que pudieran coexistir con un código de salida 0. Los gestos sintéticos ejercitan eventos de Godot; no reemplazan la prueba del panel táctil de un teléfono.

La suite de entrada usa `Input.parse_input_event` y recorre la GUI real: selección por raycast, compra, mejora hasta nivel 3, falta de oro, arrastre y pellizco sin selección accidental, bloqueo de la cámara por la UI, pausa, continuación y reinicio. También verifica distribución a 390 × 844, 768 × 1024 y 1024 × 768, y objetivos táctiles de al menos 44 píxeles con ventana de 390 píxeles de ancho.

### Simulaciones de balance ejecutadas

Se ejecutó la simulación real del combate en Godot con los datos iniciales, sin otorgar recursos adicionales a la estrategia:

| Estrategia | Resultado observado |
| --- | --- |
| Una ballesta en la casilla de índice 5 durante la primera oleada | Superada con 20 vidas y 350 monedas |
| Tres ballestas iniciales en índices 2, 3 y 5, con compras y mejoras posteriores | Victoria tras cinco oleadas, con 17 vidas y 475 monedas |
| Defensas iniciales sin mejoras | Derrota en la cuarta oleada |

Los índices son posiciones dentro de `build_slots`, contando desde cero. Estas simulaciones confirman una estrategia ganadora y una primera oleada accesible; no sustituyen sesiones de juego con personas ni prueban todas las estrategias posibles.

Los dos escenarios ganadores están conservados en `tests/test_gameplay.gd` y pueden repetirse con:

```bash
bash scripts/run_tests.sh --gameplay
```

La estrategia completa termina con cuatro torres: comienza en las casillas 2, 3 y 5, mejora progresivamente y construye una torre adicional en la casilla 4. La derrota sin mejoras fue una comprobación adicional de balance durante el desarrollo.

### Renderizado de escritorio ejecutado

Se inició y capturó el juego con **X11/Xvfb y Mesa por software** en Linux, tanto con **Compatibility / OpenGL 4.5** como con **Mobile / Vulkan 1.4.305**. Se revisaron escenas iniciales y de combate y ventanas de **390 × 844**, **540 × 960**, **768 × 1024** y **1024 × 768**, sin errores de renderizador.

Esto demuestra carga y representación gráfica en ese entorno. El renderizado por software no mide rendimiento de teléfonos ni verifica la ejecución en macOS, iOS o Android. Las acciones manuales de la lista siguiente solo deben marcarse al ejercitarlas expresamente; las capturas no sustituyen esas interacciones.

Los presets de **macOS**, **iOS** y **Android** están preparados con filtros de datos, pero no se generaron aplicaciones firmadas ni se instalaron en esos sistemas durante esta validación. El PCK probado es una verificación independiente del empaquetado y no equivale a un APK ni a una aplicación iOS/macOS.

## Validación manual de escritorio

- [ ] Abrir `project.godot`, importar recursos y ejecutar la escena principal sin errores.
- [ ] Confirmar terreno, camino, ocho signos `+`, castillo y siluetas legibles.
- [ ] Construir tres ballestas con las 300 monedas iniciales; una cuarta compra debe quedar bloqueada.
- [ ] Seleccionar una torre, revisar sus estadísticas y mejorarla dos veces cuando haya oro; nivel 3 debe indicar máximo.
- [ ] Ver cabezales orientarse, proyectiles desplazarse y enemigos perder vida.
- [ ] Completar una oleada y confirmar que no se solapa con la siguiente.
- [ ] Completar las cinco oleadas con defensas; comprobar victoria cuando no queden enemigos.
- [ ] Jugar sin defensas hasta perder; confirmar que la simulación se detiene.
- [ ] Reiniciar desde pausa, derrota y victoria; comprobar 300 monedas, 20 vidas, ocho casillas vacías y cero enemigos.
- [ ] Arrastrar desde una casilla y soltar: no debe abrir una selección como si fuera un clic.
- [ ] Probar mínimos y máximos de zoom y límites de desplazamiento.
- [ ] Pausar mientras hay enemigos y proyectiles; sus posiciones deben permanecer estables hasta continuar.

## Pantallas y controles móviles

Estas comprobaciones permanecen pendientes hasta ejecutarlas en dispositivos físicos. Anota modelo, versión del sistema operativo, renderizador y resultado.

| Dispositivo / ventana | Qué revisar | Estado |
| --- | --- | --- |
| iPhone estrecho en vertical | Notch, botones, texto, casillas accesibles mediante pan | Pendiente |
| iPhone grande en vertical | Dynamic Island, zona segura inferior, pellizco | Pendiente |
| iPad 3:4 en vertical | Espaciado, proporción del mundo y tamaño táctil | Pendiente |
| Android de gama media | Cadencia estable, temperatura, multitouch y sistema de navegación | Pendiente |
| Tablet Android | Escalado, distribución del HUD y alcance de controles | Pendiente |
| Ventana de escritorio redimensionada | No deformar el mundo ni superponer botones | Pendiente |

- [ ] Un toque selecciona; un arrastre mueve la cámara sin seleccionar.
- [ ] Pellizcar acerca y aleja; levantar uno o ambos dedos no selecciona casillas accidentalmente.
- [ ] Tocar o arrastrar desde un botón no mueve la cámara.
- [ ] Un gesto que termina sobre la interfaz no deja la cámara arrastrando indefinidamente.
- [ ] Los botones siguen siendo alcanzables con recortes y barra inferior del sistema.
- [ ] Todas las posiciones de construcción pueden seleccionarse con los límites de cámara disponibles.
- [ ] Al enviar la aplicación a segundo plano y volver, comprobar si se requiere un ajuste adicional del flujo de pausa.

## Rendimiento

Medir en hardware físico una partida completa, especialmente la quinta oleada y el máximo de torres. Registrar FPS, tiempo de CPU/GPU, memoria y temperatura. El objetivo inicial es una interacción fluida; no se establece una cifra de rendimiento verificada antes de medirla.

Las pruebas headless no validan renderizado, firma iOS/Android, consumo, latencia táctil ni rendimiento móvil. Una captura de escritorio tampoco demuestra compatibilidad en teléfonos.
