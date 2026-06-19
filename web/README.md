# Project-Cronia

App Flutter para organizar el tiempo usando Gemini como asistente de planificación.

## Estado actual

Esta versión incluye una base funcional con:

- Onboarding inicial.
- Nombre de usuario.
- API key de Gemini guardada en almacenamiento seguro.
- Pantalla principal de actividades.
- Calendario con colores por prioridad.
- Planificación con Gemini mediante JSON estructurado.
- Vista previa antes de aplicar cambios.
- Guardado local con `SharedPreferences` en formato JSON.
- Exportación/importación de respaldo JSON desde la pantalla de configuración.
- Notificaciones locales preparadas para recordatorios.

## Pendiente recomendado

- Migrar almacenamiento local a Drift/SQLite.
- Crear pantalla completa de edición de actividades.
- Agregar configuración visual de comidas y cocina.
- Agregar configuración personalizada de recordatorios por días, horas y minutos.
- Agregar cronómetro visual avanzado.
- Agregar acciones desde la notificación.
- Agregar foto de perfil con `image_picker`.

## Ejecutar

```bash
flutter pub get
flutter run
```

## Nota sobre Gemini

La app usa la API key que ingresa el usuario en el onboarding. Esa clave no se exporta en los respaldos JSON.
