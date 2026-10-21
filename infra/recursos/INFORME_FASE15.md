> Estado consolidado vigente: [manual de infraestructura](../../docs/infraestructura/README.md). Esta nota conserva antecedentes y propuestas de su fase; revisar el manual actual antes de operar.

# Fase15: auditoria y propuesta de recursos, NO aplicada

Ubuntu20.04.6WSL2, Docker27.3.1, rama prueba_docker,2026-10-21. Solo consultas y archivos nuevos. tickets-supervisor.service active PID310723 NRestarts0; mantenimiento desactivado. No se modifico supervisor ni systemd, politicas restart, contenedores, API, Flutter, DB, red, SSH o secretos. No stress, docker update o compose up.

## Capacidad WSL y competencia

16CPUlogicas (8nucleos/2hilos, Ryzen7 8840HS); RAM7946010624bytes=7.40GiB. MemAvailable6280601600bytes=5.85GiB; libre2.28GiB y buff/cache3.87GiB: disponible no es igual a libre, buena parte de cache es reclamable. Swap2GiB con150.39MiB usados. cgroupsv2; memory/cpu controllers y contabilidad de swap efectivos. PSI memoria avg10/60/300=0 en muestra: no prueba ausencia de episodios anteriores. No modificar .wslconfig, Engine ni Windows.

Otros proyectos observados solo para sumar recursos: unos57.38MiB de working set actual entre PostgreSQL15/Redis/etc; sus limites son ilimitados y MongoDB tiene bucle preexistente. No se modifico ninguno. Ese consumo bajo no garantiza margen futuro para ellos.

## Consumo e historico

Consulta solicitada7dias, pero datos disponibles menos24h. Corte de extraccion registrado en historico.json. Maximos RAM calculados sobre muestras rawretenidas, NO maximos continuos. Servicios recreados se agrupan por label de servicio dentro del proyecto: los picos pueden pertenecer a una instancia anterior; no son todos del PID actual. CPUactual=media5min; CPUmax=maximo de medias5min muestreado cada1min (subconsulta7d), NO pico instantaneo.100%equivale a1CPUlogica, no a16CPUhost. Un pico de docker stats en2segundos no es comparable a esta media5min.

| Servicio | WS actualMiB | WSmaxMiB | RSSactualMiB | RSSmaxMiB | TotalmaxMiB | CPUactual%1core | CPUmax5m%1core |
|---|---:|---:|---:|---:|---:|---:|---:|
| api | 105.47 | 152.25 | 69.85 | 83.95 | 240.03 | 0.12 | 3.39 |
| blackbox | 12.69 | 16.78 | 11.84 | 14.52 | 44.14 | 0.33 | 0.54 |
| cadvisor | 27.86 | 32.47 | 19.9 | 23.59 | 66.91 | 1.02 | 1.56 |
| docker_socket_proxy | 30.55 | 32.16 | 26.32 | 26.93 | 49.17 | 0.28 | 0.59 |
| grafana | 341.11 | 510.61 | 138.19 | 500.9 | 512.0 | 2.01 | 8.17 |
| postgres | 88.65 | 92.52 | 29.59 | 32.86 | 176.05 | 2.61 | 3.2 |
| postgres_exporter | 9.55 | 12.65 | 8.29 | 10.4 | 22.23 | 0.62 | 0.87 |
| postgres_exporter_lectura | 9.08 | 12.52 | 8.29 | 10.37 | 18.55 | 0.67 | 0.77 |
| postgres_lectura | 35.61 | 40.03 | 11.07 | 14.49 | 114.09 | 2.13 | 2.16 |
| prometheus | 60.88 | 84.06 | 56.04 | 79.5 | 219.0 | 0.76 | 1.45 |
| supervision_metricas | 0.48 | 4.65 | 0.13 | 2.79 | 4.65 | 0.2 | 0.25 |

