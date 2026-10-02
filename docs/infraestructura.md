Nota: documento histórico. La nomenclatura y separación SQL actuales están en modularizacion.md.

> Registro histórico: la instalación vigente está en [README](../README.md) y en `database/PostgreSQL/v1/BD_COMPLETA.sql`. Los instaladores y migraciones anteriores se conservan en Git; no seguir sus instrucciones como instalación actual.

Nota: reporte histórico de una etapa anterior. Los nombres actuales y la configuración segura están en conexion-global.md.

# Infraestructura reutilizable antes de funcionalidades

## Estructura Flutter

```text
mobile/lib/app/
  constants/app_texts.dart
  network/
    api_client.dart
    api_config.dart
    api_response.dart
    api_routes.dart
    api_status.dart
  routes/
    app_routes.dart
    app_pages.dart
  theme/
    app_colors.dart
    app_fonts.dart
  database/                 # sin implementación
```

Una clase propia por archivo. No se incorporaron controllers o servicios Flutter de negocio, capas de arquitectura adicionales ni rutas de pantallas futuras.

## Endpoints API

| Clase y ubicación | Contrato conservado | Dependencia |
| --- | --- | --- |
| Controllers/Auth/LoginController.cs | POST /api/auth/login, anónimo | AuthService compartido |
| Controllers/Auth/MeController.cs | GET /api/auth/me, JWT | Claims del middleware |
| Controllers/Health/DatabaseHealthController.cs | GET /api/health/database, anónimo | IDatabaseHealthService |

Se retiró AuthController y se trasladó HealthController al archivo/clase de su endpoint. No se duplicaron servicios, hashing, emisión JWT, configuración ni acceso a datos. Las URLs y respuestas se mantuvieron; Swagger ahora agrupa por los nombres específicos de Controllers. No hay Controllers de tickets ni endpoints nuevos.

## ApiClient y respuestas

ApiClient es una implementación HTTP reutilizable e instanciable; utiliza http.Client inyectable para pruebas. No se crea un singleton global oculto ni se guarda estado de autenticación. GET, POST, PUT, PATCH y DELETE delegan en un único método privado de transporte/procesamiento.

- El consumidor selecciona una ruta de ApiRoutes y un método HTTP, construye el payload y proporciona token opcional.
- El cliente resuelve la URL, envía Accept JSON y agrega Authorization Bearer solo para tokens no vacíos.
- El payload presente se serializa con jsonEncode y Content-Type JSON UTF-8. DELETE no tiene cuerpo en este contrato inicial.
- El timeout central de 15 segundos cubre envío y lectura del cuerpo. Limita la espera del consumidor, sin cancelar automáticamente la operación subyacente ni implementar reintentos.
- ApiClient.close libera el transporte, incluso si fue inyectado; debe llamarse cuando ya no se usará la instancia.

ApiResponse contiene statusCode nullable, data como Object? JSON, message nullable y success. No se acopla a Login o Tickets. Un statusCode null expresa que no hubo respuesta HTTP y evita inventar códigos para errores de red.

ApiStatus centraliza 200, 201, 204, 400, 401, 403, 404, 409, 500 y 503, y clasifica el rango 2xx. Un cuerpo vacío se admite; una respuesta no JSON produce success false y un mensaje explícito incluso si su código es 200. Los errores JSON mantienen código y datos, usando message/title si están disponibles. Timeout, transporte inaccesible y fallos inesperados reciben mensajes controlados sin exponer excepciones.

ApiRoutes registra solamente healthDatabase, login y me, que ya existen en la API. Declarar esas constantes no implementa pantallas o acciones Flutter de autenticación.

## Configuración y presentación mínima

ApiConfig es un archivo adicional justificado por su responsabilidad: centralizar base URL y timeout, separados de los nombres de endpoints. API_BASE_URL se configura con --dart-define; no existe un sistema adicional de environments.

El valor predeterminado es http://10.0.2.2:5263 para Android Emulator. Windows/local usa --dart-define=API_BASE_URL=http://localhost:5263. Un dispositivo físico necesita una URL alcanzable de la API desde su red; no se habilitó acceso por LAN ni se probó físicamente.

La app Android tiene permiso INTERNET. Solo debug permite HTTP local mediante usesCleartextTraffic; no se debilitó la configuración release. El permiso y excepción de desarrollo son infraestructura para el cliente existente, no una funcionalidad de conectividad ni una pantalla de prueba.

