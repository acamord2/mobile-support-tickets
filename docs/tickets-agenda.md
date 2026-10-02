# Agenda y tickets

## Roles y pantallas

Usuario consulta sus reportes y crea sin técnico ni programación. Técnico consulta únicamente asignados. Coordinador consulta tickets propios, su equipo y la bolsa común sin asignar; Administrador tiene alcance global. No existe tenant/zona de coordinación en el esquema. La API verifica usuario activo y alcance actual, además de los controles visuales.

Home consulta SQLite, distingue Pending, InProgress, Resolved y Cancelled y combina filtros seleccionados. Coordinador tiene las cuatro secciones Mis tickets, Técnicos a mi cargo, Sin asignar y Solicitudes en un acordeón con una sola sección abierta; abrir un técnico muestra su agenda local. El detalle presenta problema, sucursal/dirección, estado, programación, responsables, evidencias, solicitudes y timeline.

## Flujo y solicitudes

Crear reporte → programar/asignar por Coordinador → iniciar atención por responsable → seguimiento → solicitar resolución/cancelación → revisión por Coordinador/Administrador. Administrador puede ejecutar operaciones globales; Coordinador atiende los tickets asignados a él. La creación previa del Técnico se conserva autoasignada.

`ScheduledAt` admite NULL: Sin programar. Programación y reprogramación pertenecen exclusivamente a Coordinador/Administrador; no se sustituye una cita ausente por CreatedAt. Asignar/reasignar conserva identidad y UUID. Los tickets finales no admiten nuevas operaciones de atención o asignación.

Solicitud: SOLICITUD_RESOLUCION o SOLICITUD_CANCELACION; estados PENDIENTE/APROBADA/RECHAZADA. Cancelar exige motivo y resolver admite comentario opcional. Registrar una solicitud no cambia el estado. Un equivalente pendiente se rechaza; reintentar el mismo UUID devuelve el mismo registro.

Aprobar guarda revisión, revisor, fecha, estado final y eventos de decisión/finalización en una transacción PostgreSQL. Rechazar guarda la decisión sin cambiar el ticket. Usuario/Técnico no pueden cerrar directamente mediante PUT ni revisar solicitudes.

## Persistencia, cronología y sincronización

Cada acción confirma datos, eventos y cola en SQLite antes de actualizar UI e intentar envío automático. La cola pertenece a una cuenta, conserva claves/instantáneas y sobrevive a logout. Otra cuenta no la procesa. Un ciclo exclusivo envía dependencias en orden: ticket → evidencia opcional → evento; solicitudes/revisiones conservan claves propias para sus eventos transaccionales.

Descargas concilian Id remoto/UUID y respetan pending. Falta de red, timeout, fallo API o rechazo no borra trabajo. ↻ reintenta; abrir Home y recuperar conectividad también dispara sincronización. No hay polling ni segundo sincronizador. Un 401 conserva identidad local y bloquea operaciones remotas hasta reautenticación.

SQLite está en versión 6. Sus migraciones preservan sesión, tickets, evidencias, eventos y cola; reconstruir nullable/CHECK verifica recuentos y foreign_key_check antes de confirmar. La liberación de contadores diferidos de SQLite ocurre después de comprobar referencias reales.

Timeline usa fechas UTC originales, mostradas en horario local, y autor persistido; no toma la identidad de la sesión actual. Tipos: CREADO, PROGRAMADO, REPROGRAMADO, ASIGNADO, REASIGNADO, EN_ATENCION, SEGUIMIENTO, SOLICITUD_RESOLUCION, SOLICITUD_CANCELACION, RESOLUCION_APROBADA, RESOLUCION_RECHAZADA, CANCELACION_APROBADA, CANCELACION_RECHAZADA, RESUELTO y CANCELADO. No se reconstruye historia desconocida de tickets antiguos. Evidencias no enlazadas siguen consultables por separado.

## Contrato HTTP existente

| Endpoint | Uso |
|---|---|
| POST /api/auth/login · GET /api/auth/me | Autenticación e identidad pública |
| GET /api/health/database | Conectividad anónima, sin consultar tablas |
| GET /api/branches · GET /api/technicians | Catálogos autorizados |
| GET /api/tickets · POST /api/tickets | Descargar agenda y crear por UUID |
| PUT /api/tickets/{id} | Editar/iniciar dentro del permiso actual |
| PUT /api/tickets/{id}/assignment | Asignar/reasignar |
| GET /api/tickets/{id}/events · POST /api/tickets/{id}/events | Cronología idempotente |
| POST /api/tickets/{id}/evidence | Evidencia inicial/técnica validada |
| POST /api/tickets/{id}/status-requests | Crear solicitud |
| GET /api/ticket-status-requests | Consultar solicitudes; pendientes por defecto |
| PUT /api/ticket-status-requests/{id}/review | Aprobar/rechazar |

Las vistas consultan repositorios locales, no HTTP. Cada endpoint tiene su controller; SQL parametrizado permanece en Data. JWT aporta identidad, nunca el cliente elige autor/revisor. Las FK compuestas impiden enlazar fotos de otro ticket y las claves únicas sostienen idempotencia.

Instalación y credenciales: [README](../README.md). Pruebas: roles/alcance, preservación de migraciones, ciclos exclusivos, reintentos, autoría, rechazo/aprobación y acordeón. La validación funcional física fue confirmada por el usuario; no se repite como parte del cierre documental.
