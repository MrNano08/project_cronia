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