Periodos realmente disponibles, America/Mexico_City(CSTUTC-6), no siete dias completos:

- api: 2026-10-20 14:43:00 a 2026-10-21 14:15:21 CST; 23.54horas; muestras WS=1220
- blackbox: 2026-10-20 14:43:10 a 2026-10-21 14:15:23 CST; 23.54horas; muestras WS=1261
- cadvisor: 2026-10-20 14:43:09 a 2026-10-21 14:15:14 CST; 23.53horas; muestras WS=1266
- docker_socket_proxy: 2026-10-20 14:43:01 a 2026-10-21 14:15:31 CST; 23.54horas; muestras WS=1260
- grafana: 2026-10-20 14:43:08 a 2026-10-21 14:15:23 CST; 23.54horas; muestras WS=1272
- postgres: 2026-10-20 14:43:09 a 2026-10-21 14:15:18 CST; 23.54horas; muestras WS=1195
- postgres_exporter: 2026-10-20 14:43:01 a 2026-10-21 14:15:17 CST; 23.54horas; muestras WS=1256
- postgres_exporter_lectura: 2026-10-20 17:09:23 a 2026-10-21 14:15:21 CST; 21.1horas; muestras WS=867
- postgres_lectura: 2026-10-20 16:30:05 a 2026-10-21 14:15:21 CST; 21.75horas; muestras WS=895
- prometheus: 2026-10-20 14:42:54 a 2026-10-21 14:15:25 CST; 23.54horas; muestras WS=1262
- supervision_metricas: 2026-10-21 12:06:49 a 2026-10-21 14:15:22 CST; 2.14horas; muestras WS=345

Working set cAdvisor aproximadamente uso total menos inactive_file; Docker CLI Linux tambien descuenta inactive_file para su presentacion. RSS contabiliza memoria anonima residente, no todo cache/compartida. memory.current incluye carga total del cgroup: anon/file/kernel; swap se cuenta aparte. No sumar RSS de procesos PostgreSQL para estimar limite porque se duplican segmentos compartidos. No comparar totalmax con currentWS como si fueran misma metrica, ni usar WS como unico margen frente a OOM.

Grafana: actualWS341MiB, RSS138MiB, pero memory.current531070976bytes=506.47MiB de512. file377856000,anon142229504,inactive_file176586752. El cache activo explica parte de la diferencia. memory.peak536895488 (ligero exceso transitorio), max33407,eventosoom0/oom_kill0; OOMKilledfalse. Swapactual157773824bytes=150.46MiB y picohistorico220.64MiB. Hay reclaim/refaults frecuentes; no diagnosticar fuga solo con23h de datos. Aumento768MiB justificado para reducir presion; investigar tendencia posterior sin instalar herramientas ni cargarlo ahora.

## Limites efectivos y propuesta condicionada

| Servicio | RAMactualMiB | CPUactual | RAMpropuestaMiB | CPUpropuesta | Reserva propuestaMiB | RAM+swap maxMiB |
|---|---:|---:|---:|---:|---:|---:|
| api |sin limite|sin cuota|512|1.0|128|768|
| postgres |sin limite|sin cuota|1024|1.5|256|1280|
| postgres_lectura |sin limite|sin cuota|1024|1.0|256|1280|
| grafana |512|1.0|768|1.0|256|1024|
| prometheus |768|1.0|768|1.0|128|1536|
| cadvisor |384|0.75|384|0.75|0|sin cambio(768)|
| blackbox |96|0.25|96|0.25|0|sin cambio(192)|
| docker_socket_proxy |64|0.15|64|0.15|0|sin cambio(128)|
| postgres_exporter |128|0.25|128|0.25|0|sin cambio(256)|
| postgres_exporter_lectura |128|0.25|128|0.25|0|sin cambio(256)|
| supervision_metricas |32|0.10|32|0.10|0|sin cambio(64)|

