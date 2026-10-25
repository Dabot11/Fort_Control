# Exportación móvil y firma local

El usuario confirmó una partida completa del MVP base `82365e0` en **iPhone 16 Pro, iOS 27.0.1**, usando **Godot 4.7.2 y Xcode 27**. Esta guía recoge ese recorrido. El entorno cloud sigue utilizando **Godot 4.6.3**; sus pruebas no sustituyen las del teléfono. La nueva iteración de sonido, efectos y balance necesita otra exportación y prueba física.

La regla para exportar es usar **plantillas de la misma versión exacta que tu editor**, no necesariamente la versión de cloud. Si tu proyecto ya exporta con Godot 4.7.2, conserva ese editor y sus plantillas 4.7.2.

## Preparación común

1. Abre el proyecto en el editor y ejecuta una partida en escritorio.
2. Ejecuta `bash scripts/run_tests.sh` desde la raíz.
3. En **Editor → Administrar plantillas de exportación**, instala las plantillas de la versión exacta de tu editor.
4. Conserva Mobile como renderizador inicial y orientación **Portrait** en los ajustes de pantalla. Si necesitas evaluar Compatibility, repite las pruebas en un preset o copia local apropiada; no asumas idéntico rendimiento.
5. Abre **Proyecto → Exportar**. El repositorio incluye presets de preparación **macOS**, **Android** e **iOS** en `export_presets.cfg`. En la pestaña **Resources** ya tienen **Export all resources in the project** y `*.json` en **Filters to export non-resource files/folders**. Conserva ese filtro: los JSON contienen mapa, balance y oleadas; sin ellos el juego exportado no podrá inicializarse.
6. Exporta dentro de `build/`, que está ignorado por Git.

Los identificadores de aplicación y el Team ID del repositorio están vacíos intencionalmente. Cada desarrollador debe conservar su configuración local de equipo, identidad y destino. Nunca incluyas certificados, contraseñas, keystores ni perfiles de aprovisionamiento en el repositorio público. El proyecto Xcode generado tampoco debe publicarse con datos personales de firma.

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

La exportación iOS se realiza desde **macOS con Xcode instalado**. Xcode y su SDK deben admitir la versión de iOS del dispositivo. Para probar en **tu propio iPhone** puedes usar una cuenta Apple gratuita mediante **Personal Team**; la membresía pagada se necesita para otras formas de distribución, como App Store o TestFlight.

### Preparar la cuenta y obtener el Team ID

1. Instala y abre Xcode. Acepta sus condiciones e instala los componentes solicitados.
2. En **Xcode → Settings → Accounts**, añade tu cuenta Apple. No necesitas contratar una membresía para esta prueba personal.
3. Si aún no conoces tu Team ID, crea temporalmente una aplicación **iOS → App** en Xcode. Selecciona su target y abre **Signing & Capabilities**. Activa **Automatically manage signing** y elige tu **Personal Team**. Guarda el proyecto.
4. En Finder, haz clic derecho sobre el archivo `.xcodeproj` temporal y selecciona **Show Package Contents / Mostrar contenido del paquete**. Abre `project.pbxproj` con un editor de texto y busca `DEVELOPMENT_TEAM`. El valor asignado es el Team ID real que necesitas en Godot; copia únicamente ese identificador a tu configuración local. No es el nombre de la persona ni el correo de la cuenta.
5. Conecta el iPhone, acepta **Confiar en este ordenador** y activa **Developer Mode** si iOS lo solicita. Xcode puede pedir preparar el dispositivo antes de permitir Run.

La instalación con Personal Team gratuito normalmente vence a los **siete días**; vuelve a compilar e instalar desde Xcode para renovarla. Este flujo permite pruebas en tus propios dispositivos.

### Preparar Godot

