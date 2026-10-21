> Estado consolidado vigente: [manual de infraestructura](../../docs/infraestructura/README.md). Esta nota conserva antecedentes y propuestas de su fase; revisar el manual actual antes de operar.

> Estado vigente: **tickets-supervisor.service instalado y habilitado**, MainPID310723 al migrar. Ver [MIGRACION_SYSTEMD.md](MIGRACION_SYSTEMD.md); las notas de preparacion/ejecucion manual siguientes son historicas.

> Estado vigente: **recuperacion stateless activada**; ver [RECUPERACION_ACTIVA.md](RECUPERACION_ACTIVA.md). Las notas de fases anteriores son historicas. No se hizo la prueba real Blackbox.

> Estado actualizado: **observabilidad Fase14 activa, autorreparacion desactivada**. Ver [FASE14.md](FASE14.md). Las secciones de preparacion siguientes documentan la etapa previa; activar reinicios sigue sin autorizacion.

# Supervision funcional y recuperacion: preparada, NO activada

Auditoria2026-10-21, rama prueba_docker. No se reinicio ningun contenedor real, no se activaron tareas/servicios ni se modificaron Compose existentes, API, Flutter, SQL, WAL, HBA, secretos o tuneles. Se ejecutaron ciclos puntuales de observacion SELECT/HTTP solamente. No hay demonio supervisor funcionando ni activacion.json. Los contenedores efimeros de promtool se retiraron solos y no tenian red.

## Inventario real

Detalle exacto con intervalos/timeout/start_period/retries, recursos, puertos, IDs y StartedAt en inventario_auditado.json.

| Servicio | Restart actual | Healthcheck Docker | Recuperacion preparada |
|---|---|---|---|
| api |no|ninguno|Solo running con fallo HTTP propio y dependencias sanas |
| postgres |no|pg_isready,5s/5s,12fallos,gracia10s|Solo diagnostico/alerta |
| postgres_lectura |no|salud_standby.sh,10s/5s,6fallos,gracia60s|Solo diagnostico/alerta |
| prometheus |unless-stopped|/-/ready,15s/5s,5fallos,gracia30s|Observacion; TSDB no se toca |
| grafana |unless-stopped|/api/health,15s/5s,5fallos,gracia30s|Candidato acotado |
| cadvisor |unless-stopped|/healthz,15s/5s,5fallos,gracia30s|Solo observacion por permisos/kernel |
| blackbox |unless-stopped|/-/healthy,15s/5s,5fallos,gracia30s|Candidato acotado |
| postgres_exporter |unless-stopped|/metrics con pg_up1,15s/5s,5fallos,gracia30s|Solo si SQL primario disponible |
| postgres_exporter_lectura |unless-stopped|/metrics con pg_up1,15s/5s,5fallos,gracia30s|Solo si SQL standby disponible |
| docker_socket_proxy |unless-stopped|/_ping,15s/5s,5fallos,gracia30s|Solo observacion |

Solo API publica5263:8080 (WSL todas las interfaces, sin cambios); bases y monitoreo no publican puertos. API/ambos PostgreSQL sin limites CPU/RAM; monitoreo conserva limites: proxy64MiB, blackbox96, exporters128 cada uno, cadvisor384, Grafana512, Prometheus768MiB. El nuevo transporte propuesto32MiB aun NO existe.

Dependencias Compose: api depende de postgres healthy para su creacion; Grafana de Prometheus; cAdvisor de proxy. Exporters necesitan DB aunque no depends_on; standby necesita primary para streaming, pero puede atender SELECT sin el. depends_on no supervisa/reinicia dependientes durante ejecucion. Healthchecks unhealthy NO implican reinicio automatico en Compose. pg_isready no prueba SQL/roles ni escritura. Se mantienen los healthchecks existentes.

## Estados y decisiones

- Proceso detenido/exited: no start/restart; se respeta parada manual. No se intenta inferir intencion del usuario a partir de ExitCode. Docker aplica sus politicas actuales por separado.
- Running y fallo funcional repetido: candidato solo si nombre, proyecto, servicio e ID fijado coinciden; OOM/arranque/dependencia desconocida bloquean accion.
- Red/dependencia: alerta/diagnostico, sin reinicio a ciegas. Comprobaciones directas desde WSL no dependen de Prometheus para decidir. Timeout HTTP3s; CLI Docker12s; un ciclo mide todos en serie. Un fallo de ruta puede parecer fallo HTTP propio si dependencias responden: revisar trazas antes de activacion y no prometer causalidad perfecta.
- Recursos: OOM detectado, no se reintenta con igual limite. Fallos de disco/config no se arreglan regenerando datos. ExitCode y logs se consultan al diagnosticar, no se publican secretos.
- Primario/standby: SQL de metadatos con SET ROLE monitor_postgres, recovery/read_only; WAL emisor async/receptor streaming en metrica separada. Ausencia WAL o retraso nunca reinicia ni promueve/reconstruye DB. No pg_basebackup/ALTER/slots ni escrituras.
- API: consulta /api/health/disponibilidad; lectura y escritura son capacidades separadas. Solo consultas puede ser saludable y no debe reiniciarse por primario caido. No se usa fallo de /api/health/database como unico motivo para reiniciar. No se prueba escritura ejecutando DML.
- Grafana requiere respuesta JSON database=ok; Prometheus readiness y consulta vector(1). Exporters requieren pg_up1; resto endpoints de salud internos. No hay passwords en comprobaciones; SQL usa acceso local existente del contenedor e inmediatamente SET ROLE monitor_postgres (capacidad privilegiada Docker explicada abajo).

