# Evidencias

La fotografía es opcional. Usuario puede agregar evidencia inicial a su reporte pendiente; responsable Técnico/Coordinador asignado y Administrador pueden registrar seguimiento durante la atención. Un seguimiento admite texto, foto o ambos; vacío se rechaza. Resolved/Cancelled conservan consulta y no nuevas evidencias, salvo reintentos de registros ya confirmados.

## Captura y procesamiento

image_picker selecciona cámara/galería. ServicioImagen procesa fuera del hilo de UI: aplica orientación, reduce inicialmente el lado mayor a 1600, produce JPEG y baja calidad/dimensiones mediante intentos acotados. El máximo es **1 MiB de bytes JPEG comprimidos**, antes de Base64; no es el tamaño de la cadena.

La previsualización representa exactamente los bytes procesados que se guardarán. Cambiar reemplaza el borrador y Quitar lo retira; ninguna acción persiste antes de Guardar. No se incluyen fotografías ni Base64 reales en la documentación.

## Guardado y envío

Acción → transacción SQLite → UI inmediata → intento automático. Si no se puede enviar, permanece en la cola y ↻ reintenta. Primero se confirma el ticket, luego evidencia y evento con referencias remotas; fallo de imagen no recrea el ticket ya confirmado.

La evidencia inicial se enlaza a CREADO y la de atención a SEGUIMIENTO. TicketEvents guarda únicamente EvidenceId, nunca Base64; su FK compuesta exige el mismo ticket. Las evidencias antiguas sin enlace siguen consultables. Un seguimiento solo de texto no crea una evidencia vacía.

Evidences conserva PhotoBase64 completo sin prefijo data URI. PhotoPath permanece como campo compatible, sin usarlo como ubicación remota de la foto. No hay almacenamiento cloud.

## Validación y limitación real

La API valida usuario activo, alcance, condición inicial/técnica, texto compatible, MIME JPEG, Base64 decodificable, límite de bytes y firmas JPEG inicial/final. No inspecciona todos los píxeles; Flutter genera y comprueba la imagen procesada.

Deduplicación remota: TicketId + Description + PhotoBase64 bajo bloqueo transaccional. Dos imágenes intencionalmente idénticas pueden compartir evidencia, manteniendo eventos con UUID independientes. El timeline se deduplica por UserId/ClientRequestId.

Las pruebas cubren foto sola, texto solo, vacío, compresión, previsualización, cambio/quitar, envío/descarga y reintento sin duplicación. El usuario confirmó el flujo funcional físico. iOS no se compiló ni probó.
