# Login móvil y autenticación end-to-end

> Registro histórico: la instalación vigente está en [README](../README.md) y en `database/PostgreSQL/v1/BD_COMPLETA.sql`. Los instaladores y migraciones anteriores se conservan en Git; no seguir sus instrucciones como instalación actual.

## Alcance y flujo

Se implementó login Flutter mediante la API existente. Antes de modificar Flutter se ejecutaron desde Swagger las pruebas correctas: login 200, contraseña incorrecta 401, campos vacíos 400 y /me con JWT 200. No hubo errores que justificaran modificar API o base de datos.

VistaLogin → ControladorLogin → ServicioAutenticacion → IConexionApi → Conexion → ClienteApi → API → acceso existente a PostgreSQL.

Los modelos Usuario (id, username, name), SesionUsuario (token, user) y ResultadoAutenticacion (sesión o mensaje) evitan distribuir mapas dinámicos en la presentación. ServicioAutenticacion transforma el JSON y utiliza EstadoApi para 200/400/401/500/503 y fallos sin statusCode. JSON inválido y excepciones producen mensajes controlados de TextosApp sin mostrar datos técnicos.

ServicioSesion conserva usuario/JWT únicamente en memoria. ControladorLogin valida campos, bloquea peticiones simultáneas, coordina carga/error y sustituye el historial al autenticar. Libera TextEditingController en onClose. ControladorInicio limpia la sesión y sustituye el historial al salir. VistaLogin contiene contraseña oculta, formulario inicialmente vacío, progreso y mensajes; VistaInicio solo muestra bienvenida, nombre y logout.

Rutas.login (/login) es inicial; Rutas.inicio (/inicio) demuestra el éxito. DependenciasApp registra IConexionApi, ServicioAutenticacion, ServicioSesion y ambos controllers. La sesión es permanente dentro del proceso; GetX libera/recrea controllers y sus campos por navegación. No hay persistencia, refresh token ni autenticación offline.

## Validaciones ejecutadas

| Validación | Resultado |
|---|---|
| Swagger login correcto | 200, JWT e identidad pública |
| Swagger contraseña incorrecta | 401 |
| Swagger campos vacíos | 400 |
| Swagger /me con JWT | 200, identidad pública |
| dotnet build | 0 errores y 0 advertencias |
| GET /api/health/database | 200, connected |
| flutter analyze | Sin incidencias |
| flutter test | 25 aprobadas; 2 reales opt-in omitidas por defecto |
| Prueba opt-in autenticación real y /me | Aprobada contra API y PostgreSQL |
| Integración Android física | Login, identidad, historial y logout aprobados |
| flutter build apk --debug con API_BASE_URL local por USB | APK generado correctamente, sin credenciales de prueba |

La integración real obtuvo credenciales exclusivamente de DATOS_PRUEBA.md mediante parámetros externos; no hay credenciales demo en lib, test, integration_test ni test_driver. El JWT no se imprime ni se guarda. Las capturas públicas se guardaron en mobile/build/pruebas-integracion (ignorado por Git). Se inspeccionó visualmente la bienvenida con el nombre del técnico.

El usuario pidió usar su dispositivo físico para conservar recursos del equipo. Se comprobó que no había procesos de emulador activos y se utilizó adb reverse tcp:5263 tcp:5263, con API_BASE_URL=http://127.0.0.1:5263. No se continuó con emuladores. El APK normal se generó sin credenciales compiladas. El primer intento de instalación fue rechazado por el teléfono; tras la autorización del usuario, el segundo intento se instaló correctamente y se abrió la app normal para pruebas manuales.

## Archivos

Creados:

- mobile/lib/models/usuario.dart, sesion_usuario.dart, resultado_autenticacion.dart.
- mobile/lib/services/servicio_autenticacion.dart, servicio_sesion.dart.
- mobile/lib/controllers/controlador_login.dart, controlador_inicio.dart.
- mobile/lib/views/vista_login.dart, vista_inicio.dart.
- mobile/test/auth/conexion_simulada.dart, servicio_autenticacion_test.dart, controlador_login_test.dart, autenticacion_real_test.dart.
- mobile/integration_test/login_real_test.dart y mobile/test_driver/prueba_autenticacion.dart.
- docs/autenticacion.md.

Modificados:

- mobile/lib/main.dart; app/bindings/dependencias_app.dart; app/routes/rutas.dart y paginas_app.dart.
- app/constants/textos_app.dart; app/theme/colores_app.dart y fuentes_app.dart.
- mobile/test/vista_inicial_test.dart; mobile/pubspec.yaml y pubspec.lock.
- README.md y .gitignore (excluir caché generado .kotlin).

Eliminado: mobile/lib/views/vista_inicial.dart, sustituido por el formulario de login. API y database/ permanecen sin cambios.

## Pruebas, documentación y versionado

El fake de IConexionApi prueba sesión válida, status controlados, comunicación y JSON inesperado. Las pruebas del controller verifican campos vacíos, contraseña oculta, credenciales incorrectas, carga, bloqueo de duplicados, navegación sin retorno y limpieza de sesión/campos. integration_test es una dependencia de desarrollo incluida en el SDK, sin nueva dependencia de ejecución.

Documentación del código: revisada. El código propio utiliza comentarios /// en español sobre qué hace, cómo y por qué. README describe configuración, carga manual, URL para USB, pruebas y sesión en memoria.

Antes de los commits se revisan diff, staged/status y la ausencia de valores privados locales en archivos candidatos y objetos de Git. Los cambios se separan en implementación, pruebas y documentación, y se publican en main. Los hashes y la comprobación final local/remoto se informan al cerrar la etapa.

No hubo problemas funcionales pendientes. Se corrigieron detalles de compilación de tests durante desarrollo y una ruta de lectura de la credencial externa antes de ejecutar la integración correcta. Android emitió advertencias de rendimiento/teclado de la ejecución debug, sin fallos en las pruebas. La instalación adicional del APK normal se completó después de autorizarla en el teléfono.

No se requieren decisiones de arquitectura para cerrar esta etapa. Tickets, SQLite, sincronización, fotografías y persistencia del token quedan pendientes de instrucciones posteriores.
