# Versión de prueba Web

El objetivo es que David pruebe cada actualización abriendo el mismo enlace, sin repetir Git, Godot y Xcode en su Mac.

- Juego: <https://dabot11.github.io/Fort_Control/>
- Publicaciones: <https://github.com/Dabot11/Fort_Control/actions/workflows/web-preview.yml>
- Versión desplegada: <https://dabot11.github.io/Fort_Control/version.json>

## Activación inicial

En GitHub, abre **Dabot11/Fort_Control → Settings → Pages** y, en **Build and deployment → Source**, elige **GitHub Actions**. Es una configuración única. La integración cloud actual pudo consultar el repositorio pero GitHub rechazó crear Pages con `403 Resource not accessible by integration`; no se ha habilitado automáticamente.

Después se puede repetir el workflow desde **Actions → Probar y publicar Web → Run workflow**, o subir la siguiente actualización a `main`. El agente debe comprobar que la publicación terminó y que `version.json` coincide con el commit, antes de entregar el enlace como disponible.

## Uso cotidiano

1. El agente implementa y valida los cambios solicitados, y los sube a `main`.
2. GitHub Actions ejecuta las comprobaciones del juego y tres simulaciones de combate, exporta y publica. Si falla la construcción, no sustituye la versión publicada.
3. David abre el enlace en Safari. Si ya tenía el juego abierto, recarga para iniciar una partida con la versión nueva.

El juego conserva la selección, construcción, mejoras, pausa y los gestos: un dedo desplaza, dos dedos juntos giran horizontalmente y un pellizco cambia el zoom. El navegador puede requerir un primer toque para activar el audio.

La primera carga requiere internet para descargar el motor y los recursos. La partida se ejecuta localmente en el navegador, sin cuenta ni servidor de juego. No hay guardado: recargar o cerrar la página pierde la partida actual. No se instala un service worker ni se promete funcionamiento offline en el navegador.

## Cómo se construye

El workflow fija **Godot 4.6.3 Standard** y verifica SHA256 del editor y las plantillas oficiales. La caché contiene solo el ejecutable y la plantilla Web utilizada; se vuelven a comprobar sus hashes al reutilizarlos. La primera ejecución descarga el paquete oficial de plantillas completo, pero no lo conserva en la caché.

`scripts/export_web.sh` copia los recursos del juego a una carpeta temporal, aplica `scripts/prepare_web.gd` y usa el preset separado de `tools/web/export_presets.cfg`. Esto mantiene intactos `project.godot`, `export_presets.cfg`, la caché nativa y los ajustes de firma del checkout original.

La copia utiliza **Compatibility / WebGL 2**, sin hilos ni extensiones, y contiene los JSON de mapa, balance y oleadas. No necesita cabeceras COOP/COEP. Los archivos JS, WASM y PCK llevan el commit y un resumen del contenido en sus nombres, para que una versión nueva no reutilice recursos de otra. `index.html` mantiene una URL estable; `version.json` registra el commit, el motor, la fecha de construcción y si había cambios locales.

Para reproducir la exportación local con Godot 4.6.3 y su plantilla `web_nothreads_release.zip` instalada:

```bash
bash scripts/export_web.sh
python3 -m http.server 8000 --directory build/web
```

Abre la dirección HTTP del servidor local en el navegador del mismo equipo. Abrir `index.html` directamente desde Finder no sirve para cargar WASM y PCK. Este servidor local solo es una herramienta de desarrollo; el enlace compartido utiliza GitHub Pages y HTTPS.

## Alcance de las pruebas

La Web agiliza las pruebas de jugabilidad, gráficos e interfaz. Puede verse y rendir distinto a la aplicación iOS, porque usa otro renderizador y las restricciones del navegador. Validar Web no acredita rendimiento, consumo, temperatura, firma o instalación de la app nativa.

Una exportación iOS firmada todavía requiere una Mac con Xcode, la cuenta de Apple y el dispositivo emparejado. El entorno Linux cloud no tiene acceso a la Mac de David. La publicación automática descrita aquí corresponde a la Web; no publica en TestFlight ni en App Store.
