# Pruebas automáticas

Desde la raíz del proyecto:

```bash
bash scripts/run_tests.sh
```

En macOS se detecta `/Applications/Godot.app/Contents/MacOS/Godot`. También puedes indicar otro ejecutable:

```bash
GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot" bash scripts/run_tests.sh
```

El script primero importa el proyecto y después ejecuta `test_runner.gd`, `test_input.gd`, `test_polish.gd` y `test_models.gd` en modo headless. No requiere plugins ni conexión a internet. Los comandos propagan su código de salida; el runner también rechaza errores registrados por Godot aunque el proceso devolviera cero. Una aserción fallida termina con código 1; cada suite tiene un watchdog de 60 segundos que termina con código 124 si un error interrumpe la ejecución antes de finalizar.

La suite instancia la escena principal y ejecuta 11 grupos de integración:

1. Carga de escena, cámara, estado inicial, mapa y ocho casillas fuera del camino.
2. Desplazamiento por segmentos, daño y una sola señal de muerte.
3. Llegada al castillo sin posibilidad de muerte o recompensa posterior.
4. Construcción válida, casillas inválidas, compra duplicada y saldo insuficiente.
5. Costos de mejora, daño aumentado y límite de nivel 3.
6. Selección del enemigo más avanzado, proyectil visible, impacto único y objetivo liberado.
7. Recompensas y daño al castillo mediante enemigos realmente creados por el juego, incluyendo callbacks repetidos.
8. Oleadas simultáneas rechazadas; completar requiere terminar de generar enemigos y resolver los vivos.
9. Las cinco oleadas y victoria solamente al resolver el último enemigo de la quinta.
10. Derrota, bloqueo de acciones y movimiento detenido.
11. Pausa, reanudación y reinicio completo de economía, castillo, oleadas, selección y entidades.

Los avances de física y del reloj de oleadas se simulan con deltas controlados; las entidades, colisiones, señales, compras y proyectiles son las implementaciones reales. La prueba de victoria elimina enemigos mediante daño directo para verificar las transiciones: **no demuestra que una estrategia concreta pueda ganar ni sustituye una partida manual**.

La suite de entrada `test_input.gd` complementa estos casos con 36 comprobaciones mediante `Input.parse_input_event`: selección por raycasting con mouse/toque, construcción, mejora, máximo nivel, saldo insuficiente, separación de arrastre/selección, pellizco, bloqueo de cámara sobre UI, pausa/reanudación/reinicio y adaptación a 390×844, 768×1024 y 1024×768. También verifica botones de al menos 44 px en la ventana estrecha. Los eventos sintéticos no sustituyen probar una pantalla táctil física.

La suite `test_polish.gd` añade 70 comprobaciones de integración de la presentación: alcance actual y siguiente derivados del balance, vista previa de mejoras, limpieza al cerrar/pausar/reiniciar, botón táctil de sonido y persistencia de silencio durante el reinicio, efectos limitados a 48 y audio a ocho voces, pausa efectiva de streams y expiración de efectos, disparos e impactos reales conectados al feedback, recompensa única y señales de victoria/derrota. También comprueba que los efectos reflejen el daño real recibido por el castillo y que el nuevo control de sonido quepa en las tres proporciones de pantalla. Los efectos decorativos nunca deben modificar oro, salud ni colisiones.

Las comprobaciones de audio verifican que haya streams PCM no vacíos y que el mute, la pausa y la selección de voces funcionen. **No equivalen a escuchar los sonidos ni a validar su volumen en un teléfono.**

La suite `test_models.gd` añade 62 comprobaciones y carga los GLB reales de esqueleto, espada, torre y flecha. Comprueba materiales con texturas, recursos compartidos entre instancias, límites de geometría y resolución de texturas, y ausencia de colisiones añadidas por el arte. Ejercita caminar con huesos reales, ausencia de desplazamiento de la raíz por animación, espada vinculada al esqueleto, salud independiente de la reacción al golpe, pausa y reanudación. También apunta la torre hacia cuatro lados, comprueba que su base permanezca quieta, que la boca de disparo acompañe la orientación y las mejoras, y que el retroceso vuelva al reposo. La flecha debe conservar escala legible y eje longitudinal alineado con su vuelo. Estas comprobaciones no sustituyen revisar visualmente orientación, texturas o animaciones desde la cámara del juego.

## Partidas completas con combate real

```bash
bash scripts/run_tests.sh --gameplay
```

Esta opción añade `test_gameplay.gd` en tres escenarios. `first_one` comprueba que una sola torre pueda defender la primera oleada sin perder vidas. `strategy` construye y mejora usando exclusivamente oro real entre oleadas, y debe terminar las cinco con victoria. `strategy_perfect` prioriza distintas mejoras y una posición de apoyo anterior en el recorrido; debe completar las cinco sin fugas. En los tres casos los esqueletos caminan y las torres/proyectiles hacen todo el daño: no se matan enemigos desde la prueba.

Se ejecuta a diez veces la velocidad con 600 ticks de física por segundo para conservar un paso de simulación equivalente a 1/60. Cada escenario tiene un límite de 90 segundos de reloj; el watchdog adicional corta interrupciones a los 120 segundos. La salida `GAMEPLAY_RESULT` incluye salud, oro, compras y resultado, para poder revisar el balance después de cambiar los JSON. Esto demuestra estrategias concretas; no mide el rendimiento móvil.

Resultados ejecutados con el balance incluido y Godot 4.6.3: `first_one` completó la primera oleada con **20 vidas y 350 monedas**; `strategy` ganó las cinco con **19–20 vidas** en las ejecuciones observadas; `strategy_perfect` consiguió **20 vidas, 550 monedas y cuatro torres**. En la última ejecución, la estrategia estándar también terminó con 20 vidas, 550 monedas y cuatro torres; otra ejecución terminó con 19 vidas, 625 monedas y cinco torres. La temporización de apariciones por frame en la simulación acelerada puede cambiar una fuga y las compras posteriores. Los tres procesos terminaron con código 0. Estos resultados prueban estrategias concretas, sin garantizar una partida perfecta con cualquier distribución de torres.

La ejecución de referencia con los modelos importados y Godot **4.6.3** completó **311 comprobaciones: 143 de gameplay, 36 de entrada, 70 de presentación y 62 de modelos, 0 fallos**. La salida del comando actual es siempre la autoridad para una revisión posterior; las simulaciones adicionales se informan por separado.

El modo headless no verifica apariencia, interacción con dedos reales, notch, rendimiento, exportación ni comportamiento de iOS/Android. Estos puntos necesitan las verificaciones manuales descritas en la documentación principal.
