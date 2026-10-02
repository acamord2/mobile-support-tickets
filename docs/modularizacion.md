# Modularización de PostgreSQL y nomenclatura

> Registro histórico: la instalación vigente está en [README](../README.md) y en `database/PostgreSQL/v1/BD_COMPLETA.sql`. Los instaladores y migraciones anteriores se conservan en Git; no seguir sus instrucciones como instalación actual.

## Estructura documental

```text
database/
  DATABASE.md
  DATOS_PRUEBA.md
  FUNCIONES_SP.md
  VISTAS.md
  TRIGGERS.md
```

DATABASE.md conserva CREATE DATABASE, las cuatro tablas, PK/FK, NOT NULL, UNIQUE, CHECK, índices y verificaciones de estructura. No contiene INSERT ni definiciones de funciones, procedimientos, vistas o triggers. Los bloques de creación física se compararon con la versión anterior y son idénticos.

FUNCIONES_SP.md es la única fuente de instalación de public.get_user_by_username. Se trasladó su SQL sin cambiar nombre, parámetros, columnas de retorno o implementación; se corrigió la referencia documental antigua a EF Core por DbCommand. No hay procedimientos almacenados ni funciones nuevas de tickets.

VISTAS.md y TRIGGERS.md explican su finalidad y criterios de uso. Actualmente no contienen objetos requeridos ni SQL que ejecutar.

DATOS_PRUEBA.md contiene exclusivamente instrucciones y DML de demostración: un técnico, dos sucursales, dos tickets y una evidencia descriptiva con PhotoPath NULL. No se inventan fotografías ni se agrega esquema. La carga secuencial usa ON CONFLICT para Username y NOT EXISTS para los demás registros; conserva datos/estados existentes y no está diseñada para ejecución concurrente. Advierte sobre un tecnico1 previo con otra contraseña y sucursales demo duplicadas por una carga externa.

Credencial pública de desarrollo: tecnico1 / Demo123*. Su hash fue generado con PasswordHasher<Usuario> de ASP.NET Core .NET 10 y verificado: acepta la contraseña correcta y rechaza una incorrecta. PostgreSQL recibiría únicamente el hash. No se reutilizó ninguna credencial privada y no se cargaron los datos sobre la base local.

Orden manual en pgAdmin, documentado en README: DATABASE → FUNCIONES_SP → VISTAS → TRIGGERS; agregar DATOS_PRUEBA únicamente para desarrollo/demo. Los primeros cuatro permiten instalar una base funcional sin datos. La API no instala objetos ni hace seed.

## Renombres C#

| Antes | Ahora |
|---|---|
| LoginController | ControladorLogin |
| MeController | ControladorIdentidad |
| DatabaseHealthController | ControladorSaludBaseDatos |
| AuthService | ServicioAutenticacion |
| DatabaseHealthService | ServicioSaludBaseDatos |
| IDatabaseHealthService | IServicioSaludBaseDatos |
| PostgresUserDataAccess | AccesoUsuariosPostgres |
| IUserDataAccess | IAccesoUsuarios |
| AppDbContext | ContextoBaseDatos |
| JwtOptions | OpcionesJwt |
| BearerSecurityOperationFilter | FiltroSeguridadBearer |
| LoginRequest | SolicitudLogin |
| LoginResponse | RespuestaLogin |
| UserResponse | RespuestaUsuario |
| DatabaseHealthResponse | RespuestaSaludBaseDatos |
| User | Usuario |
| Branch | Sucursal |
| Evidence | Evidencia |
| TicketStatus | EstadoTicket |

Los archivos de esas clases/interfaces se renombraron con el mismo nombre y se actualizaron referencias, genéricos y DI. Conexion, IConexion y Ticket ya eran compatibles con la regla. ContextoBaseDatos y EF Core continúan inactivos; no se eliminan dependencias.

## Renombres Dart