Routes/AppPages siguen siendo la única configuración GetX, con la ruta inicial. AppTexts contiene el nombre actual y mensajes de infraestructura realmente usados. AppColors centraliza fondo/texto de la vista inicial y AppFonts.body su tamaño, peso y color, sin fuente externa ni sistema visual adicional. main.dart utiliza AppTexts y AppPages; InitialView reutiliza los estilos.

Dependencia directa agregada: http ^1.6.0. http_parser y typed_data son dependencias transitivas. No se añadió Dio ni un paquete de mocks: MockClient está incluido en http.

## Validación

| Comprobación | Resultado |
| --- | --- |
| flutter pub get | Correcto |
| flutter analyze | Sin problemas |
| flutter test | 13 pruebas aprobadas; prueba externa omitida por defecto |
| Prueba real opt-in de ApiClient | 1 prueba aprobada; GET health devuelve 200 y JSON connected |
| flutter build apk --debug | APK generado correctamente |
| dotnet build | 0 errores, 0 advertencias |
| Swagger en navegador | Carga los tres Controllers reorganizados |
| Health ejecutado en Swagger sin JWT | 200, status ok y database connected |
| /api/auth/me sin JWT | 401 |
| /api/auth/login sin campos | 400 |
| DATABASE.md | Hash SHA-256 sin cambios |

Los tests con MockClient verifican los cinco verbos, Bearer opcional, omisión de token vacío, JSON UTF-8, códigos 201/204, ProblemDetails 401, error 503, contenido no JSON, timeout, API inaccesible y error inesperado. Además permanece la prueba de ruta/vista inicial. No dependen de datos demo.

La prueba real solo hace GET contra health. Se mantiene en test/network/api_client_live_test.dart y se activa con:

```sh
flutter test test/network/api_client_live_test.dart --dart-define=RUN_API_TEST=true --dart-define=API_BASE_URL=http://localhost:5263
```

No hay código temporal de pruebas en producción. No se ejecutaron scripts, cambios de esquema, inserciones ni seeds. No se implementaron Login Flutter, persistencia de token, Tickets, SQLite, Connectivity, fotografías ni sincronización.

## Archivos

Creados:

```text
api/Controllers/Auth/LoginController.cs
api/Controllers/Auth/MeController.cs
api/Controllers/Health/DatabaseHealthController.cs (trasladado/renombrado)
mobile/lib/app/network/api_client.dart
mobile/lib/app/network/api_config.dart
mobile/lib/app/network/api_response.dart
mobile/lib/app/network/api_routes.dart
mobile/lib/app/network/api_status.dart
mobile/lib/app/constants/app_texts.dart
mobile/lib/app/theme/app_colors.dart
mobile/lib/app/theme/app_fonts.dart
mobile/test/network/api_client_test.dart
mobile/test/network/api_client_live_test.dart
docs/infraestructura.md
```

Modificados: mobile/lib/main.dart, mobile/lib/views/initial_view.dart, mobile/test/widget_test.dart, mobile/pubspec.yaml, mobile/pubspec.lock, manifiestos Android main/debug, README.md y docs/linea-base.md. Los Controllers originales fueron retirados/trasladados; su lógica se conservó en los nuevos archivos.

## Documentación del código: revisada

Se revisó el código propio existente y se documentaron en español todas las clases y métodos nuevos, incluidos constructor, transporte privado, interpretación de respuestas y liberación de recursos. C# utiliza XML y Dart /// con intención, funcionamiento y justificación. Las lambdas breves de factories/tests se explican en su contexto. El código nativo y boilerplate generado por las plantillas no se comentó de nuevo.

## Problemas y decisiones

No se encontraron errores de compilación, análisis o pruebas. Pub informa versiones más recientes de algunas dependencias transitivas fuera de sus constraints; no se actualizaron paquetes ajenos a esta etapa porque las validaciones pasaron.

Decisiones rutinarias: ApiClient como instancia reutilizable con transporte inyectable; ApiConfig separado; statusCode null para errores de transporte; prueba externa opt-in; HTTP local únicamente en debug. No hay decisiones pendientes de aprobación.

No se realizó una prueba en Android Emulator o dispositivo físico; se compiló el APK y el GET real se verificó desde el runner Flutter en el equipo. Para la configuración Android se consultaron las fuentes oficiales enlazadas en README.

La etapa termina aquí, antes de implementar Login Flutter u otras funcionalidades.
