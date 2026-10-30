# Project-Cronia

App Flutter para organizar el tiempo usando Gemini como asistente de planificación.

## Estado actual

La aplicación activa usa `lib/src/`, `lib/app.dart` y `lib/main.dart`. Incluye:

- Onboarding inicial.
- Nombre de usuario.
- API key de Gemini guardada en almacenamiento seguro.
- Pantalla principal de actividades.
- Calendario con colores por prioridad.
- Planificación con Gemini mediante salida JSON estructurada, validación local y vista previa.
- Vista previa antes de aplicar cambios.
- Guardado local con `SharedPreferences` en formato JSON.
- Exportación/importación de respaldo JSON desde la pantalla de configuración.
- Recordatorios locales restaurados al iniciar la aplicación.
- Reglas de repetición diaria, laborable, semanal, mensual y anual, guardadas como una regla compacta en la tarea. Las fechas se calculan localmente, aparecen en el calendario y cada ocurrencia usa una identidad estable basada en serie y fecha.

## Repetición

Al editar o crear una actividad, usa la sección **Repetir**. Las reglas permanecen locales y no requieren conexión ni Gemini. Se puede elegir una fecha final o un número máximo de ocurrencias; la pantalla muestra las próximas cinco fechas. Los recordatorios de una serie se programan en una ventana móvil de 30 días, con un máximo global preventivo de 450 solicitudes pendientes y modo inexacto de Android para respetar las restricciones del sistema. Completar una actividad repetida conserva el historial y excluye solo esa fecha. Desde el formulario se puede editar, cancelar o eliminar solo esa ocurrencia, esa y las siguientes, o toda la serie. Los cambios a futuro dividen la serie y conservan el historial anterior. Las excepciones y los cambios por ocurrencia se exportan e importan con el respaldo JSON.

## Gemini

La API key se conserva en Flutter Secure Storage. En Ajustes se puede indicar el identificador del modelo y consultar los modelos que admiten `generateContent`. La aplicación predetermina `gemini-2.5-flash`; la disponibilidad y las cuotas dependen de la API key y la cuenta de Google. Las respuestas se validan antes de mostrarse o guardarse. No se vuelve a intentar automáticamente ante una cuota diaria agotada.

Las propuestas se guardan en una sola escritura local tras validar IDs existentes, tareas completadas/inmovibles y conflictos de horario. El usuario debe revisar y confirmar antes de guardar.

## Firma Android de distribución

`flutter build apk --release` genera un APK instalable. Si no hay `android/key.properties`, se firma con la clave debug local del equipo; sirve para pruebas en dispositivos, pero no para publicar. Para firmar una versión de distribución, crea `android/key.properties` localmente con `storeFile`, `storePassword`, `keyAlias` y `keyPassword`. Ese archivo y la keystore no deben publicarse. Usa siempre la misma clave para actualizar una instalación existente sin perder los datos.

Para comprobar el APK antes de instalarlo, ejecuta `apksigner verify --verbose build/app/outputs/flutter-apk/app-release.apk`. Si Android rechaza una actualización por firma incompatible, exporta primero un respaldo de la app instalada; no desinstales sin preservar los datos.

## Ejecutar

```bash
flutter pub get
flutter run
```

## Nota sobre Gemini

La app usa la API key que ingresa el usuario en el onboarding. Esa clave no se exporta en los respaldos JSON.
