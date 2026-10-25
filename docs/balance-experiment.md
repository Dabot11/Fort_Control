# Ajuste de dificultad tras la primera partida en iPhone

El usuario completó las cinco oleadas del MVP en un iPhone 16 Pro y reportó controles cómodos. Las primeras cuatro oleadas resultaron fáciles y la quinta difícil de terminar sin perder vida. No se registró una cifra exacta de vida final del usuario ni medidas de rendimiento físico.

## Cambio elegido

La primera oleada conserva sus valores. Las cantidades siguen siendo 6, 9, 12, 16 y 22 enemigos: 65 en total. Costos, recompensas, daño de torres y vida del castillo no cambian. Se aumenta gradualmente la presión de las oleadas intermedias y se reduce el salto de la cuarta a la quinta.

| Oleada | Vida antes → ahora | Velocidad antes → ahora | Intervalo antes → ahora |
| --- | ---: | ---: | ---: |
| 1 | 48 → 48 | 1.25 → 1.25 | 1.70 → 1.70 |
| 2 | 85 → 110 | 1.35 → 1.40 | 1.40 → 1.30 |
| 3 | 140 → 180 | 1.45 → 1.50 | 1.10 → 1.00 |
| 4 | 215 → 250 | 1.55 → 1.60 | 0.90 → 0.85 |
| 5 | 320 → 300 | 1.65 → 1.65 | 0.72 → 0.80 |

La quinta sigue teniendo más enemigos, más vida por enemigo, mayor velocidad y menor separación entre apariciones que la cuarta. Reducir su pico de presión no garantiza una defensa perfecta con cualquier colocación.

## Método

Simulaciones con Godot 4.6.3 headless, sin daño artificial ni oro concedido por el ensayo. Los enemigos recorrieron el camino; las torres eligieron objetivos y sus proyectiles causaron todo el daño. La velocidad se aceleró diez veces y la frecuencia física se fijó en 600 ticks por segundo para conservar pasos simulados de 1/60 s. Las comparaciones iniciales usaron una copia temporal de las fuentes del MVP (`82365e0`) con los datos de cada candidato inyectados antes de iniciar la partida.

## Resultados observados

| Estrategia | Vida al terminar cada oleada con el ajuste | Resultado |
| --- | --- | --- |
| Una ballesta en la posición 5, solo primera oleada | 20 | 6 eliminaciones, 350 monedas |
| Estrategia de referencia, compras entre oleadas | 20, 20, 20, 19, 19 | Victoria, 625 monedas, 5 torres |
| Estrategia alternativa, compras entre oleadas | 20, 20, 20, 20, 20 | Victoria, 550 monedas, 4 torres |
| Tres torres iniciales sin reinvertir | 20, 19, 10, 0 | Derrota durante la cuarta oleada |

La estrategia de referencia sobre los datos originales terminaba con 20, 20, 20, 20 y 17 vidas. Con los datos nuevos, el pico observado de enemigos simultáneos aumenta de **10 en la cuarta** a **13 en la quinta**. El promedio de recorrido alcanzado por los enemigos eliminados pasa de aproximadamente **54 % a 56 %** entre esas dos oleadas: la defensa necesita más trabajo en el tramo final.

Estos porcentajes se calculan sobre enemigos eliminados, no sobre fugados. Un enemigo que llega al castillo recorre el 100 % y se registra por separado como vida perdida. No deben interpretarse como el avance máximo de todos los enemigos.

## Estrategia alternativa reproducible

Los índices corresponden a `build_slots`, contando desde cero. Se utilizan exclusivamente monedas obtenidas por eliminaciones y compras entre oleadas:

1. Construir inicialmente en las posiciones **2, 3 y 5**.
2. Después de cada oleada, intentar mejorar a nivel 2 en el orden **3, 2, 5**.
3. Después intentar las mejoras a nivel 3 en ese mismo orden, cuando alcance el oro.
4. Con el saldo restante, intentar construir en las posiciones **1, 4, 7, 6, 0**, en ese orden, omitiendo las ocupadas.

En la ejecución registrada, las tres torres iniciales llegaron a nivel 3 y se construyó una cuarta en la posición 1. La estrategia demuestra que una partida sin fugas es posible con este balance; no sustituye nuevas pruebas con personas.

Las verificaciones integradas y las partidas reales se ejecutan mediante `bash scripts/run_tests.sh --gameplay`. El resultado actual del comando y los cambios posteriores de datos prevalecen sobre estas observaciones.

En la integración final con efectos y sonido, la estrategia de referencia terminó con 19–20 vidas en distintas ejecuciones. Las apariciones se programan por frame y la simulación acelerada puede variar una fuga, el oro disponible y las compras siguientes. La estrategia alternativa también completó la integración con 20 vidas. Consulta `validation.md` para los últimos resultados; la tabla anterior conserva los ensayos comparativos realizados sobre la copia del MVP.
