# Referencia de balance y mapa

Los recursos se leen como JSON. Las distancias usan unidades del mundo de Godot y los tiempos se expresan en segundos. Una casilla mide inicialmente 1.25 unidades. Tras editar un recurso, detén el juego con **F8** y vuelve a ejecutarlo con **F5** para cargar los nuevos valores. El botón Reiniciar restaura la partida con los datos que ya estaban cargados.

## Economía y fortaleza

Archivo: `resources/balance/default.json`.

| Campo | Valor inicial | Significado |
| --- | ---: | --- |
| `initial_gold` | 300 | Monedas al iniciar o reiniciar |
| `castle_health` | 20 | Vida inicial del castillo |
| `enemy_reward` | 25 | Monedas por esqueleto eliminado |
| `castle_damage` | 1 | Vida perdida por esqueleto que completa el camino |
| `projectile_speed` | 15.0 | Velocidad de los proyectiles en unidades por segundo |

Usa enteros no negativos para monedas, recompensas y daño al castillo; la vida inicial debe ser mayor que cero. La velocidad del proyectil debe ser positiva.

## Ballesta

`tower_levels` contiene tres objetos en orden. El campo `cost` del primer nivel es el precio de construcción; en los siguientes niveles es el costo adicional de mejorar desde el anterior. Por ejemplo, alcanzar el nivel 3 desde una casilla vacía cuesta `100 + 125 + 200 = 425` monedas.

| Nivel | `cost` | `damage` | `range` | `interval` | Disparos/s aproximados |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 100 | 18.0 | 3.7 | 0.95 | 1.05 |
| 2 | 125 | 34.0 | 4.3 | 0.75 | 1.33 |
| 3 | 200 | 58.0 | 4.9 | 0.58 | 1.72 |

- `damage`: daño de un impacto; no es daño por segundo.
- `range`: radio horizontal de adquisición del objetivo.
- `interval`: segundos mínimos entre disparos. Un número menor permite disparar más seguido.
- La frecuencia mostrada se calcula como `1 / interval`.

Mantén exactamente tres niveles para este MVP y usa valores positivos de daño, alcance e intervalo. Las torres eligen al enemigo vivo que más distancia haya recorrido dentro de su alcance. No pueden atacar un enemigo ya muerto o resuelto.

## Oleadas

Archivo: `resources/waves/default.json`. Cada objeto representa una oleada, en orden.

| Oleada | `count` | `health` | `speed` | `spawn_interval` |
| --- | ---: | ---: | ---: | ---: |
| 1 | 6 | 48.0 | 1.25 | 1.70 |
| 2 | 9 | 110.0 | 1.40 | 1.30 |
| 3 | 12 | 180.0 | 1.50 | 1.00 |
| 4 | 16 | 250.0 | 1.60 | 0.85 |
| 5 | 22 | 300.0 | 1.65 | 0.80 |

- `count`: cantidad total de esqueletos de la oleada; entero mayor que cero.
- `health`: vida de cada esqueleto, mayor que cero.
- `speed`: unidades por segundo a lo largo del camino, mayor que cero.
- `spawn_interval`: separación temporal entre apariciones, mayor que cero.

Hay 65 enemigos en total. Aumentar vida, velocidad o cantidad eleva la dificultad; reducir el intervalo concentra el ataque. Cambia un parámetro por vez y juega la partida completa para evitar una primera oleada demasiado exigente o un final trivial.

### Motivo de esta revisión

En la partida del MVP base `82365e0`, el usuario reportó que las primeras cuatro oleadas eran fáciles y que la quinta exigía más cuidado para evitar perder vida. Esta revisión distribuye antes la presión: sube vida y velocidad moderadamente en las oleadas 2–4 y acerca sus apariciones. La quinta tiene algo menos de vida por enemigo y más separación entre apariciones para reducir el salto final.

La primera oleada conserva sus parámetros de introducción. También se mantienen cantidad de enemigos, economía y estadísticas de las torres, de modo que el ajuste se concentre en el ritmo de las oleadas. El alcance y las comparaciones visibles de mejoras usan estos mismos datos de torre, sin un balance separado para la interfaz.

Las simulaciones sirven para comprobar que existen estrategias ganadoras y que invertir en defensas importa; el ritmo percibido debe confirmarse en una nueva partida humana. El [experimento de balance](balance-experiment.md) detalla la comparación y las compras de una estrategia sin fugas. Consulta [validación](validation.md) para separar resultados del MVP original, pruebas de esta revisión y reporte del usuario.

## Mapa

Archivo: `resources/maps/meadow.json`.

| Campo | Función |
| --- | --- |
| `columns`, `rows` | Cantidad de columnas y filas; inicialmente 8 y 14 |
| `cell_size` | Ancho y profundidad de cada casilla; inicialmente 1.25 |
| `path` | Secuencia ordenada de casillas `[columna, fila]` recorridas por el enemigo |
| `build_slots` | Ocho casillas habilitadas para construcción |
| `castle` | Casilla del castillo, inicialmente `[4, 0]` |

Los índices comienzan en cero. La columna corresponde a X y la fila a Z, con el tablero centrado en el origen del mundo. La fila 13 es el borde de entrada y la fila 0 la zona de la fortaleza. El camino termina en `[4, 1]`, frente a ella.

Mantén todas las coordenadas dentro del tablero, el camino continuo entre casillas vecinas, las casillas de construcción únicas y fuera del camino, y el castillo separado de la última casilla transitable. Cambiar los datos del mapa no implementa navegación dinámica: las torres nunca alteran el recorrido.
