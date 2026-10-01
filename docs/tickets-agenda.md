# Tickets y agenda local-first

## Estado entregado

PostgreSQL conserva la estructura confirmada manualmente por el usuario. Se verificaron por lectura ScheduledAt, ClientRequestId, PhotoBase64, RoleId, IsActive, Roles y UQ_Tickets_TechnicianId_ClientRequestId. No se ejecutó nuevamente ningún ALTER ni los documentos de migración. La vista nueva public.agenda_tickets se instaló con autorización explícita; su única definición canónica vive en database/VISTAS.md. OBJETOS_TICKETS_POSTGRESQL.md indica cómo instalarla en otra base ya migrada.

SQL Server continúa documentado/no validado contra instancia real. Su instalador incluye UNIQUEIDENTIFIER nullable y un índice UNIQUE filtrado por ClientRequestId IS NOT NULL para permitir varios NULL por técnico, además de PhotoBase64 NVARCHAR(MAX). La vista equivalente está en database/sqlserver/VISTAS_SQLSERVER.md. No hay provider ni conexión SQL Server.

## Flujo

API → ServicioSincronizacion → SQLite → repositorios → controllers → widgets. Login es la excepción explícita porque necesita autenticar remotamente; la agenda no consume respuestas HTTP. Home muestra fecha del dispositivo, identidad pública, indicador de red, conteos reales, agenda por ScheduledAt y acción rápida para crear.

NuevoTicket selecciona una sucursal previamente descargada, título, descripción y programación (fecha/hora inicialmente ahora). La creación no necesita API ni JWT vigente. RepositorioTickets guarda ticket, UUID, evidencia opcional y cola en una misma transacción; vuelve a Home y consulta SQLite. No se ofrecen sucursales ficticias: sin catálogo local debe sincronizarse primero. No se añadió pantalla de atención/detalle ni panel administrativo en esta etapa; el repositorio y PUT preparan actualizaciones locales.

## SQLite v3

La migración v2 → v3 conserva sesion_local y cola_sincronizacion. Añade role_id/rol públicos a sesión y usuario_id a cola; el token permanece en flutter_secure_storage. Añade sucursales por usuario, tickets y evidencias. Las fechas created_at, updated_at y scheduled_at son ISO-8601 UTC completas; la UI convierte programación a hora local. También se permite migrar v1 pasando por v2 en la misma apertura.

id_local no cambia. id_remoto es nullable hasta confirmar el servidor. client_request_id es UUID v4 generado una sola vez con Random.secure al crear localmente y nunca durante sincronización. Cada envío utiliza esa clave persistida. Las descargas reconocen Id remoto o clave móvil para evitar duplicar filas locales.

La cola guarda referencias locales pequeñas, no token, contraseñas ni Base64. Cada operación nueva pertenece a usuario_id. Los pendientes previos se asignan solamente a la identidad presente durante la migración; los huérfanos sin identidad se conservan sin envío automático, porque no es seguro atribuirlos a otra cuenta. Logout elimina identidad/token, no negocio ni cola. Otra cuenta consulta su agenda y solo procesa sus operaciones. Estados procesando interrumpidos se recuperan dentro del ciclo exclusivo del propietario.

## API

| Endpoint | Responsabilidad |
|---|---|
| GET /api/tickets | Agenda del técnico autenticado desde la vista |
| POST /api/tickets | Creación idempotente; devuelve el ticket nuevo o existente |
| PUT /api/tickets/{id} | Cambios editables del ticket propio, conserva identidad/creación/clave |
| GET /api/branches | Catálogo real para SQLite |
| POST /api/tickets/{id}/evidence | Evidencia autorizada, valida contenido y límite |

Cada endpoint tiene una clase y archivo propios en español. Controllers no contienen SQL. AccesoTicketsPostgres consume IConexion y comandos parametrizados; listado utiliza la vista. La identidad procede exclusivamente de sub validado en JWT. Los endpoints comprueban IsActive actual; /me también consulta la identidad activa y devuelve rol público. Un 401 requiere reautenticación sin borrar trabajo local. PasswordHash nunca aparece en JSON.

La creación ejecuta INSERT ON CONFLICT (TechnicianId, ClientRequestId) DO NOTHING y luego SELECT en un comando posterior: la restricción UNIQUE es la garantía concurrente y la siguiente lectura recupera el registro confirmado por otro request. Repetir una clave no cambia el contenido del ticket existente; modificaciones posteriores usan PUT. La fecha de creación offline se transmite al crear; no se sustituye por la fecha programada.

