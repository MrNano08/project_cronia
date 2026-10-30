# Project Cronia

**Organiza actividades, planifica con Gemini y gestiona tareas recurrentes desde una aplicación Flutter.**

Project Cronia es una aplicación personal de productividad desarrollada con **Flutter y Dart**. Combina un calendario de actividades, recordatorios locales, planificación asistida por Gemini y un sistema de repeticiones calculadas en el dispositivo. Los datos de tareas y preferencias se guardan localmente; no requiere un backend propio.

> **Estado:** proyecto personal en desarrollo. Este README describe el código incluido en la actualización de octubre de 2026. La ejecución integral, la comunicación con Gemini y el APK de distribución deben comprobarse en un dispositivo antes de considerarlos validados.

## Funcionalidades

### Actividades y calendario

- Crear y editar actividades con título, descripción, fecha, hora, duración y prioridad.
- Gestionar estados de las actividades y consultar la agenda desde Inicio y Calendario.
- Organizar la información mediante un calendario mensual y colores por prioridad.
- Configurar recordatorios locales para el inicio, finalización o momentos previos a una actividad.
- Personalizar horarios de descanso, comidas y otros parámetros de la planificación.

### Tareas recurrentes

La repetición se configura desde el formulario de actividad. Las reglas se guardan como parte de la tarea original; **las fechas se calculan localmente**, sin solicitar a Gemini una respuesta por cada ocurrencia.

| Modalidad | Opciones disponibles |
| --- | --- |
| Diaria | Todos los días o cada N días |
| Laborable | De lunes a viernes |
| Semanal | Días de la semana seleccionados y cada N semanas |
| Mensual | Día del mes o posición del día de semana; cada N meses |
| Anual | Repetición por año |

Cada serie puede finalizar nunca, en una fecha determinada o después de un número establecido de ocurrencias. El formulario muestra una vista previa de las próximas cinco fechas.

Al editar, cancelar o eliminar una actividad recurrente, se puede elegir **solo esta ocurrencia**, **esta y las siguientes** o **toda la serie**. Los cambios particulares y las fechas completadas se guardan como excepciones; no se duplican permanentemente todas las tareas futuras.

Ejemplo: «Estudiar inglés todos los lunes, miércoles y viernes a las 19:00» se representa mediante **una actividad y una regla semanal**.

### Planificación con Gemini

- Escribir instrucciones en lenguaje natural y solicitar una propuesta de planificación.
- Obtener varias actividades en una respuesta estructurada, con un máximo implementado de **30 tareas por propuesta**.
- Solicitar reglas compactas de repetición sin generar todas las fechas mediante IA.
- Revisar y editar títulos, fechas y horas antes de aplicar una propuesta.
- Validar identificadores de tareas, actividades completadas o inmovibles y conflictos horarios antes de guardar los cambios.
- Gestionar respuestas inválidas, límites de salida y errores HTTP, incluyendo los relacionados con cuotas.
- Consultar modelos disponibles con `generateContent` desde Ajustes y configurar el identificador del modelo. El valor predeterminado en el código revisado es `gemini-2.5-flash`.

**Importante:** la generación asistida requiere conexión a Internet, una API key personal de Gemini y disponibilidad de cuota. Las tareas manuales, la consulta del calendario y las repeticiones se procesan localmente una vez configurada la aplicación.

### Persistencia, respaldo y notificaciones

- Las tareas, series recurrentes, excepciones y preferencias se guardan como JSON en `SharedPreferences`.
- La API key se almacena por separado con `flutter_secure_storage` y **no se incluye en los respaldos JSON**.
- La opción de exportación genera texto JSON para copiar; la importación admite pegar un respaldo. No se implementa una sincronización en la nube.
- Los recordatorios recurrentes se programan en una ventana móvil de aproximadamente **30 días**, con un límite preventivo global de **450 solicitudes pendientes**. La programación se renueva al iniciar o retomar la aplicación, sujeta a permisos y restricciones del sistema operativo.

## Tecnologías

| Área | Tecnología |
| --- | --- |
| Aplicación | Flutter, Dart |
| Estado | Riverpod |
| Navegación | GoRouter |
| Calendario | TableCalendar |
| Almacenamiento local | SharedPreferences |
| Clave de Gemini | Flutter Secure Storage |
| Integración con IA | Gemini API mediante `http` |
| Recordatorios | Flutter Local Notifications |
| Zonas horarias | `timezone`, `flutter_timezone` |
| Fechas y formato | `intl` |
| Identificadores | `uuid` |

