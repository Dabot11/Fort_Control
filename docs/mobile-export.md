# Exportación móvil para las primeras pruebas

Estas instrucciones preparan una instalación local de desarrollo. No implican que se haya ejecutado una exportación ni probado un dispositivo físico. Usa **Godot 4.6.3 Standard** y plantillas de exportación de la misma versión.

## Preparación común

1. Abre el proyecto en el editor y ejecuta una partida en escritorio.
2. Ejecuta `bash scripts/run_tests.sh` desde la raíz.
3. En **Editor → Administrar plantillas de exportación**, instala las plantillas **4.6.3**.
4. Conserva Mobile como renderizador inicial y orientación **Portrait** en los ajustes de pantalla. Si necesitas evaluar Compatibility, repite las pruebas en un preset o copia local apropiada; no asumas idéntico rendimiento.
5. Abre **Proyecto → Exportar**. El repositorio incluye presets de preparación **macOS**, **Android** e **iOS** en `export_presets.cfg`. En la pestaña **Resources** ya tienen **Export all resources in the project** y `*.json` en **Filters to export non-resource files/folders**. Conserva ese filtro: los JSON contienen mapa, balance y oleadas; sin ellos el juego exportado no podrá inicializarse.
6. Exporta dentro de `build/`, que está ignorado por Git.

Los identificadores de aplicación y el Team ID están vacíos intencionalmente: el editor mostrará los requisitos que debes completar antes de exportar. Cada desarrollador debe seleccionar su equipo, identidad y destino locales. Nunca incluyas certificados, contraseñas, keystores ni perfiles de aprovisionamiento en el repositorio público. La existencia de los presets no implica que una exportación firmada se haya probado.

### Comprobar el empaquetado sin firma

El preset técnico **Validation PCK** empaqueta recursos para verificar que los JSON y escenas llegan al archivo exportado. No crea un instalador ni necesita SDK móvil:

```bash
mkdir -p build/validation
godot --headless --path . --export-pack 'Validation PCK' build/validation/FortControl.pck
godot --headless --main-pack build/validation/FortControl.pck --quit-after 120
```

Para una revisión gráfica del mismo paquete en un equipo con pantalla:

```bash
godot --main-pack build/validation/FortControl.pck --rendering-method gl_compatibility
```

El PCK es un paquete de datos, no una aplicación autónoma. macOS, Android e iOS requieren sus plantillas y pasos de exportación propios.

## iPhone y iPad con Xcode

La exportación iOS se realiza desde **macOS con Xcode instalado**. La versión concreta de Xcode y su SDK debe permitir ejecutar en la versión de iOS de tu dispositivo.

1. Instala Xcode desde Apple. Ábrelo al menos una vez, acepta las condiciones e instala los componentes solicitados.
2. Añade tu Apple ID en los ajustes de cuentas de Xcode. La firma y sus restricciones dependen de tu cuenta y equipo; para distribuir en App Store se necesita la membresía correspondiente.
3. Conecta el iPhone/iPad, acepta **Confiar en este ordenador** y activa **Developer Mode** si iOS lo solicita para la ejecución de desarrollo.
4. En Godot, selecciona el preset **iOS** incluido. En **Application**, introduce tu **App Store Team ID** real y tu **Bundle Identifier** propio. El Team ID es el identificador del equipo, no su nombre visible.
5. Habilita las familias iPhone/iPad que quieras probar y conserva orientación vertical. No actives capacidades de red, compras o servicios que este proyecto no utiliza.
6. Exporta a `build/ios/`. Godot genera un proyecto Xcode; si conservas la salida `.zip` del preset, descomprímela en una carpeta nueva antes de abrir el proyecto.
7. Abre el archivo `.xcodeproj` exportado. En **Signing & Capabilities**, selecciona el equipo correcto y configura firma automática si es adecuada para tu cuenta.
8. Selecciona el dispositivo conectado como destino y pulsa **Run**. Resuelve en Xcode cualquier requisito de perfil o firma que indique para tu cuenta.
9. Juega una partida completa y registra los resultados de la lista de validación. Una ejecución en una Mac Apple Silicon o simulador no sustituye la prueba en iPhone/iPad físico.

Si Godot no encuentra el SDK de iPhone, revisa `xcode-select -p`: debe apuntar al Xcode completo que instalaste, no únicamente a Command Line Tools. Selecciona la instalación correcta en **Xcode → Settings → Locations → Command Line Tools**.

Referencia: [Exporting for iOS, documentación Godot 4.6](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_ios.html).

## Android

La documentación de **Godot 4.6** indica estos prerrequisitos:

| Componente | Versión |
| --- | --- |
| Java | OpenJDK 17 |
| Android Studio | Iguana 2023.2.1 o posterior |
| SDK Platform-Tools | 35.0.0 o posterior |
| SDK Build-Tools | 35.0.1 |
| SDK Platform | Android 35 |
| SDK Command-line Tools | Latest |
| CMake | 3.10.2.4988404 |
| NDK | r28b / 28.1.13356709 |

Los componentes CMake/NDK preparan también la ruta de compilación Android personalizada. Este MVP no necesita plugins ni plantillas de Gradle personalizadas para su primer APK estándar.

1. Instala OpenJDK 17 y Android Studio desde sus fuentes oficiales. Ejecuta Android Studio y abre su **SDK Manager** para instalar los componentes indicados. En **SDK Tools**, usa **Show Package Details** cuando necesites elegir una versión específica.
2. En los ajustes del editor de Godot, busca **Export → Android**. Configura **Java SDK Path** con la instalación de JDK 17 y **Android SDK Path** con la carpeta que contiene `platform-tools/adb`.
3. Instala las plantillas de Godot 4.6.3 y selecciona el preset **Android** incluido en **Proyecto → Exportar**.
4. Selecciona un identificador de paquete propio, arquitectura **arm64-v8a** para dispositivos modernos y orientación vertical. No añadas el permiso **Internet**: el juego es local.
5. En el teléfono activa opciones de desarrollador y **Depuración USB**. Conéctalo y acepta la autorización del ordenador.
6. Exporta un **APK de depuración** a `build/android/`. Puedes instalarlo con Godot o con `adb install -r build/android/fort-control.apk`, usando el nombre que hayas elegido al exportar.
7. Comprueba una partida completa en el dispositivo, incluyendo pausa, reanudación, pellizco y todos los botones.

Para distribución posterior, prepara un **AAB firmado** con tu propia identidad. Guarda la keystore fuera del checkout y administra sus contraseñas mediante mecanismos locales seguros. Esta entrega no crea ni necesita una cuenta de Google Play.

Referencia: [Exporting for Android, documentación Godot 4.6](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html). Si actualizas el motor, revisa también los requisitos del SDK y descarga plantillas de la nueva versión.
