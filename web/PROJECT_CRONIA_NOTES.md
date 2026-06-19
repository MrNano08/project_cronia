# Cambios aplicados

Se modificó el proyecto para dejar una base funcional de Project-Cronia.

## Archivos principales modificados o creados

- `pubspec.yaml`: dependencias principales agregadas.
- `lib/main.dart`: inicialización de SharedPreferences, Riverpod y notificaciones.
- `lib/app.dart`: rutas principales con GoRouter y tema visual.
- `lib/src/models.dart`: modelos de usuario, tareas, prioridades, estados, recordatorios, comidas y planificación.
- `lib/src/providers.dart`: controladores y providers principales.
- `lib/src/services/*`: almacenamiento seguro, repositorio local, notificaciones y Gemini.
- `lib/src/screens/*`: onboarding, inicio, calendario, planificación y configuración.
- `android/app/src/main/AndroidManifest.xml`: permisos de notificación.
- `android/app/build.gradle.kts`: desugaring necesario para programación de notificaciones.
- `test/widget_test.dart`: prueba base actualizada.

## Pendiente recomendado

- Ejecutar `flutter pub get`.
- Ejecutar `flutter analyze`.
- Ejecutar `flutter run`.
- Probar Gemini con una API key válida.
- En una siguiente fase, migrar de SharedPreferences a Drift/SQLite.

## Actualización manual/edit
- El botón + en la pantalla IA ahora abre el formulario manual y copia el texto escrito como título inicial.
- Agregada pantalla para crear y editar actividades manualmente.
- La actividad se puede editar desde Inicio y Calendario.
- El formulario permite configurar título, descripción, fecha, hora, duración, prioridad, estado, flexibilidad y recordatorios por días/horas/minutos antes.
- Al editar una actividad se reprograman sus notificaciones y se cancelan las anteriores para evitar duplicados.


## Actualización: icono y overflow en ajustes

- Se corrigió el overflow amarillo/negro en la pantalla de Configuración.
- El selector de zona horaria ahora usa `isExpanded: true` y texto con `ellipsis`.
- Las filas de sueño y comida ahora cambian a diseño vertical si no hay espacio suficiente.
- Se agregó `flutter_launcher_icons` como dependencia de desarrollo para poder cambiar el icono.

Para cambiar el icono:

1. Coloca tu imagen en `assets/icon/app_icon.png`. Debe ser PNG cuadrado, preferiblemente 1024x1024 px.
2. Agrega esto al final de `pubspec.yaml` si aún no está configurado:

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/app_icon.png"
  min_sdk_android: 21
```

3. Ejecuta:

```bash
dart run flutter_launcher_icons
flutter clean
flutter pub get
flutter run
```
