# Project Cronia

**Planificador personal de actividades con asistencia de Gemini, calendario y recordatorios locales.**

Project Cronia es una aplicación desarrollada con **Flutter y Dart** para organizar tareas, establecer prioridades y construir una agenda a partir de instrucciones en lenguaje natural. Permite crear actividades manualmente o solicitar una propuesta de planificación a Gemini, revisarla y decidir cuándo aplicarla.

> **Estado:** proyecto en desarrollo. El código contiene un flujo funcional de interfaz, almacenamiento local y conexión a la API de Gemini, pero la ejecución completa en Android/iOS y la integración con Gemini deben verificarse en un entorno Flutter configurado. No es una aplicación publicada ni certificada para producción.

## Características

- **Gestión de actividades:** crear, editar, iniciar, completar y cancelar tareas con fecha, hora de inicio, duración, descripción, prioridad y estado.
- **Planificación asistida por IA:** enviar instrucciones escritas a Gemini para obtener una propuesta de actividades con horarios, acciones sugeridas y advertencias. El resultado se muestra antes de aplicarlo.
- **Calendario mensual:** consultar las actividades de cada día y acceder a su edición; los indicadores visuales reflejan prioridades.
- **Recordatorios locales:** programar avisos antes del inicio, al comenzar y al finalizar una actividad, sujetos a los permisos y restricciones del sistema operativo.
- **Rutina personalizable:** configurar país, zona horaria, hora de levantarse, hora de dormir y bloques de comida, incluido el tiempo de preparación.
- **Persistencia local:** guardar perfil, configuración, actividades y horarios de comida en el dispositivo.
- **Respaldo JSON:** copiar los datos exportados al portapapeles e importarlos pegando el JSON en la aplicación. La clave de Gemini no forma parte de la exportación.
- **Interfaz Material:** navegación entre Inicio, Calendario, Planificación y Configuración, con componentes y estilos personalizados.

### Cómo funciona la planificación

1. Configura tu perfil y proporciona **tu propia clave de API de Gemini**.
2. Escribe una instrucción, por ejemplo: «Organiza mis tareas de mañana, dejando tiempo para almorzar».
3. La aplicación envía a Gemini la solicitud, datos de planificación relevantes, horarios de comida y preferencias de rutina.
4. Revisa el resumen, las actividades propuestas y las advertencias.
5. Pulsa **Aplicar propuesta** para guardar los cambios aceptados. Las solicitudes de eliminación señaladas como `delete_request` se omiten; no eliminan tareas automáticamente.

También es posible crear y editar actividades manualmente, sin recurrir a la generación con IA. El primer registro del perfil, en la implementación actual, sí exige ingresar una clave de Gemini.

## Tecnologías

| Área | Tecnología | Uso |
| --- | --- | --- |
| Aplicación | Flutter / Dart | Interfaz y lógica de aplicación |
| Estado | `flutter_riverpod` | Proveedores y controladores de tareas |
| Rutas | `go_router` | Navegación entre pantallas |
| Persistencia | `shared_preferences` | Perfil, tareas y preferencias en JSON |
| Credenciales | `flutter_secure_storage` | Almacenamiento de la clave de Gemini |
| IA | Gemini API + `http` | Generación de propuestas de planificación |
| Calendario | `table_calendar` | Vista mensual de actividades |
| Recordatorios | `flutter_local_notifications` | Notificaciones locales programadas |
| Fechas | `timezone`, `flutter_timezone`, `intl` | Horarios, zona horaria y presentación |
| Identificadores | `uuid` | IDs de tareas y registros |

El archivo `pubspec.yaml` establece **Dart SDK `^3.12.2`**. Consulta las versiones reales instaladas mediante `flutter --version` y `flutter pub get`.

## Estructura principal

```text
lib/
├── main.dart                       # Inicialización de Flutter, preferencias y notificaciones
├── app.dart                        # Tema y rutas con GoRouter
└── src/                            # Implementación utilizada por la aplicación
    ├── models.dart                 # Tareas, estados, prioridades, recordatorios y planificación
    ├── providers.dart              # Estado y controladores Riverpod
    ├── screens/                    # Onboarding, inicio, calendario, IA, formulario y ajustes
    ├── services/
    │   ├── gemini_service.dart     # Cliente de Gemini y comprobación de respuestas
    │   ├── local_repository.dart   # Persistencia y respaldo JSON
    │   ├── notification_service.dart
    │   └── secure_storage_service.dart
    ├── theme/                      # Tema visual
    └── widgets/                    # Componentes compartidos

assets/icon/                       # Icono de la aplicación
test/widget_test.dart              # Prueba inicial de interfaz
android/, ios/                     # Proyectos de plataforma generados por Flutter
```