| Antes | Ahora / archivo |
|---|---|
| ApiConnection | IConexionApi / i_conexion_api.dart |
| ApiClient | ClienteApi / cliente_api.dart |
| ApiResponse | RespuestaApi / respuesta_api.dart |
| ApiStatus | EstadoApi / estado_api.dart |
| ApiRoutes | RutasApi / rutas_api.dart |
| ApiConfig | ConfiguracionApi / configuracion_api.dart |
| AppBindings | DependenciasApp / dependencias_app.dart |
| AppTexts | TextosApp / textos_app.dart |
| AppColors | ColoresApp / colores_app.dart |
| AppFonts | FuentesApp / fuentes_app.dart |
| Routes | Rutas / rutas.dart |
| AppPages | PaginasApp / paginas_app.dart |
| InitialView | VistaInicial / vista_inicial.dart |
| TicketsApp | AppTickets / main.dart |

Los tests propios pasaron a cliente_api_test.dart, cliente_api_real_test.dart, conexion_api_test.dart y vista_inicial_test.dart. Se actualizaron imports, referencias de documentación y README. Conexion conserva su nombre y composición con ClienteApi; DependenciasApp registra IConexionApi → Conexion.

La regla global queda también en AGENTS.md para las próximas etapas.

## Nombres y contratos conservados

El código nativo generado por Flutter conserva sus nombres; no fue diseñado ni modificado para esta etapa. No se traducen tipos externos como ControllerBase, DbConnection, DbCommand, GetxController, GetPage, BuildContext, PasswordHasher, ProblemDetails o paquetes externos. Program.cs, main.dart, appsettings y pubspec conservan nombres convencionales de herramientas; Tickets.Api y el paquete tikets mantienen identidad de proyecto. Carpetas convencionales mantienen la arquitectura existente.

Ticket, Login, API, JWT, SQL y Bearer son términos técnicos reconocibles. Las propiedades/métodos existentes se conservan porque esta regla se aplica a clases, interfaces y archivos; en particular nombres de campos HTTP/SQL y el User heredado de ControllerBase no son clases propias por traducir. Pending, InProgress y Resolved se mantienen por el contrato PostgreSQL vigente.

No cambian tablas, columnas ni get_user_by_username. URLs conservadas: POST /api/auth/login, GET /api/auth/me y GET /api/health/database. Se compararon los campos Swagger: username/password, token/user, id/username/name y status/database permanecen iguales. Cambian únicamente los nombres de esquemas DTO y grupos de Swagger según las clases renombradas.

## Validación y límites

- dotnet build: 0 errores, 0 advertencias.
- Health: 200, status ok y database connected con User Secrets.
- Swagger: carga y conserva las tres URLs; health no requiere JWT.
- /api/auth/me sin JWT: 401. Login sin campos: 400.
- flutter analyze: sin problemas.
- flutter test: 15 aprobadas; 1 prueba externa omitida por defecto.
- flutter build apk --debug: APK generado.
- SQL: estructura física y función idénticas a la versión anterior; separación documental comprobada, 6 INSERT demo y ninguna definición artificial de vista/trigger.
- Hash demo: verificación real con PasswordHasher; no se ejecuta SQL demo. La idempotencia se revisó por condiciones del bloque, sin simular una carga en la base local.
- User Secrets, appsettings y configuración del proyecto no fueron modificados.

Se realizan commits separados para nomenclatura y documentación SQL y se publican en main después de las validaciones y auditoría de secretos. No se avanza a Login Flutter, endpoints/UI de tickets, SQLite, sincronización o integraciones externas.

Documentación del código: revisada. El código propio modificado conserva XML C# o /// Dart en español con intención, funcionamiento y razón. SQL no trivial incluye comentarios equivalentes; no se comenta boilerplate generado.


## Problemas y decisiones

Durante la revisión se observaron ediciones concurrentes temporales en las rutas Flutter. Los archivos volvieron a la ruta inicial existente y se repitieron analyze, test y build apk sobre ese estado final antes del commit. No quedó una ruta /home ni una pantalla adicional.

No hay errores ni decisiones nuevas pendientes. La muestra SQL está revisada y el hash validado, pero su carga manual sigue siendo opcional y no se ejecutó en la base local. EF Core continúa conservado según las decisiones anteriores.
