# Guion de demostración — 2:55

Preparar API y teléfono en la misma red, cuatro cuentas demo, una sucursal y un ticket nuevo. Evitar escribir contraseñas lentamente: iniciar cada cambio de sesión con los campos preparados y pausar la grabación si hace falta. No mostrar JWT, User Secrets ni conexión PostgreSQL. API_BASE_URL debe configurarse antes; no modificarla durante la demostración.

| Tiempo | Pantalla / acción | Narración |
|---|---|---|
| 0:00–0:20 | Diagrama del README | «Esta app mantiene la atención de incidencias aunque falte conexión. Flutter lee y guarda SQLite; una cola sincroniza con la API REST autenticada por JWT y PostgreSQL.» |
| 0:20–0:45 | Usuario: +, sucursal, problema, foto, previsualizar y Guardar | «El Usuario reporta sin elegir técnico ni fecha. La foto es opcional. Guardar confirma localmente e intenta sincronizar automáticamente.» |
| 0:45–1:15 | Coordinador: Sin asignar, abrir reporte, programar y asignar | «El Coordinador programa y asigna. El Home abre una sección a la vez y permite consultar su equipo y solicitudes.» |
| 1:15–1:45 | Técnico: abrir asignado, iniciar y guardar seguimiento | «El Técnico ve únicamente asignados. Registra trabajo y puede adjuntar evidencia comprimida.» |
| 1:45–2:10 | Técnico: Solicitar resolución | «Solicitar cierre no finaliza inmediatamente: crea una decisión pendiente. Cancelar exige motivo.» |
| 2:10–2:30 | Coordinador: Solicitudes, abrir y Aprobar | «Coordinación revisa; aprobar guarda decisión, estado final y eventos juntos. Rechazar conserva el estado.» |
| 2:30–2:45 | Detalle Resuelto, timeline | «La cronología conserva fecha original, autor, seguimiento y aprobación; la foto está enlazada al evento.» |
| 2:45–2:55 | Ticket activo con datos descargados: mostrar consulta offline; volver a conectar | «La interfaz continúa con datos locales. El trabajo offline queda en cola; recuperar red intenta enviarlo y ↻ permite reintentar.» |

Para el último bloque dejar preparado otro ticket activo; no intentar modificar el ya Resuelto. Mostrar únicamente lo que efectivamente ocurra en pantalla. La secuencia dura 2:55, sin contar preparación o pausas de grabación.