## Politica de accion (NO armada)

Lista cerrada: api, grafana, blackbox, postgres_exporter, postgres_exporter_lectura. Los otros cinco solo observacion. No Docker start/stop/update/exec arbitrario en la ruta de accion: unico comando restart --time10 del ID ya fijado, con revalidacion inmediata de etiquetas/estado. Los exec SQL son fijos y de lectura.

3fallos consecutivos, gracia120s tras StartedAt, cooldown300s, maximo3solicitudes de reinicio/hora por servicio. Intervalo15s DESPUES de cada ciclo; no es SLA exacto de45s. Presupuesto se persiste antes de llamar al Engine incluso si el reinicio falla; no se borra al reiniciar supervisor. Los contenedores recreados requieren rearmar IDs con autorizacion; no se aceptan nombres ajenos MongoDB/Redis/PostgreSQL15.

Importante: el limite corresponde a los reinicios del supervisor, NO limita los reinicios que Docker ya realiza con unless-stopped. Se prepara alerta de reinicios frecuentes; no se cambia politica ni se detiene contenedor para imponer limite global. Propuesta futura para salidas con error: evaluar on-failure:3 por servicio, sabiendo que no recupera automaticamente tras reiniciar daemon; requiere aprobacion separada y plan de arranque. No combinar dos gestores que hagan start del mismo contenedor.

## Riesgo Engine y mantenimiento

No se monta docker.sock en ningun servicio nuevo. Supervisor es CLI local bajo el usuario WSL que ya pertenece a docker; no se anadio ese privilegio. Esto NO es aislamiento fuerte: acceso al Engine equivale en la practica a privilegio amplio del host. Allowlist/IDs/pruebas reducen errores de programa, pero no contienen codigo malicioso ejecutado bajo esa identidad. Mantener codigo/permisos y no ejecutar como root. Proxy HAProxy actual solo GET/HEAD sigue intacto: no se habilitan POST ni endpoints exec en el proxy compartido. Si se requiere separacion de seguridad real, revisar broker de acciones dedicado y autorizacion acotada antes de activar; no ampliar proxy/socket indiscriminadamente.

Estado externo ~/.local/state/tickets-supervision (0700), metricas en subdirectorio0755 y ficheros publicos sin secretos; estado.json, latido.json, incidentes.jsonl y activacion.json no van a Git. Lock excluye ciclos concurrentes; se libera al dormir para poder suspender. Mantenimiento suspende y borra fallos consecutivos, conserva intentos/cooldown. No habilitar otro supervisor sobre mismos IDs.

## Comandos seguros actuales

Desde Ubuntu como econt:

```sh
cd /home/econt/practica/mobile-support-tickets
python3 -m unittest discover -s infra/supervision -p pruebas_supervisor.py -v
python3 infra/supervision/supervisor.py una-vez
python3 infra/supervision/supervisor.py observar
# Ctrl+C detiene SOLO observador; no envia señales a contenedores.
python3 infra/supervision/supervisor.py mantenimiento
python3 infra/supervision/supervisor.py reanudar
python3 infra/supervision/supervisor.py suspender
```

observar/una-vez NUNCA reinician, aunque exista activacion. Tras autorizacion independiente para autorreparacion:

```sh
python3 infra/supervision/supervisor.py habilitar --confirmar-proyecto mobile-support-tickets-prueba-docker
python3 infra/supervision/supervisor.py vigilar
```

vigilar solo puede actuar si tambien existe activacion con IDs aprobados. Para apagar acciones desde otra terminal: mantenimiento o suspender; detener luego vigilar con Ctrl+C. Un ciclo que ya comenzo puede terminar antes de obtener lock: comprobar estado antes de intervenir manualmente. No borrar estado para resetear presupuesto. Reversion no requiere tocar Docker: suspender, Ctrl+C, conservar evidencias y todos los volumenes. No se activaron esos comandos de accion en esta fase.

## Observabilidad adicional preparada, NO desplegada

