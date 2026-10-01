# Evidencias e imágenes

## Seguimiento

Un ticket En atención admite seguimiento con texto, texto y foto o solamente foto. Sin ambos se rechaza. Guardar persiste SEGUIMIENTO, evidencia opcional y cola dentro de una transacción local; no espera API. Resolver exige ese evento manual; los eventos automáticos no cuentan. Un ticket Resuelto permite consulta y no nuevas modificaciones.

TicketEvents enlaza EvidenceId nullable y nunca contiene Base64. La FK compuesta exige que foto y evento pertenezcan al mismo ticket. Un seguimiento descriptivo no crea una evidencia vacía. Para foto sola se conserva descripción vacía del evento y una leyenda compatible en Evidences.Description.

## Procesamiento y previsualización

Cámara/galería utilizan image_picker. ServicioImagen procesa bytes en isolate con image: aplica orientación, reduce la dimensión mayor a 1600, produce JPEG y reduce calidad/dimensiones con intentos acotados. El máximo es 1 MiB de bytes comprimidos antes de Base64; nunca se trunca contenido. Devuelve MIME image/jpeg y contenido completo.

El formulario muestra Image.memory con el Base64 procesado que realmente se almacenará. Cámara/galería permiten reemplazar la selección; Quitar elimina solamente el borrador. No hay escritura hasta Guardar. La línea de tiempo vuelve a mostrar la imagen desde evidencias SQLite, sin copia en eventos. Las evidencias anteriores no enlazadas siguen disponibles por separado.

## Persistencia y envío

SQLite usa ticket_id_local y una referencia opcional desde ticket_eventos. La cola conserva solo identificadores locales y propietario. Se confirma primero el ticket, después la evidencia si existe y finalmente el evento. Si falla la imagen, se conserva pendiente para reintento y no se recrea el ticket confirmado.

La API valida usuario activo, propiedad, descripción compatible, MIME JPEG, Base64 decodificable, límite de bytes y firmas JPEG inicial/final. No realiza inspección completa de píxeles; Flutter produce y prueba la imagen decodificable. PhotoBase64 conserva contenido íntegro; PhotoPath no se reutiliza. No hay almacenamiento cloud.

La evidencia remota se deduplica por TicketId + Description + PhotoBase64 bajo bloqueo transaccional del ticket. Dos evidencias intencionalmente idénticas pueden compartir el mismo registro; distintos eventos conservan UUID propios y pueden referenciar esa imagen sin duplicarla. El evento se deduplica mediante UNIQUE(UserId, ClientRequestId).

## Validación

Pruebas específicas: seguimiento sin foto, solo foto, vacío rechazado, doble pulsación, JPEG comprimido, previsualización exacta, quitar/reemplazar sin persistir, envío y descarga, fallo de evidencia y reintento sin duplicados. La revisión física manual de previsualización y cronología está pendiente de confirmación del usuario. El APK LAN se instaló por reemplazo, preservando negocio e identidad. No se utilizan flutter drive ni fotografías personales en pruebas automatizadas. iOS no se compiló ni probó en Windows.
