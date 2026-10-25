# Arquitectura del MVP

La escena `scenes/main/main.tscn` es el punto de entrada. Su coordinador, `FortGame`, crea los sistemas y conecta sus señales. No necesita autoloads ni servicios externos. Los datos del mapa y balance se cargan desde `resources/`.

| Clase | Responsabilidad |
| --- | --- |
| `FortGame` | Estado de partida, selección, validación de acciones y conexión de sistemas |
| `FortEconomy` | Saldo, cobros válidos y recompensas |
| `FortCastle` | Vida y daño recibido |
| `FortWaveManager` | Aparición de enemigos y finalización de oleadas |
| `FortMap` | Geometría del escenario y conversión de casillas a coordenadas |
| `FortBuildSlot` | Identidad, ocupación, selección y colisión seleccionable de una casilla |
| `FortEnemy` | Vida, desplazamiento por waypoints y transición a muerte o llegada |
| `FortTower` | Nivel, selección de objetivo, orientación y cadencia |
| `FortProjectile` | Seguimiento visual e impacto único |
| `FortCamera` | Desplazamiento, giro horizontal, zoom, límites y selección mediante raycast |
| `FortHUD` | Valores mostrados, panel contextual y menús |
| `FortFeedback` | Respuesta audiovisual a eventos ya resueltos, límites de efectos y estado de sonido |
| `FortSoundBank` | Generación y caché de sonidos PCM propios, sin servicios ni recursos de terceros |
| `FortTransientEffect` | Efectos visuales temporales con vida limitada |
| `FortRangeIndicator` | Alcance actual y próximo nivel de la casilla seleccionada |

## Flujo de partida

1. El coordinador carga mapa y balance, crea el escenario y restablece oro, vida y oleadas.
2. La cámara emite la selección de una casilla. El HUD presenta construcción o estadísticas según su ocupación.
3. Al confirmar, el coordinador comprueba que la casilla pertenece al mapa, la partida permite actuar y hay oro suficiente. Solo entonces crea o mejora una torre.
4. El jugador inicia una oleada. El gestor programa apariciones con los valores de su entrada JSON y bloquea otro inicio mientras está activa.
5. Los enemigos siguen el camino; las torres eligen al más avanzado a su alcance y generan proyectiles.
6. Al morir o llegar, el enemigo entra primero en estado terminal y emite la señal correspondiente. El coordinador aplica oro o daño, nunca ambos por el mismo resultado.
7. Una oleada termina cuando no quedan apariciones pendientes ni enemigos activos. Al terminar la quinta se muestra victoria; si la vida llega a cero, derrota.
8. Pausa detiene la simulación y mantiene operables los controles del menú. Reiniciar elimina el estado de la partida anterior y repone todos los valores iniciales.

## Separar presentación y lógica

Los modelos GLB de enemigos, torres, espada y flecha viven en `assets/models/`. La lógica de combate conserva sus responsabilidades; los scripts visuales adaptan escala, orientación, animaciones y pivotes. Las texturas forman parte de los recursos locales y no hay descargas durante una partida.

| Capa visual | Contrato con la lógica |
| --- | --- |
| `enemy_visual.gd` | `animate_walk(delta, speed)`, `set_health_ratio(ratio)` y `show_hit()` |
| `tower_visual.gd` | `set_level(level)`, `aim_at(world_target)`, `muzzle_position()` en coordenadas globales y `play_recoil()` |
| Presentación de `projectile.gd` | Orientar el modelo de flecha; el proyectil consume su estado antes de aplicar daño |

La orientación de avance del enemigo y la de disparo son el eje local `-Z`. La animación del esqueleto no debe trasladar su nodo lógico ni cambiar el camino. La espada sigue la mano como parte de la presentación. La barra de salud conserva su propia transformación para que la reacción de impacto no la deforme.

La torre mantiene la base inmóvil mientras gira el arma. El origen del proyectil se obtiene de su boca de disparo, y las mejoras conservan la dirección a la que apunta. Los tres niveles representan los mismos valores de balance que muestra el HUD.

No se usan cuerpos físicos para mover esqueletos ni navegación dinámica: el camino está definido como puntos y el movimiento consume distancia sobre cada segmento. Las torres no alteran ese recorrido. Las colisiones de construcción se reservan para selección; no deben impedir el paso.

Las escenas de enemigo, torre y proyectil ofrecen puntos de entrada reutilizables. El terreno, el castillo y la decoración siguen creados en código; los modelos de combate se importan con Godot. La preparación de los modelos y sus límites están documentados en `assets/models/README.md`.

## Respuesta visual y sonora

El coordinador envía los eventos de disparo, impacto, eliminación, construcción, mejora, daño al castillo, inicio de oleada y resultado a `FortFeedback`. Esta capa presenta lo que ya ocurrió: no aplica daño, no cobra oro y no decide quién gana. Las señales y estados de combate mantienen su responsabilidad original.

`FortSoundBank` sintetiza nueve sonidos propios y los conserva en memoria como PCM mono de 16 bits a 22 050 Hz. No se descargan archivos ni se requiere un plugin. El banco y sus límites están documentados en `assets/audio/README.md`.

El feedback admite como máximo **48 grupos de efectos transitorios** y **8 voces de audio**: siete para gameplay que obedecen la pausa y una para el resultado, que puede sonar con la simulación detenida. Son límites de concurrencia del diseño, no una medición de rendimiento en teléfonos. El reinicio retira los efectos y sonidos de la partida anterior.

Los efectos incluyen destello de disparo e impacto, fragmentos de hueso con el oro obtenido, anillos al construir o mejorar y aviso de vida perdida en el castillo. El modelo del enemigo puede reaccionar al impacto y la ballesta muestra retroceso; estos movimientos son visuales y no cambian el recorrido ni la cadencia lógica.

`FortRangeIndicator` representa el alcance horizontal en el suelo: cian para el nivel actual o una construcción nueva, y dorado discontinuo para la siguiente mejora. El HUD deriva la comparación de estadísticas del mismo arreglo `tower_levels` usado por combate y economía. En nivel 3 desaparece la anticipación de mejora.

El control de sonido de los menús emite una solicitud al coordinador. El estado se conserva al reiniciar una partida dentro de la sesión, sin persistencia en disco. El contador de vida y el mensaje de oleada proporcionan señales visuales incluso con audio silenciado.

## Límites que deben conservarse

- El oro no puede bajar de cero y las operaciones rechazadas no modifican el estado.
- Una casilla admite una sola torre y las mejoras terminan en nivel 3.
- Un enemigo resuelto no vuelve a ser objetivo ni vuelve a cobrar recompensa o dañar el castillo.
- Los proyectiles comprueban que su objetivo sigue siendo válido.
- Una oleada activa bloquea un segundo inicio.
- Victoria requiere todas las oleadas terminadas y ningún enemigo pendiente.
- Los valores visibles se derivan de los sistemas, no de contadores independientes en el HUD.
- Un arrastre o pellizco no se convierte en una selección accidental al levantar los dedos.

La suite headless comprueba invariantes de lógica y carga. La revisión visual y el rendimiento móvil requieren la lista manual de `docs/validation.md`.