Consulta `pubspec.yaml` para las restricciones de versiones. El proyecto actualmente requiere **Dart SDK `^3.12.2`**.

## Organización del código

```text
lib/
├── main.dart                   # Inicialización, preferencias y notificaciones
├── app.dart                    # Navegación y tema
└── src/
    ├── models.dart            # Modelos de actividades y planificación
    ├── recurrence.dart        # Reglas y cálculo de ocurrencias
    ├── providers.dart         # Estado y acciones de tareas
    ├── screens/               # Inicio, calendario, Gemini, formulario y ajustes
    ├── services/
    │   ├── gemini_service.dart
    │   ├── local_repository.dart
    │   ├── notification_service.dart
    │   └── secure_storage_service.dart
    ├── theme/
    └── widgets/

test/
├── recurrence_test.dart
├── recurrence_management_test.dart
├── gemini_service_test.dart
└── widget_test.dart

android/                       # Proyecto Android y configuración de firma
assets/icon/                   # Icono de la aplicación
```

El repositorio también contiene carpetas `lib/core/` y `lib/features/` que **no corresponden al flujo principal conectado desde `lib/app.dart`**. No se deben interpretar automáticamente como funcionalidades de producción.

## Instalación y uso

### Requisitos

- Flutter SDK con una versión de Dart compatible con `^3.12.2`.
- Herramientas Android y un dispositivo o emulador, si vas a ejecutar la versión Android.
- API key de Gemini para completar el onboarding actual y utilizar las funciones de IA.

> **Limitación actual:** aunque el cálculo de las recurrencias no utiliza Gemini, el formulario inicial todavía exige introducir una API key para finalizar la configuración de usuario. No se ofrece por ahora un onboarding totalmente independiente de Gemini.

### Ejecutar el proyecto

```bash
git clone https://github.com/MrNano08/project_cronia.git
cd project_cronia
flutter doctor
flutter pub get
flutter run
```

Al iniciar por primera vez, completa el perfil y la configuración inicial. Después puedes crear tareas manualmente desde el formulario o generar propuestas desde la pantalla de planificación.

### Comprobaciones para desarrollo

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

Estas son instrucciones para **ejecutar** las comprobaciones, no una afirmación de que ya hayan pasado en la versión publicada. Los archivos `test/` incluyen casos de recurrencias, cambios por ocurrencia, respuestas de Gemini simuladas y una prueba de interfaz. Las pruebas de Gemini utilizan clientes HTTP de prueba; no validan por sí mismas la disponibilidad actual del servicio real.

## Crear una versión Android

Para una compilación de prueba:

```bash
flutter build apk --debug
```

Para una compilación `release`:

```bash
flutter build apk --release
```

El archivo APK suele generarse en `build/app/outputs/flutter-apk/`.

**Firma:** el `android/app/build.gradle.kts` revisado utiliza la clave local de **debug** como alternativa cuando no existe `android/key.properties`. Esto permite generar un APK instalable para pruebas, pero **no equivale a una firma de distribución profesional**.

Para distribuir actualizaciones utiliza una keystore propia y configura `android/key.properties` con `storeFile`, `storePassword`, `keyAlias` y `keyPassword`. No subas la keystore ni las contraseñas al repositorio. Una actualización Android debe estar firmada con la misma clave que la instalación anterior; si cambias de clave, respalda tus datos antes de modificar o reinstalar la aplicación.

Comprueba la firma del APK antes de compartirlo:

```bash
apksigner verify --verbose build/app/outputs/flutter-apk/app-release.apk
```

## Limitaciones conocidas

- La aplicación se mantiene como proyecto personal; no se ha verificado aquí su comportamiento completo en dispositivos físicos.
- Gemini puede rechazar solicitudes por cuota, restricciones de modelo, disponibilidad o formato de respuesta. Admitir varias actividades en una respuesta no garantiza que todas las solicitudes sean aceptadas por la API.
- Las notificaciones dependen de permisos y políticas del sistema operativo; la programación en Android usa un modo inexacto.
- `SharedPreferences` ofrece almacenamiento local, pero no sustituye una base de datos con sincronización entre dispositivos.
- El onboarding exige actualmente una API key, aunque las actividades manuales y las recurrencias puedan funcionar sin conexión después de configurarse.
- El proyecto conserva plataformas generadas por Flutter; su presencia no demuestra que todas hayan sido probadas.

## Autoría

Proyecto personal desarrollado y mantenido por [MrNano08](https://github.com/MrNano08).