Candidatos API/DB no son validacion de carga: se aceptan como punto de partida de practica actual de baja concurrencia, se RECHAZA afirmar que cubren100conexiones activas/consultas arbitrarias. Grafana768 es prioridad. No reducir Prometheus ni otros servicios por tener consumo bajo: historico corto, compilacion de consultas/compactacion y transitorios no representados. Reservas suman1GiB, son proteccion blanda de reclaim (verificar memory.low al aplicar), no memoria preasignada ni garantia de capacidad. No tocar memory.min/high ni kernelOOMflags.

Suma RAMdura de11servicios4928MiB=4.8125GiB. Quedan unos2.588GiB de7.40 para sistema, Docker, supervisor y proyectos ajenos: reservar presupuesto operativo1.5GiB para OS/Engine y unos1.09GiB para terceros. Es una envolvente de planificacion, NO garantia porque terceros carecen de limites y comparten kernel/WSL; si requieren mas, no aprobar toda la propuesta sin reajustar. CPU suma7.25de16logicas, no son nucleos reservados. Sin pinning: cuota no impide bursts/scheduling ni garantiza latencia.

Swap propuesto:256MiB adicionales por API/PG/Grafana; en Grafana se mantiene TOTALactual1024 pero RAMsube768, por lo que swappermitida baja512->256MiB. Revalidar swapactual<256 antes de futura aplicacion; su pico220.64 deja margen pequeno, compensado parcialmente por mayor RAM, no es garantia. Los techos permitidos de swap del conjunto pueden sumar mas de2GiB y terceros son ilimitados: son maximos, no reserva; no planificar sostener uso simultaneo de todos. No cambiar swap de WSL ni considerarla sustituto de RAM.

## PostgreSQL

Ambos nodos: shared_buffers128MiB; work_mem4MiB; hash_mem_multiplier2; max_connections100; maintenance_work_mem64MiB; autovacuum_work_mem=-1 hereda maintenance;3workers; max_parallel_workers8,max_parallel_workers_per_gather2; temp_buffers8MiB; effective_cache_size4GiB. Este ultimo es estimacion del planner, NO asignacion real de4GiB. No cambiarlo ni shared_buffers/otros parametros en esta fase.

Actividad de muestra: primario8clientes (7idle+1active, incluye consulta de auditoria),1walsender; replica5clientes (4idle+1active),startup/walreceiver. tickets_db reportaba7/5backends respectivamente, segun momento. Hits compartidos acumulados~99.985%/99.992%, temp_bytes0: influye monitorizacion y carga baja; no es p95 ni prueba de rendimiento bajo carga.

work_mem aplica por operacion/nodo y puede multiplicarse con paralelismo;100hashes concurrentes x4MiB x2 ya son800MiB, mas128shared, hasta192autovacuum y memoria de conexiones/cache/temp.1GiB NO es limite suficiente garantizado en ese peor caso. No adaptar max_connections a ciegas: standby exige compatibilidad con primario, y cambiar max_connections/shared_buffers requiere reinicio. No ejecutar ALTER/reload, ninguna migracion ni datos de carga. Primero probar concurrencia y pools en etapa autorizada antes de llamar estos limites aptos para produccion. Limitar CPU puede retrasar replay/WAL; verificar lag y receiver, no promover.

## API .NET10

Runtime instalado10.0.13, ServerGCtrue. Sin variables GC/heap/processor explicitas; no se encontro GC.RefreshMemoryLimit ni diagnostico de heap propio en fuentes. No se adjunto depurador ni se instalo profiler. Working set no es tamano de heap. El proceso arranco sin limite de cgroup. Un limite512MiB al arrancar da por defecto un presupuesto aproximado75% para heap GC (384MiB) si no hay otros overrides; NO es limite de RSS ni incluye toda memoria nativa, threads/JIT/HTTP. Dejar margen total.

