# Tickets y agenda local-first

> Registro histórico: la instalación vigente está en [README](../README.md) y en `database/PostgreSQL/v1/BD_COMPLETA.sql`. Los instaladores y migraciones anteriores se conservan en Git; no seguir sus instrucciones como instalación actual.

## Flujo del MVP

Crear → detalle → editar programación → comenzar atención → registrar seguimiento → resolver → sincronizar. Toda escritura se guarda primero en SQLite, con evento y cola en la misma transacción lógica. Las vistas no consultan HTTP. Home conserva agenda, conteos y filtros.

Editar permite título, descripción y ScheduledAt; conserva sucursal, identidad, UUID y estado. Las únicas transiciones son Pending → InProgress → Resolved. Resolver exige un evento manual SEGUIMIENTO previo, con texto, foto o ambos. Los eventos automáticos y las evidencias antiguas no sustituyen ese requisito. Resolved conserva consulta de historia y evidencias, sin edición ni reapertura.

## Cronología y autoría

La creación registra CREADO y PROGRAMADO. Cambiar la cita registra REPROGRAMADO con PreviousScheduledAt y ScheduledAt. Iniciar y resolver registran EN_ATENCION y RESUELTO. Los eventos son instantáneas inmutables, ordenadas por CreatedAt e Id; no se generan por UpdatedAt, confirmación o reintento.

El autor remoto se conserva mediante UserId y se entrega con nombre público. SQLite conserva autor_id y usuario_nombre; usuario_id identifica al propietario de la caché/cola. Mostrar un evento no toma el autor de la sesión actual. Las fechas se normalizan a UTC ISO-8601 y la UI las convierte a hora local.

Las evidencias previas permanecen disponibles en una sección separada cuando no están enlazadas a un evento. No se inventan eventos antiguos ni se atribuyen acciones históricas desconocidas.

## SQLite v4

La migración v3 → v4 añade ticket_eventos con claves local/remota, ticket local, propietario, autor, tipo, descripción, fecha original, UUID, citas anterior/nueva, evidencia local opcional y sync_status. Las referencias remotas se obtienen de tickets/evidencias; no se duplica Base64. Se conservan sesión, tickets, sucursales, evidencias y cola. Las migraciones anteriores siguen disponibles para instalaciones v1/v2.

Cada UUID se genera una sola vez. La cola guarda referencias pequeñas y propietario, sin JWT, contraseña ni fotografía. Otra cuenta no consulta ni procesa registros ajenos. Logout conserva negocio y pendientes; JWT permanece en flutter_secure_storage.

## API

| Endpoint | Responsabilidad |
|---|---|
| GET /api/tickets | Agenda propia |
| POST /api/tickets | Crear por UUID persistente |
| PUT /api/tickets/{id} | Actualizar campos operativos propios |
| GET /api/branches | Catálogo para caché |
| POST /api/tickets/{id}/evidence | Validar y guardar evidencia |
| POST /api/tickets/{id}/events | Guardar instantánea idempotente |
| GET /api/tickets/{id}/events | Descargar cronología con autor público |

Un endpoint corresponde a una clase y archivo. Controllers no contienen SQL; AccesoEventosPostgres reutiliza IConexion y parámetros. El JWT aporta el autor y se comprueba usuario activo y propiedad. No se permite elegir UserId ni enviar Base64 en el evento.

TicketEvents se instaló mediante la única migración PostgreSQL autorizada, sin datos demo adicionales, borrados ni otros ALTER. Sus FK son restrictivas y la relación compuesta impide enlazar evidencia de otro ticket. UNIQUE(UserId, ClientRequestId) garantiza idempotencia; INSERT ON CONFLICT y lectura posterior recuperan el mismo Id. La API no genera una segunda copia automática al recibir PUT. SQL Server permanece documentado y no ejecutado.

## Sincronización

Se extiende ServicioSincronizacion existente: confirmar ticket remoto → confirmar evidencia opcional → enviar evento con referencias remotas. Cada operación mantiene su pendiente hasta confirmarse; negocio y evento tienen confirmaciones independientes. Un fallo de imagen conserva los pendientes y no recrea el ticket confirmado. Los reintentos conservan el UUID original del evento.

El ciclo descarga sucursales, tickets/evidencias y eventos a SQLite; reconoce Id remoto/UUID, conserva instantáneas existentes y no pisa negocio pending. Home vuelve a consultar repositorios. No hay otro sincronizador, polling, resolución avanzada de conflictos ni cambios de LAN/puertos/perfiles. Un 401 conserva trabajo e identidad local y exige reautenticación para operaciones remotas.

## Validación

dotnet build: cero errores/advertencias tras liberar el ejecutable de la API anterior. flutter analyze: sin incidencias. La única suite final aprobó 84 pruebas y omitió dos opt-in; falló una expectativa antigua de versión 3, corregida a 4 y revalidada únicamente en su archivo: siete pruebas aprobadas.

Las pruebas específicas verifican migración real v3→v4 sin pérdida de filas, autor persistido, foto sola válida, vacío inválido, previsualización de los bytes procesados, resolución con seguimiento manual y sincronización después de fallo de evidencia sin duplicar ticket ni eventos. Swagger publica ambos endpoints de eventos y health LAN devuelve 200.

El APK debug se compiló con API_BASE_URL LAN aprobada y se instaló con adb install -r, sin desinstalar ni borrar datos. Se comprobó migración física a v4 y conservación de tickets, evidencias, cola e identidad. La revisión manual final del flujo está pendiente de confirmación del usuario; Android bloquea INJECT_EVENTS. No se utiliza flutter drive ni emulador.

BD_COMPLETA_POSTGRESQL.md permanece intacto y sin versionar; DATOS_PRUEBA.md conserva su modificación previa fuera de esta etapa. Documentación de código relevante revisada en español.
