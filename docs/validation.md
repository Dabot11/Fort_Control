# Validación

Motor de referencia cloud: **Godot 4.6.3.stable.official.7d41c59c4**. Los comandos se ejecutan desde la raíz del proyecto. La prueba física reportada utiliza otra versión del editor y se registra por separado.

## Prueba manual reportada del MVP base

| Dato | Reporte del usuario |
| --- | --- |
| Revisión | MVP base `82365e0` |
| Dispositivo | iPhone 16 Pro |
| Sistema | iOS 27.0.1 |
| Herramientas locales | Godot 4.7.2 y Xcode 27 |
| Resultado | Completó las cinco oleadas; no se registró un saldo final exacto de vida |
| Controles | Le resultaron cómodos y el juego funcionó en el teléfono |
| Dificultad percibida | Primeras cuatro oleadas fáciles; quinta más difícil para evitar perder vida |

Es evidencia de una partida manual **reportada por el usuario**, no una medición realizada por el agente. No se registraron FPS, tiempos de CPU/GPU, consumo, temperatura ni una matriz de dispositivos. El reporte motivó la revisión de la progresión de las oleadas 2–5.

## Nueva iteración: sonido, efectos y balance

La nueva iteración añade efectos de combate, sonidos, alcance visible, comparación de mejoras y balance revisado. **Debe volver a probarse en el iPhone**: el resultado del MVP base no valida automáticamente esos cambios.

Las verificaciones ejecutadas de esta revisión usan Godot 4.6.3 en Linux cloud:

| Comprobación | Resultado |
| --- | --- |
| Lógica principal `tests/test_runner.gd` | 143 verificaciones aprobadas |
| Entrada e interfaz `tests/test_input.gd` | 36 verificaciones aprobadas |
| Sonido, efectos, alcance y mejoras `tests/test_polish.gd` | 70 verificaciones aprobadas |
| `first_one` | Aprobada: primera oleada con 20 vidas, 350 monedas y una torre |
| `strategy` | Aprobada: 19–20 vidas observadas; última ejecución con 20 vidas, 550 monedas y cuatro torres |
| `strategy_perfect` | Aprobada: victoria sin fugas, 20 vidas, 550 monedas y cuatro torres |
| Exportación `Validation PCK` | Código de salida 0; incluidos los tres JSON y las cuatro clases de feedback |
| Arranque del PCK desde una carpeta vacía fuera del checkout | Código de salida 0, sin errores |

Son **249 verificaciones automatizadas**, además de **tres simulaciones con combate real** y comprobaciones de empaquetado. Las cifras del apartado histórico posterior pertenecen al MVP base, no se suman a este total.

El runner final terminó con código 0 y sin errores ni advertencias. La estrategia estándar obtuvo 19 vidas, 625 monedas y cinco torres en una ejecución anterior: la temporización de apariciones por frame en la simulación acelerada puede variar una fuga y las compras posteriores. Los ensayos comprueban resultados de juego, no un saldo idéntico en cada ejecución. El escenario `strategy_perfect` verifica explícitamente terminar sin perder vida.

La revisión de audio comprobó los nueve sonidos PCM generados y sus niveles, sin saturación de las muestras individuales. No fue una prueba de escucha en iPhone ni certifica el nivel sonoro de la mezcla en sus altavoces. Las pruebas de pulido también cubren límites de concurrencia, silencio, pausa, reinicio, daño variable al castillo y correspondencia entre comparaciones de mejora y datos reales.

Se revisaron capturas de esta versión con **Mobile/Vulkan a 720 × 1280** y **Compatibility a 390 × 844, 768 × 1024 y 1024 × 768**, mediante X11/Xvfb y renderizado por software en Linux. El panel de mejoras, los anillos de alcance y el menú de pausa con sonido permanecieron dentro de la ventana. No son mediciones de rendimiento de una GPU física ni una nueva prueba de iOS.

El [experimento de balance](balance-experiment.md) registra los parámetros elegidos y las estrategias comparadas. Una estrategia automatizada sin fugas no implica que el usuario haya terminado su partida anterior con 20 vidas.

## Verificación automatizada

```bash
bash scripts/run_tests.sh
```

