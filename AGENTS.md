# Convenciones para trabajar en Fort Control

## Entorno y alcance

- Proyecto **Godot 4.6.3 Standard**, **GDScript** y renderizador **Mobile**. Compatibility se puede probar mediante `--rendering-method gl_compatibility`.
- Usa el checkout existente. Cada tarea cloud ya está aislada; no crees un Git worktree salvo petición explícita del usuario.
- Lee `README.md`, los recursos JSON y los scripts afectados antes de cambiar una interfaz. No reemplaces cambios del usuario o de otros colaboradores.
- Conserva el funcionamiento offline. No añadas backend, cuentas, monetización, servicios o plugins sin una petición que lo requiera.

## Diseño y código

- Usa nombres de archivo `snake_case.gd`, nombres de clase `FortNombre`, tabuladores de GDScript y tipos explícitos en APIs compartidas.
- Mantén separados coordinación, economía, oleadas, combate, cámara y HUD. Usa señales para comunicar eventos; evita autoloads y rutas absolutas entre nodos.
- El estado real pertenece a los sistemas. El HUD representa ese estado y emite solicitudes, sin cobrar oro ni conceder recompensas por su cuenta.
- Los valores de balance se editan en `resources/balance/default.json`, `resources/waves/default.json` y `resources/maps/meadow.json`. Documenta los cambios de campos en `docs/balance.md`.
- Mantén la lógica del enemigo separada de sus modelos. Reutiliza materiales y geometría sencilla; evita navegación dinámica y física compleja para este MVP.
- Conserva recompensa e impacto únicos, oro no negativo, ocupación única, nivel máximo 3, una oleada activa y resolución completa antes de victoria.
- Trata referencias a enemigos como temporales: comprueba su validez y estado antes de usarlas desde torres o proyectiles.
- Usa UI con anchors/containers, botones táctiles amplios y zonas seguras. Un gesto de cámara nunca debe ejecutar una construcción.

## Validación

Desde la raíz:

```bash
bash scripts/run_tests.sh
```

Si el motor no está en `PATH`, proporciona `GODOT_BIN`. En macOS:

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot bash scripts/run_tests.sh
```

Para cambios de gameplay, añade o adapta pruebas que comprueben el comportamiento afectado y ejecuta la suite. Para cambios de UI/cámara, complementa la carga headless con revisión visual y controles reales cuando haya entorno gráfico. No declares pruebas aprobadas si no terminaron o no ejercitaron el comportamiento.

`bash scripts/run_tests.sh --gameplay` añade tres simulaciones con combate real: primera oleada accesible, estrategia ganadora de cinco oleadas y estrategia sin pérdidas de vida. Ejecútalas cuando cambies balance, alcance, cadencia, movimiento o reglas de oleadas. La suite habitual también comprueba efectos, sonido, alcance y sus interacciones con pausa, reinicio y UI.

Registra resultados y límites concretos en la entrega. No presentes una prueba headless como evidencia de rendimiento o compatibilidad de hardware móvil. Consulta `docs/validation.md` para la revisión manual.

## Repositorio público

- Versiona fuentes `.gd`, escenas `.tscn`, recursos necesarios y archivos `.uid` generados junto a scripts. No versionar `.godot/` ni exportaciones.
- Mantén certificados, claves, tokens, contraseñas, keystores y perfiles de firma fuera del repositorio. No inventes identidades de publicación.
- Los presets de exportación deben incluir `*.json` en su filtro de archivos no reconocidos como recursos, porque el juego carga mapa, balance y oleadas mediante `FileAccess`.
- No desactives validaciones TLS, firmas o checksums para instalar herramientas.
- Actualiza documentación si cambian controles, comandos, APIs públicas o balance. No añadas dependencias externas para sustituir geometría provisional sin necesidad.