- Dashboard dashboard_supervision.json:12paneles, UID supervision_local. Fuera del directorio provisionado para NO alterar los4dashboards/38paneles actuales.
- Ocho alertas en reglas.yaml con pruebas promtool: latido ausente/viejo, endpoint no disponible, recuperacion bloqueada, fallo funcional persistente, API solo consultas, motor no disponible, WAL sin streaming y reinicios Docker frecuentes. Ventanas30s/1m/2m, segun regla.
- Metricasserie reales producidas por ciclo local: functional, Dockerhealth, estados/causa, reiniciosEngine/solicitados, incidentes, recuperacion, capacidades API y WAL. HealthDocker0 en API significa no definido, no afirmar API no disponible (ver inventario).
- compose.supervision.yaml solo agrega servidor estatico RO de metricas en red monitoreo, sin publicaciones ni socket/privilegios. BusyBox1.37.0 fija version, pero NO esta en cache local: antes de autorizar puesta en marcha validar proveedor/digest/arquitectura y httpd, adquirir imagen explicitamente; pull_policy never impide descarga implicita. El transporte es preparacion, no validacion runtime de imagen.
- job_prometheus.yaml es fragmento para scrape /supervisor.prom; no esta en configuracion activa. No se copiaron nuevas reglas/dashboard a mounts existentes ni se recargo Prometheus.

Para activar observabilidad se necesita aprobar: imagen/digest, crear solo supervision_metricas --no-deps con Composebase+monitoring+supervision, incorporar job/reglas y un quinto dashboard; validar promtool/check config/reglas/tests y samples reales antes del reload. No recrear API/PostgreSQL/Grafana. No hay Alertmanager/canal externo: reglas preparadas NO son notificaciones entregadas. No publicar un tiempo de recuperacion real hasta tener un incidente verificado; ceros iniciales no prueban recuperacion.

## Observacion independiente y reinicio Windows/WSL

comprobar_latido.py usa solo archivo externo, sin Docker/Prometheus. Si proceso se cuelga/muere, latido envejece; al volver, registra brecha en incidentes.jsonl y metrica ultima_brecha. Si Prometheus cae pero supervisor sigue, logs/estado continuan; alertas seran visibles al recuperarse, no se garantiza notificacion durante caida. Revisar desde Windows manualmente:

```powershell
wsl --list --running
# Si Ubuntu esta activo:
wsl -d Ubuntu-20.04 -- python3 /home/econt/practica/mobile-support-tickets/infra/supervision/comprobar_latido.py
```

No existe un observador independiente automatico: requeriria tarea Windows u otro host/canal autorizado. Este limite queda explicito; no autoinstalar tareas. Estado congelado/ausente es una senal verificable manualmente, no una alerta ya entregada.

WSL tiene systemd=true y Docker esta enabled/active. Eso solo arranca Docker cuando la distro inicia: no demuestra que WSL inicie al encender Windows. No se reinicio Engine/WSL para probarlo. Tras reinicio manual autorizado: iniciar distro; comprobar motor; contenedores unless-stopped intentaran recuperarse salvo paradas manuales; API/ambosPG con restart no necesitan revision/arranque MANUAL aprobado. Respetar mantenimiento y usar manifest de IDs/estado previo; no compose up indiscriminado (base sola podria revertir imagen/config API). Para arranque API conservar compose.api-lectura.yaml; standby conserva compose.replica.yaml. Diagnosticar SQL/WAL antes de abrir app. Tuneles SSH/proxyGrafana son temporales y se reabren con procedimientos propios, sin modificar ADB. Supervisor empieza en observar; activacion no equivale a arranque persistente. Una tarea Windows/systemd requeriria diseno y autorizacion especifica.

## Pruebas y siguiente autorizacion

21pruebas unitarias/ficticias aprobadas: estados healthy->unhealthy->recovering->healthy, HTTP503/200 efimero, limites/cooldown/gracia/mantenimiento, dependencias, APIdegradada, motor caido, ID/etiquetas, OOM, rechazo de otros proyectos, presupuesto persistido al fallo y observacion incapaz de accionar aun armada. SQL/HTTP reales de la observacion dieron healthy en10servicios, sin reinicios. Compose sintaxis,8reglas y pruebas promtool correctos.

Prueba real propuesta, aun NO autorizada: elegir blackbox exclusivamente (breve perdida de sondas, no datos); fijar ID/imagen/estado y registrar baseline; inducir suspension del proceso por SIGSTOP, no docker pause (pausa explicita se respeta como manual); verificar fallos consecutivos y un restart permitido; validar /-/healthy y targets al recuperar. Reversion prevista SIGCONT del mismo ID si no se reinicio y sigue suspendido; diagnosticar, no repetir a ciegas. Requiere autorizacion de interrupcion explicita y supervisor armado, no ejecutar antes. Alternativa mas segura: un contenedor canario aislado con politica separada y sin IDs reales, antes de tocar blackbox. Ninguna prueba real sobre API/Grafana/DB autorizada.

No se verifico recovery real de procesos, arranque tras reboot ni entrega de notificaciones: son pendientes, no exitos reportados.
