# Monitoreo y Grafana

[compose.monitoring.yaml](../../compose.monitoring.yaml) complementa base, API dos conexiones, réplica y supervisión. Ningún puerto de monitoreo se publica por Docker. [Inventario](09-INVENTARIO-DOCKER.md) contiene versiones/digests, comandos y mounts reales.

## Scraping, protocolo y retención

[Prometheus](../../infra/monitoring/prometheus/prometheus.yaml) scrape/evalúa cada15s, timeout10s; datos persistentes en datos_prometheus:/prometheus y retención7d. La retención no garantiza siete días de historia disponibles. Monta infra/monitoring/prometheus→/etc/prometheus RO, incluidos reglas.yaml, supervision.yaml y targets de réplica.

| Job | Destino/función |
|---|---|
| prometheus | Autoobservación9090 |
| cadvisor | Recursos contenedores8080 |
| postgres | postgres_exporter9187 |
| postgres_replica | exporter standby9187 mediante file_sd |
| blackbox | Salud exporter9115 |
| api_disponibilidad | Probe HTTP /api/health/database, no /metrics de API |
| docker_estado | Dos probes running de API/primario por proxy |
| docker_health_postgres | Probe health primario por proxy |
| supervision | supervisor.prom por HTTP9199 |

Nueve jobs, diez targets; no diez contenedores scrapeados. Job supervision usa fallback_scrape_protocol: PrometheusText0.0.4 porque BusyBox no entrega Content-Type específico de métricas. Es selección del parser, no tolerancia a fallo del servicio. Se verificó con promtool y consultas reales.

Exporters usan monitor_postgres y archivo externo, --no-collector.wal evita pg_ls_waldir y permisos de archivos. Deshabilitan stat_statements/stat_activity_autovacuum, habilitan stat_checkpointer y en standby stat_wal_receiver. No conceder SUPERUSER/pg_read_server_files para un panel. Estado físico/WAL del supervisor proviene de SELECT de estadísticas; no presume bytes pg_wal del collector deshabilitado.

## Mounts y seguridad

Grafana: datos_grafana→/var/lib/grafana RW, provisioning→/etc/grafana/provisioning RO, dashboards→/var/lib/grafana/dashboards RO y password externo→/run/secrets/grafana_admin.key RO. UID472 necesita escribir su volumen; PrometheusUID65534 el suyo. Read-only no concede permisos de lectura por sí mismo.

cAdvisor usa pid/cgroup host, SYS_ADMIN/DAC_READ_SEARCH y mounts RO de /, /sys y Docker root; tmpfs superpuestos ocultan rutas sensibles previstas. Es observación privilegiada, no aislamiento frente a lectura del host. Docker Socket Proxy es el único servicio con socket: HAProxy permite GET/HEAD a lista de metadatos, niega escritura/exec/archive/logs. Mount docker.sock:ro no vuelve read-only el protocolo: la protección efectiva es ACL HTTP y red interna. Supervisor de host tiene permiso Docker separado y amplio.

## Provisioning y paneles

Datasource prometheus_local→http://prometheus:9090. [Provider](../../infra/monitoring/grafana/provisioning/dashboards/practica.yaml) instala JSON de [dashboards](../../infra/monitoring/grafana/dashboards).

| UID | Paneles | Cobertura |
|---|---:|---|
| docker_local | 12 | CPU, working set, red, disco, cantidad y tendencias |
| disponibilidad_local | 14 | API, PostgreSQL, probes y estadísticas |
| plataforma_local | 4 | Recolección y plataforma |
| replica_local | 8 | Receptor WAL/replicación disponible |
| supervision_local | 12 | Incidentes, funcionalidad, reinicios y latido |

Cinco dashboards/50 paneles con series reales. Cero puede ser válido; No data no es cero. Disco cAdvisor puede corresponder a filesystem compartido del host, no bytes exclusivos de un volumen. No hay evidencia de backups automáticos ni panel que los certifique.

## Reglas y validación

Seis alertas de reglas.yaml y ocho de supervision.yaml: ApiNoDisponible, PostgresNoDisponible, RecolectorNoDisponible, ReplicaAtrasada, ReplicaNoDisponible, ReceptorWalNoDisponible, SupervisorSinLatido, SupervisionNoDisponible, RecuperacionBloqueada, ServicioFuncionalNoDisponible, ApiSoloConsultas, MotorDockerNoDisponible, WalSinStreamingSupervisado y ReiniciosDockerFrecuentes.

Regla cargada no implica firing; pending acumula plazo for y firing supera ese plazo. **No existe Alertmanager/canal externo configurado**: no se acredita notificación entregada. Alertas de recursos Fase15 siguen propuestas, fuera de las14.

```sh
python3 infra/monitoring/validar.py
sh infra/operacion/compose_proyecto.sh exec -T prometheus promtool check config /etc/prometheus/prometheus.yaml
sh infra/operacion/compose_proyecto.sh exec -T prometheus promtool check rules /etc/prometheus/reglas.yaml /etc/prometheus/supervision.yaml
sudo python3 infra/supervision/comprobar_fase14.py --autorreparacion 1
sudo python3 infra/monitoring/comprobar.py
```

Validadores leen credencial Grafana solo en memoria, verifican datasource y ejecutan consultas de los paneles. En comprobar_fase14.py, --autorreparacion 1 es únicamente la expectativa de un assert sobre una métrica: no activa, arma ni ejecuta recuperación. No iniciar otro supervisor observar/vigilar para comprobar salud.

## Acceso local

PowerShell Windows, Python disponible, terminal propia:

```powershell
$repo = '\\wsl$\Ubuntu-20.04\home\econt\practica\mobile-support-tickets'
python "$repo\infra\monitoring\acceso_local.py" --puerto 13000
```

Abrir [Grafana](http://127.0.0.1:13000). Ctrl+C cierra ese proxy, no Grafana. Si13000 está ocupado identificar propietario; no matar procesos ampliamente. Proxy resuelve contenedor por proyecto/servicio y transmite por stdio WSL sin publicar puerto Docker ni registrar cabeceras. REMOTO contiene ruta/distro fijas: adaptar una copia revisada al cambiar clon.

No restaurar acceso publicando3000/9090 o cambiando firewall. Prometheus se consulta por IP descubierta desde WSL o validadores. Diagnóstico: logs exactos antes de asumir permisos, UID/volumen antes de chown, nunca chmod777; Content-Type usa fallback; pg_ls_waldir se evita; target UP no prueba probe_success; No data exige revisar PromQL/labels/intervalo.

[Referencia oficial Prometheus](https://prometheus.io/docs/prometheus/latest/configuration/configuration/).