1. Comprueba la versión del editor e instala sus plantillas exactas. En la configuración ya utilizada por el usuario, ambos son **4.7.2**.
2. Si el exportador indica que faltan texturas **ETC2/ASTC**, abre **Project → Project Settings**, activa ajustes avanzados si es necesario y busca **Import ETC2 ASTC**. Habilita `rendering/textures/vram_compression/import_etc2_astc` y deja que Godot reimporte los recursos. Reinicia el editor si lo solicita.
3. En **Project → Export**, selecciona **iOS**. En **Application**, introduce tu **App Store Team ID** y un **Bundle Identifier** propio y único. No uses el nombre visible de Personal Team como Team ID.
4. Activa **Application → Export Project Only**. Godot generará el proyecto para que Xcode lo compile y firme; no intentes producir un IPA de distribución desde Godot para esta prueba con Personal Team.
5. Selecciona iPhone/iPad según corresponda, conserva **Portrait** y mantén `*.json` en el filtro de **Resources**. No añadas capacidades de servicios que el juego no utiliza.
6. Exporta a `build/ios/`. Si la salida es `.zip`, descomprímela en una carpeta nueva. Abre el archivo **`.xcodeproj`** generado.

### Compilar e instalar desde Xcode

1. Selecciona el target del juego. En **Signing & Capabilities**, activa **Automatically manage signing** y elige tu **Personal Team**.
2. En **Build Settings**, busca **Code Signing Identity**. Para este recorrido de desarrollo usa **Apple Development** tanto en **Debug** como en **Release**; no selecciones una identidad de distribución. Deja que Xcode gestione el perfil compatible con tu cuenta.
3. En el selector de destino junto a Run, elige **el iPhone físico conectado**, no un simulador. El flujo comprobado utiliza un dispositivo real.
4. Pulsa **Run**. Si iOS pide confiar en el desarrollador o activar Developer Mode, completa la instrucción del sistema para tu cuenta y vuelve a ejecutar.
5. Completa las cinco oleadas y registra los resultados de `docs/validation.md`. Comprueba de nuevo los cambios de cada versión aunque una compilación anterior ya haya funcionado.

Si aparece **Undefined symbol: _main** al intentar usar un simulador, comprueba primero el destino seleccionado y la correspondencia de plantillas/editor. En el recorrido documentado se utilizó el iPhone físico. No borres scripts ni cambies las bibliotecas del motor para intentar corregir ese mensaje; si persiste con el destino correcto, revisa el error de enlace completo en Xcode.

Si Godot no encuentra el SDK de iPhone, revisa `xcode-select -p`: debe apuntar al Xcode completo que instalaste, no únicamente a Command Line Tools. Selecciona la instalación correcta en **Xcode → Settings → Locations → Command Line Tools**.

Referencia: [Exporting for iOS, documentación Godot 4.6](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_ios.html).

## Actualizar sin perder la configuración que ya funciona

Los ajustes de textura pueden modificar `project.godot`; los datos de exportación y firma pueden modificar `export_presets.cfg`. Revisa `git status --short` y actualiza con `git pull --ff-only origin main`, conservando tus ajustes locales.

Esta iteración no modifica esos dos archivos. Si una actualización futura genera conflicto, compara y conserva los valores locales de firma y exportación. Genera después un proyecto Xcode nuevo desde Godot; una exportación anterior no se actualiza sola.

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
3. Instala las plantillas de la misma versión de tu editor y selecciona el preset **Android** incluido en **Proyecto → Exportar**. Los valores de SDK de la tabla corresponden a 4.6; consulta los requisitos de tu versión si cambias el motor.
4. Selecciona un identificador de paquete propio, arquitectura **arm64-v8a** para dispositivos modernos y orientación vertical. No añadas el permiso **Internet**: el juego es local.
5. En el teléfono activa opciones de desarrollador y **Depuración USB**. Conéctalo y acepta la autorización del ordenador.
6. Exporta un **APK de depuración** a `build/android/`. Puedes instalarlo con Godot o con `adb install -r build/android/fort-control.apk`, usando el nombre que hayas elegido al exportar.
7. Comprueba una partida completa en el dispositivo, incluyendo pausa, reanudación, pellizco y todos los botones.

Para distribución posterior, prepara un **AAB firmado** con tu propia identidad. Guarda la keystore fuera del checkout y administra sus contraseñas mediante mecanismos locales seguros. Esta entrega no crea ni necesita una cuenta de Google Play.

Referencia: [Exporting for Android, documentación Godot 4.6](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html). Si actualizas el motor, revisa también los requisitos del SDK y descarga plantillas de la nueva versión.