Docker update cambia el techo del kernel en vivo, pero no acredita que el GC/ProcessorCount ya inicializados recalculen memoria/paralelismo. Existe GC.RefreshMemoryLimit pero requiere cooperacion de la app y puede fallar si el nuevo techo es menor al comprometido. No modificar API para invocarlo. Por ello no presentar limite API512en vivo como totalmente validado; mantenerlo condicionado a nueva autorizacion con ventana de reinicio SOLOAPI o prueba de diagnostico adaptacion, no ejecutar reinicio ahora. CPUquota en kernel si se impone en vivo, pero heuristicas GC/threadpool pueden conservar configuracion anterior. No inyectar DOTNET_* ni editar runtimeconfig.

## Aplicacion futura, NO ejecutada

Nuevo compose.recursos.yaml es el unico cambio Compose preparado. No modificar Composebase, overrideAPI, replica o monitoring ahora. Incluirlo AL FINAL al gestionar estos servicios en el futuro para conservar propuesta despues de recreacion; no lanzar compose up para aplicar limites en vivo: puede recrearlos. Modelo fusionado validado y comparado: solo mem_limit/mem_reservation/memswap_limit/cpus de5servicios cambiaron. RESTO identico.

Secuencia recomendada: aprobar primero SOLOGrafana768 (aumento), observar24h y luego revisar API/DBcondicionadas. Antes de cada docker update: identidad por proyecto/servicio/ID; snapshot recursos/StartedAt/RestartCount/memory.events; memory.current inferior al techo con margen (orientativo<70%), swapactual por debajo del nuevo permiso, MemAvailable del host y dependencias saludables. No ejecutar si presion global/cliente esta ocupado o ID no corresponde. No activar mantenimiento innecesariamente ni modificar supervisor; si empieza un incidente real, pausar cambios y solicitar decision.

Ejemplos listos para revision, NO comandos ya ejecutados. Reemplazar $ID_* por IDs verificados justo antes, nunca usar docker ps -q global:

```sh
# Aumento prioritario: confirmar swapactual<256MiB, memoria disponible y baseline.
docker update --memory 768m --memory-reservation 256m --memory-swap 1024m --cpus 1 "$ID_GRAFANA"
# Condicionales: NO aplicar API sin resolver adaptacion del runtime/ventana autorizada.
docker update --memory 512m --memory-reservation 128m --memory-swap 768m --cpus 1 "$ID_API"
docker update --memory 1024m --memory-reservation 256m --memory-swap 1280m --cpus 1.5 "$ID_POSTGRES"
docker update --memory 1024m --memory-reservation 256m --memory-swap 1280m --cpus 1 "$ID_REPLICA"
# Prometheus conserva techo/CPU/swap, solo reserva propuesta128m.
docker update --memory 768m --memory-reservation 128m --memory-swap 1536m --cpus 1 "$ID_PROMETHEUS"
```

Docker27/Linux admite actualizaciones CPU/RAM/reserva/swap de contenedores sin recreacion. Eso NO hace inocua la reduccion de memoria: kernel puede reclamar cache o provocar OOM; tampoco es validacion runtime de esta propuesta. Se deben verificar controles soportados antes. Variables de entorno, runtimeconfig, imagen/entrypoint/mounts y muchos healthchecks requieren recreacion/reinicio fuera de esta autorizacion; parametros PGpostmaster requieren restart. Esta fase no modifica ninguno.

## OOM, supervisor y reversion

OOMkill real puede matar proceso y Dockerunless-stopped reiniciarlo; un OOMde backendPG puede desencadenar recuperacion de procesos en el servidor. Supervisor no ajusta RAM ni debe repetir SQLautoheal; no diagnosticar solo con State.OOMKilled porque puede cambiar tras reinicio. Comparar memory.events oom/oom_kill, Docker events exit137/OOM, logs y restartCount antes/despues. No deshabilitarOOMkiller ni dar superusuario. El presupuesto3/hora del supervisor no limita ciclos DockerporOOM: si aparecieran, detener aplicacion de nuevos limites e informar, sin matar bases ni borrar datos.

