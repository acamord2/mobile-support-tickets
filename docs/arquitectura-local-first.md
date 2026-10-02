# Decisiones de arquitectura

## Responsabilidades

Flutter usa MVC simplificado con GetX para rutas/controllers; módulos componen vistas, servicios y repositorios locales. La UI lee y guarda SQLite. ServicioSincronizacion es el único coordinador de transporte y cola; no se agregan capas, polling, CQRS ni sincronizadores paralelos.

ASP.NET Core mantiene controllers por endpoint, DTOs públicos, servicios concretos y Data con SQL parametrizado. IConexion abre conexiones Npgsql; no hay DbContext activo ni instalación automática de BD. El paquete existente que aporta Npgsql no se cambia durante el cierre documental. Los scripts versionados se ejecutan manualmente y SQL Server continúa como equivalente sin proveedor runtime.

## Identidad, offline y permisos

La identidad pública vive en sesion_local y el JWT en flutter_secure_storage. Arranque restaura antes de decidir Login/Home. Un JWT expirado o 401 limita acceso remoto, sin eliminar identidad ni pendientes. El primer login necesita API; logout retira sesión/token y conserva trabajo asociado a la cuenta.

La caché/cola está segregada por usuario. Descargar aplica visibilidad del alcance sin destruir pendientes. La API consulta rol/actividad vigentes; ocultar botones no sustituye autorización. Sin asignar es un conjunto común, porque no existe tenant/zona de Coordinador en el esquema.

## Consistencia e idempotencia

Datos, eventos y operaciones se guardan transaccionalmente antes de intentar red. UUID nace una vez y se mantiene entre reintentos; confirmar envío no crea historia nueva. Ticket conserva clave global aunque se reasigne; eventos usan UserId/ClientRequestId y solicitudes una clave única.

La cola guarda referencias o instantáneas necesarias, sin JWT ni copias de fotos. Envío ordena dependencias y comparte un ciclo exclusivo. Descarga respeta pending. Aprobar/rechazar solicitudes bloquea y valida filas dentro de una transacción PostgreSQL; aprobación añade estado final y eventos juntos.

SQLite v6 reconstruye tablas cuando nullable/CHECK no puede alterarse directamente. Copia registros, conserva secuencias y comprueba filas/referencias antes de confirmar; el workaround de contadores diferidos se aplica únicamente después de foreign_key_check válido. Esta preservación y los reintentos fueron la principal dificultad del desarrollo offline.

## Límites deliberados

No hay resolución automática de conflictos, background con la app cerrada, tiempo real, cloud de imágenes ni administración independiente. Un rechazo remoto conserva pending y requiere revisión/reintento; no se prometen merges automáticos. Evidencias idénticas pueden compartir un registro remoto.

API_BASE_URL se inyecta al compilar el APK y los perfiles de escucha permanecen estables. La dirección especial de emulador heredada no configura el teléfono físico; debe proporcionarse su URL accesible. Las pruebas no reescriben esa configuración ni usan credenciales reales.

No se probaron SQL Server, iOS ni despliegue Linux. Con más tiempo se priorizarían recuperación guiada de errores, escenarios largos de desconexión/concurrencia, descarga de imágenes más eficiente y despliegue HTTPS. [README](../README.md) contiene instalación y alcance final.