En macOS, si Godot no está en `PATH`:

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot bash scripts/run_tests.sh
```

La suite debe cubrir importación, escena principal, movimiento, daño, recompensa única, construcción válida e inválida, falta de oro, mejoras hasta nivel 3, oleadas, victoria, derrota y reinicio. Usa siempre el resultado de la ejecución actual: la existencia del script no demuestra que haya pasado.

### Resultados históricos del MVP `82365e0` en Linux cloud

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

### Simulaciones históricas con el balance original

Se ejecutó la simulación real del combate en Godot con los datos iniciales, sin otorgar recursos adicionales a la estrategia:

| Estrategia | Resultado observado |
| --- | --- |
| Una ballesta en la casilla de índice 5 durante la primera oleada | Superada con 20 vidas y 350 monedas |
| Tres ballestas iniciales en índices 2, 3 y 5, con compras y mejoras posteriores | Victoria tras cinco oleadas, con 17 vidas y 475 monedas |
| Defensas iniciales sin mejoras | Derrota en la cuarta oleada |

Los índices son posiciones dentro de `build_slots`, contando desde cero. Estas simulaciones confirman una estrategia ganadora y una primera oleada accesible; no sustituyen sesiones de juego con personas ni prueban todas las estrategias posibles.

Los escenarios de prueba están en `tests/test_gameplay.gd` y se ejecutan con el balance del checkout actual. Por tanto, una nueva ejecución no tiene por qué reproducir los saldos históricos anteriores:

```bash
bash scripts/run_tests.sh --gameplay
```

La estrategia completa termina con cuatro torres: comienza en las casillas 2, 3 y 5, mejora progresivamente y construye una torre adicional en la casilla 4. La derrota sin mejoras fue una comprobación adicional de balance durante el desarrollo.

### Renderizado histórico del MVP base

Se inició y capturó el juego con **X11/Xvfb y Mesa por software** en Linux, tanto con **Compatibility / OpenGL 4.5** como con **Mobile / Vulkan 1.4.305**. Se revisaron escenas iniciales y de combate y ventanas de **390 × 844**, **540 × 960**, **768 × 1024** y **1024 × 768**, sin errores de renderizador.

Esto demuestra carga y representación gráfica en ese entorno. El renderizado por software no mide rendimiento de teléfonos ni verifica la ejecución en macOS, iOS o Android. Las acciones manuales de la lista siguiente solo deben marcarse al ejercitarlas expresamente; las capturas no sustituyen esas interacciones.

En la validación cloud original no se generaron aplicaciones firmadas ni se instalaron en macOS, iOS o Android. Posteriormente, el usuario completó la exportación local y la partida de iPhone descritas al inicio. El PCK probado es una verificación independiente del empaquetado y no equivale a un APK ni a una aplicación iOS/macOS.

## Lista para repetición manual de escritorio

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

Las comprobaciones detalladas de la nueva iteración permanecen pendientes hasta repetirlas en el dispositivo. La partida del MVP en iPhone 16 Pro ya está reportada; no se extrapola a otros teléfonos. Anota modelo, versión del sistema operativo, renderizador y resultado de cada repetición.

| Dispositivo / ventana | Qué revisar | Estado |
| --- | --- | --- |
| iPhone 16 Pro / iOS 27.0.1 | Cinco oleadas y controles del MVP base | Confirmado por el usuario; nueva iteración pendiente |
| iPhone estrecho en vertical | Notch, botones, texto, casillas accesibles mediante pan | Pendiente |
| iPhone grande en vertical | Dynamic Island, zona segura inferior, pellizco | Pendiente |
| iPad 3:4 en vertical | Espaciado, proporción del mundo y tamaño táctil | Pendiente |
| Android de gama media | Cadencia estable, temperatura, multitouch y sistema de navegación | Pendiente |
| Tablet Android | Escalado, distribución del HUD y alcance de controles | Pendiente |
| Ventana de escritorio redimensionada | No deformar el mundo ni superponer botones | Revisado en Linux por software; revisión manual en Mac pendiente |

- [ ] Un toque selecciona; un arrastre mueve la cámara sin seleccionar.
- [ ] Pellizcar acerca y aleja; levantar uno o ambos dedos no selecciona casillas accidentalmente.
- [ ] Tocar o arrastrar desde un botón no mueve la cámara.
- [ ] Un gesto que termina sobre la interfaz no deja la cámara arrastrando indefinidamente.
- [ ] Los botones siguen siendo alcanzables con recortes y barra inferior del sistema.
- [ ] Todas las posiciones de construcción pueden seleccionarse con los límites de cámara disponibles.
- [ ] Al enviar la aplicación a segundo plano y volver, comprobar si se requiere un ajuste adicional del flujo de pausa.

## Repetición física de la nueva iteración

- [ ] Jugar las cinco oleadas en el mismo iPhone 16 Pro y anotar en cuáles se pierde vida, cuándo se construye y cuándo se mejora.
- [ ] Comparar el ritmo de las oleadas 2, 3 y 4 con la quinta; reportar si sigue existiendo un salto brusco.
- [ ] Escuchar disparos, impactos, construcción, mejoras y señales de oleada/resultado sin saturación durante combate intenso.
- [ ] Activar y desactivar sonido desde pausa; comprobar que la preferencia se mantiene al reiniciar la partida.
- [ ] Comprobar que impactos, muerte y oro ganado se distinguen sin tapar el camino ni los enemigos.
- [ ] Seleccionar una torre: comprobar alcance actual en cian y siguiente alcance en dorado discontinuo; nivel 3 no debe ofrecer otra mejora.
- [ ] Contrastar la comparación de daño, alcance y ataques por segundo con la mejora realmente aplicada y el oro descontado.
- [ ] Recibir daño en el castillo y comprobar que el indicador de vida responde sin impedir tocar la interfaz.
- [ ] Comprobar pausa, reinicio y resultado con efectos activos; no deben quedar efectos de la partida anterior.

## Rendimiento

Medir en hardware físico una partida completa, especialmente la quinta oleada y el máximo de torres. Registrar FPS, tiempo de CPU/GPU, memoria y temperatura. El objetivo inicial es una interacción fluida; no se establece una cifra de rendimiento verificada antes de medirla.

Las pruebas headless no validan renderizado, firma iOS/Android, consumo, latencia táctil ni rendimiento móvil. Una captura de escritorio tampoco demuestra compatibilidad en teléfonos.
