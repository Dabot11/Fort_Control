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
| `FortCamera` | Pan, zoom, límites y selección mediante raycast |
| `FortHUD` | Valores mostrados, panel contextual y menús |

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

Los modelos provisionales de enemigos y torres están separados de sus reglas de combate. Los modelos GLB futuros deben cambiar esa capa visual, manteniendo las señales y métodos de la lógica.

No se usan cuerpos físicos para mover esqueletos ni navegación dinámica: el camino está definido como puntos y el movimiento consume distancia sobre cada segmento. Las torres no alteran ese recorrido. Las colisiones de construcción se reservan para selección; no deben impedir el paso.

Las escenas de enemigo, torre y proyectil ofrecen puntos de entrada reutilizables. La mayor parte de la geometría provisional se crea en código para que el proyecto sea autónomo y mantenga pocos recursos externos.

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
