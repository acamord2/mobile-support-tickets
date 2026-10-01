# Evidencias e imágenes

## Seguimiento del MVP

En un ticket En atención, Agregar seguimiento abre un formulario con descripción obligatoria del trabajo y fotografía opcional. ServicioImagen conserva compresión JPEG, Base64 completo y límite de 1 MiB. La evidencia y su operación se guardan mediante la transacción existente; no necesita Internet ni JWT vigente para trabajar localmente. Un ticket Resuelto permite consulta, sin nuevas modificaciones.

Detalle lista descripción, fecha local, fotografía disponible y aviso pendiente desde SQLite. El GET de tickets incorpora las evidencias públicas del propietario para descarga; los registros ya confirmados se reconocen por Id remoto. No hay galería, almacenamiento externo ni campos nuevos. Resolver requiere una descripción de evidencia no vacía, sin exigir foto.

Las pruebas específicas verificaron trabajo sin fotografía, guardado único ante doble pulsación, bloqueo de resolución sin texto, imagen JPEG real comprimida, envío después de crear el ticket remoto y reintento sin duplicados. La prueba física final se realiza manualmente sin flutter drive y se registra al concluir.

La captura opcional del formulario NuevoTicket permite cámara o galería mediante image_picker. ServicioImagen recibe bytes y ejecuta trabajo en un isolate (compute), separado de widgets, controllers, repositorios y HTTP. Utiliza image para aplicar orientación, reducir la dimensión mayor a 1600 y producir JPEG con calidades 85/70/55/40; si no cumple, reduce dimensiones en intentos acotados. Mide bytes antes de Base64, devuelve Base64 sin prefijo, MIME image/jpeg, tamaño original/comprimido y dimensiones. Nunca trunca Base64. Datos inválidos producen FormatException controlada.

ConfiguracionImagen.maximoBytes centraliza 1024 * 1024 bytes (1 MiB) en Flutter; ValidacionEvidencia.MaximoBytes centraliza el mismo contrato en la API. El límite es de JPEG comprimido, no de longitud Base64. Las pruebas generan imágenes sintéticas; no se versionaron fotografías personales. Las claves de permiso iOS explican cámara/galería; iOS no se compiló ni probó en este equipo Windows.

La evidencia SQLite usa ticket_id_local, independiente de Id remoto. Crear ticket con foto persiste ticket/evidencia/ambas operaciones en una transacción. La cola solo conserva id_local y autoría, no duplica el contenido Base64. Se confirma primero ticket e Id remoto; después POST /api/tickets/{id}/evidence. Si falla la evidencia, el ticket confirmado no se vuelve a crear.

La API verifica usuario activo, propiedad del ticket, descripción, MIME fijo JPEG, Base64 decodificable, límite de bytes decodificados y firmas JPEG inicial/final. No admite data URI ni trunca contenido. Esta validación del servidor no realiza una decodificación completa de píxeles: la imagen completa se produce y se prueba como decodificable en Flutter; una inspección exhaustiva de formatos del lado servidor queda fuera de este MVP.

PhotoBase64 guarda el contenido íntegro en PostgreSQL; PhotoPath se conserva y no se reutiliza para la fotografía. No se añade columna MIME: solo se admite JPEG, con MIME enviado en el contrato y conservado localmente. No hay cloud storage.

Para evitar duplicación ante pérdida de respuesta, el acceso de datos bloquea el ticket propio durante la transacción y recupera evidencia idéntica por TicketId + Description + PhotoBase64 (incluido NULL). Limitación deliberada: dos evidencias intencionalmente idénticas se consideran la misma; no se añadió identificador remoto extra ni ALTER. Tickets sí utiliza el UUID móvil y restricción UNIQUE autorizados.

Pruebas de imagen: pequeña, grande/redimensionada, Base64, metadatos/tamaño y decodificación JPEG, contenido inválido y procesamiento en isolate. SQLite y sincronización prueban vínculo local, orden ticket → evidencia y ausencia de recreación tras confirmar el ticket. La prueba real validó evidencia descriptiva y rechazo de Base64 inválido. La fotografía extremo a extremo está pendiente: el teléfono reconectado bloqueó reinstalación por USB tras corregir un fallo del canal HTTP. No se creó aún la fotografía sintética remota autorizada ni se afirma prueba física completa. El incidente de desinstalación automática de flutter drive se registra en tickets-agenda.md.
