# Pruebas automáticas

Desde la raíz del proyecto:

```bash
bash scripts/run_tests.sh
```

En macOS se detecta `/Applications/Godot.app/Contents/MacOS/Godot`. También puedes indicar otro ejecutable:

```bash
GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot" bash scripts/run_tests.sh
```

El script primero importa el proyecto y después ejecuta `test_runner.gd` y `test_input.gd` en modo headless. No requiere plugins ni conexión a internet. Los comandos propagan su código de salida; el runner también rechaza errores registrados por Godot aunque el proceso devolviera cero. Una aserción fallida termina con código 1; cada suite tiene un watchdog de 60 segundos que termina con código 124 si un error interrumpe la ejecución antes de finalizar.

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

## Partidas completas con combate real

```bash
bash scripts/run_tests.sh --gameplay
```

Esta opción añade `test_gameplay.gd` en dos escenarios. `first_one` comprueba que una sola torre pueda defender la primera oleada sin perder vidas. `strategy` construye y mejora usando exclusivamente oro real entre oleadas, y debe terminar las cinco con victoria. En ambos casos los esqueletos caminan y las torres/proyectiles hacen todo el daño: no se matan enemigos desde la prueba.

Se ejecuta a diez veces la velocidad con 600 ticks de física por segundo para conservar un paso de simulación equivalente a 1/60. Cada escenario tiene un límite de 90 segundos de reloj; el watchdog adicional corta interrupciones a los 120 segundos. La salida `GAMEPLAY_RESULT` incluye salud, oro, compras y resultado, para poder revisar el balance después de cambiar los JSON. Esto demuestra estrategias concretas; no mide el rendimiento móvil.

Resultados ejecutados con el balance incluido y Godot 4.6.3: `first_one` completó la primera oleada con **20 vidas y 350 monedas**; `strategy` ganó las cinco con **17 vidas, 475 monedas y cuatro torres**. Ambos procesos terminaron con código 0.

La ejecución de referencia con Godot **4.6.3** completó **143 comprobaciones de gameplay y 36 de entrada, 0 fallos**. La salida del comando actual es siempre la autoridad para una revisión posterior.

El modo headless no verifica apariencia, interacción con dedos reales, notch, rendimiento, exportación ni comportamiento de iOS/Android. Estos puntos necesitan las verificaciones manuales descritas en la documentación principal.
