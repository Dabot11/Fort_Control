# Sonidos originales de Fort Control

Los nueve efectos se sintetizan con `scripts/feedback/sound_bank.gd`, usando únicamente Godot. No utilizan muestras descargadas, servicios, plugins ni archivos con licencias de terceros. No requieren conexión a internet ni importaciones adicionales.

`FortSoundBank.streams()` genera y conserva una copia de cada `AudioStreamWAV` en memoria. El formato es PCM mono de 16 bits a 22.050 Hz, con entradas y salidas suavizadas y un pico máximo de 0,72. La síntesis usa un generador de ruido con semilla local; no altera el estado aleatorio del juego. Las llamadas posteriores reutilizan los streams.

| Clave | Duración | Uso |
| --- | --- | --- |
| `shot` | 0,16 s | Cuerda y cuerpo de madera de la ballesta |
| `hit` | 0,13 s | Impacto breve |
| `kill` | 0,38 s | Tintineo al obtener recompensa |
| `built` | 0,30 s | Construcción de una torre |
| `upgraded` | 0,67 s | Arpegio de mejora |
| `castle_hit` | 0,44 s | Golpe grave al castillo |
| `wave_started` | 0,78 s | Aviso de oleada |
| `victory` | 1,10 s | Resolución de victoria |
| `defeat` | 0,98 s | Resolución de derrota |

`FortSoundBank.export_samples(directory)` permite guardar los nueve WAV para escucharlos o medirlos fuera del juego. Este método devuelve un código `Error`; no modifica los streams usados durante la partida. Los WAV exportados son material generado y no necesitan versionarse.

El control de volumen, silencio, prioridad, número de voces y pausa pertenece a `FortFeedback`, separado de la síntesis. Una prueba headless puede validar formatos, niveles y disparo de eventos; la comodidad auditiva y el volumen en iPhone/Android necesitan escucharse en el dispositivo.