> El repositorio también incluye carpetas `lib/core/`, `lib/features/` y una copia de proyecto dentro de `web/`. El punto de entrada actual utiliza **`lib/src/`**; esas otras carpetas no deben interpretarse como módulos de base de datos o funcionalidades terminadas.

## Requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) con una versión de Dart compatible con `^3.12.2`.
- Android SDK, emulador o dispositivo Android para probar la ejecución móvil.
- Una clave personal habilitada para usar la API de Gemini si deseas utilizar el planificador con IA.
- Conexión a Internet para las solicitudes a Gemini; el uso de tareas locales no requiere un servidor propio.

La presencia de proyectos generados para iOS, escritorio y web **no significa que todas esas plataformas hayan sido probadas**. Verifica compatibilidad y permisos en el destino concreto.

## Instalación y ejecución

Clona el repositorio:

```bash
git clone https://github.com/MrNano08/project_cronia.git
cd project_cronia
```

Comprueba el entorno e instala las dependencias:

```bash
flutter doctor
flutter pub get
```

Inicia en un dispositivo o emulador compatible:

```bash
flutter devices
flutter run
```

Al iniciar por primera vez, completa el perfil, selecciona la zona horaria y registra tu clave de Gemini. La clave se introduce en la aplicación; **no la añadas al código fuente, a capturas ni al repositorio**.

### Comprobaciones de desarrollo

```bash
flutter analyze
flutter test
```

El repositorio incluye una prueba de widget para la pantalla de incorporación inicial. Estas órdenes son instrucciones para ejecutarlas localmente: **no se afirma que ya hayan superado una ejecución completa**.

### Construcción de Android

```bash
flutter build apk --release
```

**Importante:** el archivo `android/app/build.gradle.kts` usa actualmente la firma de depuración para la variante release. Configura una firma de publicación propia antes de distribuir una aplicación de producción; un APK generado con la configuración actual no debe presentarse como una entrega firmada para tiendas.

## Datos y privacidad

- La aplicación almacena perfil, tareas y configuración mediante **SharedPreferences**, sin sincronización entre dispositivos ni base de datos remota.
- La **clave de Gemini** se guarda mediante `flutter_secure_storage` y se utiliza para autenticar solicitudes directas desde la aplicación a la API de Google.
- El servicio de IA recibe la instrucción escrita y contexto de planificación: actividades próximas, horarios de comida y preferencias de zona horaria/rutina. Evita introducir datos sensibles que no desees enviar a un proveedor externo.
- Los respaldos JSON pueden contener nombres y actividades personales. No publiques estos respaldos y evita dejarlos en portapapeles compartidos.
- La clave de API no se incluye en el JSON exportado.
- No se ha implementado un backend propio que oculte la clave detrás de un servidor. **No se recomienda desplegar esta versión como aplicación web pública** sin revisar la protección de la clave y el modelo de autenticación.

## Limitaciones conocidas

- El código usa `gemini-3.5-flash` en `lib/src/services/gemini_service.dart`. Según la [documentación oficial de Gemini](https://ai.google.dev/gemini-api/docs/models/gemini-3.5-flash), ese identificador está obsoleto y se redirige a `gemini-3.6-flash`. Conviene actualizarlo a un modelo estable compatible y comprobar sus condiciones de uso.
- La validación de la respuesta de IA comprueba la forma de varios campos, pero no garantiza por sí sola que se respeten todas las restricciones, como tareas inmovibles, solapamientos u horarios de descanso. Revisa las propuestas antes de aplicarlas.
- Las notificaciones dependen de los permisos del dispositivo y utilizan programación no exacta en Android.
- Los datos se guardan en SharedPreferences; no hay cifrado general de actividades, almacenamiento SQL ni sincronización en la nube.
- El respaldo funciona copiando/pegando JSON; no genera ni abre automáticamente un archivo desde un selector.
- Las pruebas automatizadas cubren solo un flujo de incorporación inicial. En la versión revisada, la aserción de `test/widget_test.dart` busca un subtítulo que ya no coincide con `OnboardingScreen`; requiere actualización. Faltan pruebas de integración y validaciones en dispositivos reales.
- La compatibilidad con todas las plataformas generadas por Flutter no está confirmada.

## Estado del proyecto

Project Cronia es un proyecto de aprendizaje y desarrollo móvil orientado a organización personal, interfaces Flutter y consumo de una API de inteligencia artificial. Se publica para mostrar su implementación y facilitar su evolución; no debe considerarse un servicio comercial ni una solución de gestión crítica de agendas.

## Autoría

Desarrollado en el repositorio [MrNano08/project_cronia](https://github.com/MrNano08/project_cronia).

La licencia de reutilización no está definida en este repositorio. Antes de aceptar contribuciones o habilitar reutilización por terceros, añade una licencia apropiada para el proyecto.