## Sincronización

Un ciclo comprueba sesión/red/health, reclama operaciones propias, sube tickets, persiste Id remoto y confirmación atómicamente, luego envía evidencias y finalmente descarga sucursales y agenda a SQLite. Home se refresca del repositorio. Las llamadas simultáneas comparten el mismo ciclo. No hay polling, bucles permanentes ni reintentos infinitos: un intento al entrar a Home, otro en transición sin red → con red y botón manual.

El canal HTTP se registra como dependencia global permanente: retirar Login no debe cerrar el cliente que conserva sincronización. Las pruebas de navegación verifican que permanece abierto en Login → Home → logout y que el cierre explícito libera el canal.

Estados públicos: sincronizando, actualizado, pendientes, offline, error y reautenticación. Un fallo no confirma operaciones ni simula éxito. Una edición durante envío mantiene pending mientras haya otra operación de ese ticket; una descarga no sobrescribe tickets pending. Se conservan cambios locales sin resolver automáticamente conflictos: cuando finalmente se envían, PUT aplica el estado local. Los registros retirados del servidor no se eliminan automáticamente del dispositivo en esta etapa.

## Validación

- dotnet build: cero errores y advertencias.
- Pruebas API sin red: reglas de Base64/MIME/límite y rechazo de usuario inactivo con contraseña correcta en memoria. No se desactivaron cuentas reales.
- API real: health/login/me/agenda/sucursales/Swagger correctos; acceso anónimo 401; Base64 inválido 400. Cinco POST concurrentes más reintento devolvieron un solo Ticket Id 3; evidencia repetida devolvió Id 2. Los dos registros fueron autorizados expresamente y se conservaron.
- flutter analyze: sin incidencias.
- flutter test: 68 correctas y 2 opt-in omitidas. Incluye migración/persistencia SQLite real, programación, conteos, protección pending, claves, autoría, logout, HTTP simulado offline/503/401/subida/descarga/reintento, PUT y orden de evidencia.
- APK debug compilado con API_BASE_URL LAN externa; no se versiona la dirección del equipo.
- No se utilizó emulador. El teléfono reconectado inició sesión; la primera prueba falló durante descarga antes de crear datos. Se corrigió el ciclo de vida del canal HTTP, validado mediante navegación GetX. La repetición física quedó bloqueada por INSTALL_FAILED_USER_RESTRICTED y requiere aceptar instalación por USB; aún no se afirma verificación física de SQLite/fotografía ni se creó el ticket adicional autorizado.
- El primer flutter drive desinstaló la app automáticamente al terminar. No se puede garantizar conservación de datos locales anteriores ni restauración sin respaldo. Próximos intentos deben usar --keep-app-running; el APK normal se compiló de nuevo, pero su reinstalación está pendiente del teléfono.

Pruebas reproducibles desde raíz: dotnet run --project tests/api/PruebasApi.csproj. El modo --real crea y conserva un ticket/evidencia nuevos por ejecución y requiere autorización; la credencial demo se lee exclusivamente de DATOS_PRUEBA.md, JWT solo en memoria, nunca en salida. Desde mobile: flutter analyze, flutter test y flutter build apk --debug "--dart-define=API_BASE_URL=$env:API_BASE_URL".

Para prueba física: instalar APK sin desinstalar ni borrar datos; iniciar sesión, sincronizar, desactivar red, crear ticket con fotografía, comprobar agenda, cerrar/abrir, recuperar red y sincronizar. Comprobar ticket/evidencia en PostgreSQL y los identificadores locales/remotos en el dispositivo. Equipo y teléfono deben compartir LAN; no depende de USB ni adb reverse.

La prueba automatizada integration_test/agenda_real_test.dart utiliza SQLite nativo separado, token en memoria, desconexión simulada en servicio y fotografía sintética. La persistencia se comprueba cerrando/reabriendo el archivo SQLite, no reiniciando el proceso. Su ejecución crea y conserva el ticket/evidencia adicional expresamente autorizado. Ejecutar flutter drive con --keep-app-running para impedir su desinstalación automática y reinstalar después el APK normal compilado sin DEMO_USERNAME/DEMO_PASSWORD.

BD_COMPLETA_POSTGRESQL.md se conserva intacto y sin versionar por instrucción del usuario: es un consolidado anterior con datos demo, no la fuente oficial actual y no incluye las nuevas columnas ni vista. Los documentos oficiales contienen la estructura actual. Documentación de código relevante revisada en español.