Guardar snapshot justo antes de aplicar y preparar argumentos inversos por ID; limites_y_cgroups.json de esta auditoria NO sustituye ese snapshot futuro. Para Grafana el retorno seria memory512m,reservation0,swapTOTAL1024m,cpus1, pero SOLO si memory.current ha bajado suficientemente: tras elevar limite puede crecer y reducirlo de inmediato provocar OOM. Si no hay margen, no ejecutar rollbackautomatico; mantener aumento e informar. API/PG antes sin limites: NO se ha validado que docker update con valores0 elimine los limites (puede significar no actualizar); no ofrecerlo como rollback exacto ni probarlo en produccion. Antes de endurecer estos tres contenedores, validar restauracion en canario bajo autorizacion independiente. Si Engine27 no permite volver exactamente a ilimitado en vivo, la restauracion completa exige recreacion futura autorizada con configuracion original; mientras tanto conservar un techo temporal suficientemente holgado bajo decision explicita, sin reiniciar ni descubrir parametros por ensayo/error. Verificar memory.max=max,cpu.max=max100000 y reserva0 solo si la operacion ha demostrado soportarlo; volver a un valor alto no es igual a sin limite. Retirar override de futuras recreaciones y restaurar configuracion en modelo no cambia contenedor existente.

Despues de cada cambio: docker stats/inspect y cgroupmemory.current/max/low/swap.max/events/cpu.max; mismaID/StartedAt/RestartCount, sinOOM; APIhealth200 y disponibilidad lectura/escritura; SELECT1/recovery/readonly en nodos; streamingasync/slotactivo/LSNsin crecimiento sostenido;10targetsUP,datasource y5dashboards50paneles; journal del supervisor sin reinicios. Capturar15min iniciales y24h de carga normal antes del siguiente paso. Las pruebas de stress/concurrencia estan pendientes de autorizacion, no se ejecutan con este informe.

## Alertas adicionales propuestas, NO cargadas

alertas_propuestas.yaml: working set>85%/10min, eventos memory.max/5min, CPU>90%cuota/10min, periodos throttled>20%/10min, swap sostenida15min. Promtool valida5reglas; no se modifica setactivo de14reglas ni dashboards. CPU usaquota/periodo real; sin cuota se filtra. Antes de integrar la regla RAM verificar limites reales: cAdvisor puede presentar RAMhost como limite para contenedores ilimitados, no interpretarlo como techo configurado. OOMgauge/counter disponibles deben validarse como tales: memory.events.max NO equivale a OOMkill. La alerta de disponibilidad y reinicios existente sigue.

No hay node_exporter/MemAvailable/PSIhost en Prometheus comprobados; no inventar series. Monitoreo de MemAvailable<1GiB o presion PSI requiere nuevo recolector autorizado o revision manual de /proc, no cambiar supervisor. Alertas cargadas no son notificaciones externas entregadas.

Fuentes primarias: https://docs.docker.com/reference/cli/docker/container/update/ ; https://docs.docker.com/engine/containers/resource_constraints/ ; https://www.postgresql.org/docs/17/runtime-config-resource.html ; https://learn.microsoft.com/en-us/dotnet/core/runtime-config/garbage-collector ; https://learn.microsoft.com/en-us/dotnet/api/system.gc.refreshmemorylimit?view=net-10.0 .

## Archivos entregados y alcance

Nuevos: compose.recursos.yaml; infra/recursos/historico.json, limites_y_cgroups.json, modelo_propuesto.json, alertas_propuestas.yaml y este informe. Ningun archivo activo se modifico. No se aplicaron limites ni se suspendio/reinicio supervisor o contenedor. Se requiere autorizacion explicita para cualquier docker update, recreacion o integracion de alertas.
