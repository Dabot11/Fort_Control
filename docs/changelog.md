# Cambios de Fort Control

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
