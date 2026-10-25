# Cambios de Fort Control

## Giro de cámara con dos dedos

Deslizar dos dedos juntos hacia los lados gira la vista alrededor del tablero, manteniendo su inclinación. Un dedo desplaza la cámara y el pellizco sigue controlando el zoom. En escritorio, el giro también está disponible al arrastrar con el botón derecho del mouse.

El reconocimiento agrupa los movimientos de ambos dedos y conserva una referencia de zoom estable para que los eventos intercalados no dejen cambios de zoom o desplazamientos accidentales. La pausa cancela los gestos pendientes y reiniciar recupera la orientación inicial. El HUD y la guía de controles muestran el nuevo gesto.

Pasaron 343 comprobaciones automatizadas, incluidas 68 de entrada mediante eventos de Godot. Se revisó el giro en una ventana Mobile/Vulkan de 720 × 1280 en Linux. La sensación del gesto con dos dedos reales queda pendiente de probar en el iPhone.

## Integración de modelos 3D

Esta revisión incorpora los modelos facilitados para Fort Control: ballesta, esqueleto animado, espada y flecha. Los recursos GLB y sus texturas se incluyen en el proyecto para jugar offline.

- Preparación de la torre original para reducir su complejidad y permitir que la ballesta apunte sobre una base fija.
- Esqueleto con animación de caminar y espada que acompaña el movimiento de su mano.
- Flecha texturizada en los disparos.
- Adaptación de escala, orientación, boca de disparo, reacción de impacto y representación de los tres niveles de torre.
- Documentación de procedencia y preparación en `assets/models/README.md`.

La integración mantiene el mapa, las reglas de combate, el balance de las oleadas y los ajustes de exportación existentes. El castillo, el terreno y la decoración conservan su geometría procedural.

La importación termina sin errores ni advertencias, y pasan 311 comprobaciones automatizadas y tres simulaciones con combate real. Los resultados de revisión visual y empaquetado se registran en `validation.md`. La nueva apariencia y su rendimiento todavía requieren una partida en el iPhone; la prueba física de una versión anterior no acredita estos modelos.

## Iteración de respuesta audiovisual y balance

Esta revisión parte del MVP `82365e0` y del reporte de una partida completa en iPhone 16 Pro. El usuario consideró cómodos los controles y fáciles las primeras cuatro oleadas, con mayor dificultad concentrada en la quinta. No se registraron métricas de rendimiento ni un saldo final exacto de vida.

- Sonidos propios generados localmente para combate, construcción, mejoras, daño al castillo, oleadas y resultado.
- Control de sonido en pausa y resultado; conserva la preferencia durante el reinicio de partida, sin guardarla en disco.
- Efectos de impacto, eliminación, oro ganado, construcción y mejora, con límites de concurrencia.
- Reacción de impacto del esqueleto, retroceso de ballesta y aviso visual al perder vida.
- Alcance de la torre seleccionada y anticipación del alcance de su próxima mejora.
- Comparación de daño, alcance y ataques por segundo antes de mejorar.
- Revisión de la progresión de dificultad de las oleadas 2–5; parámetros y evidencia en `balance.md` y `validation.md`.
- Guía de iPhone actualizada con ETC2/ASTC, plantillas de la versión correcta, Personal Team gratuito y exportación del proyecto para firma desde Xcode.

La revisión mantiene un mapa, ocho posiciones de construcción, una ballesta de tres niveles y un tipo de esqueleto. Los modelos siguen siendo provisionales. No modifica la configuración móvil local de `project.godot` ni `export_presets.cfg`.

**Validación física:** pendiente repetir esta revisión en el iPhone. La prueba manual del MVP base no acredita por sí sola el nuevo audio, los efectos o el nuevo balance. Los resultados automatizados de la revisión se registran por separado en `validation.md`.

## MVP base — `82365e0`

- Proyecto Godot ejecutable con mapa 3D, cámara isométrica, mouse y gestos táctiles.
- Construcción, mejoras, proyectiles, economía, cinco oleadas, victoria, derrota, pausa y reinicio.
- Pruebas headless de lógica e interacción, simulaciones de combate y validación del paquete PCK.
- Partida completa posteriormente reportada por el usuario en iPhone 16 Pro con Godot 4.7.2, Xcode 27 e iOS 27.0.1.
