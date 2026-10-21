# Inventario Docker verificado

2026-10-21, Linux/amd64, Engine27.3.1/Compose2.29.7. Once contenedores del proyecto. Systemd/SSH/proxies host no son imágenes. [JSON completo sin secretos](inventario-verificado.json).

|Servicio|Imagen real|Origen|Interno / host|RAM / reserva / total RAM+swap MiB|CPU|
|---|---|---|---|---|---|
|api|`tickets-api:fase12-3`|Local: api/Dockerfile|8080 / 5263 WSL 0.0.0.0 y ::|0 / 0 / 0|0.0|
|blackbox|`quay.io/prometheus/blackbox-exporter:v0.29.0`|Terceros/editor del proyecto|9115 / ninguno|96 / 0 / 192|0.25|
|cadvisor|`ghcr.io/google/cadvisor:0.60.6`|Terceros/editor del proyecto|8080 / ninguno|384 / 0 / 768|0.75|
|docker_socket_proxy|`tecnativa/docker-socket-proxy:v0.5.0`|Terceros/editor del proyecto|2375 / ninguno|64 / 0 / 128|0.15|
|grafana|`grafana/grafana:13.2.4`|Terceros/editor del proyecto|3000 / ninguno|768 / 256 / 1024|1.0|
|postgres|`postgres:17`|Docker Official Image|5432 / ninguno|0 / 0 / 0|0.0|
|postgres_exporter|`quay.io/prometheuscommunity/postgres-exporter:v0.20.1`|Terceros/editor del proyecto|9187 / ninguno|128 / 0 / 256|0.25|
|postgres_exporter_lectura|`quay.io/prometheuscommunity/postgres-exporter:v0.20.1`|Terceros/editor del proyecto|9187 / ninguno|128 / 0 / 256|0.25|
|postgres_lectura|`postgres@sha256:2d2b8998d31037bf721cfdf764d76ba74171b4fab3431b7f72c27c56ddbdf9e3`|Docker Official Image|5432 / ninguno|0 / 0 / 0|0.0|
|prometheus|`prom/prometheus:v3.15.0`|Terceros/editor del proyecto|9090 / ninguno|768 / 0 / 1536|1.0|
|supervision_metricas|`busybox@sha256:bdf57e528e45e4433820e045b29b4597825a1c9e38353532d90a01445013f82e`|Docker Official Image|9199 / ninguno|32 / 0 / 64|0.1|

Memory/CPU0 significa sin límite específico, sujeto a WSL. Swap0 en servicios sin límite no significa prohibido. Todas restart=unless-stopped. Grafana total1024 incluye768RAM+256swap adicional. Publicaciones de proyectos ajenos excluidas. Las imágenes de editores externos no se clasifican como Docker Official Images; API usa bases oficiales Microsoft y no tiene RepoDigest.

## Detalle exhaustivo

### api

- Nombre: `mobile-support-tickets-prueba-docker-api-1`; ID: `a1c448528710e67dc08910ea5a0caad80791899bcf0293fc57bf8ebe7f5cc522`.
- Image ID: `sha256:218135d79d244c66e75aafb7abbefd87e3d487cca7b4f3be4ff9ce656fbc8210`.
- Tags: `tickets-api:fase12-3`.
- Digest: no disponible: compilación local no publicada.
- Redes: `mobile-support-tickets-prueba-docker_acceso_api`, `mobile-support-tickets-prueba-docker_base_datos`.
- Entrypoint: `["dotnet", "Tickets.Api.dll"]`; comando: `null`.
- Estado: running / sin healthcheck; OOMKilled=false.
- Sin healthcheck Docker; API se valida por HTTP/Blackbox/supervisor.
- Dependencia Compose: postgres healthy.
- Mounts no secretos: ninguno adicional a credenciales externas cuando corresponde.
- Credenciales externas RO según Compose; contenido privado excluido del inventario.

### blackbox

- Nombre: `mobile-support-tickets-prueba-docker-blackbox-1`; ID: `8fb336223f2b69e1285dba5a6a52a3a1375feb27d923d4917b2e327fa6c9fdbf`.
- Image ID: `sha256:7ef4bd0d9c33800235b7b3dd9a5b9258fd22d51e847f46c9a30b83560fe3748b`.
- Tags: `quay.io/prometheus/blackbox-exporter:v0.29.0`.
- Digest: `quay.io/prometheus/blackbox-exporter@sha256:9613f2884689b6fad9f1939f6a3b0388c93a022cfaededb19545b329b5c83dea`.
- Redes: `mobile-support-tickets-prueba-docker_base_datos`, `mobile-support-tickets-prueba-docker_monitoreo`, `mobile-support-tickets-prueba-docker_motor_docker`.
- Entrypoint: `["/bin/blackbox_exporter"]`; comando: `["--config.file=/etc/blackbox/blackbox.yaml"]`.
- Estado: running / healthy; OOMKilled=false.
- Healthcheck: `{"Test": ["CMD-SHELL", "wget -q -O /dev/null http://127.0.0.1:9115/-/healthy"], "Interval": 15000000000, "Timeout": 5000000000, "StartPeriod": 30000000000, "Retries": 5}`.
- Dependencia Compose: sin depends_on explícito; ver dependencia funcional en arquitectura.
- Mounts no secretos: `/home/econt/practica/mobile-support-tickets/infra/monitoring/blackbox/blackbox.yaml` → `/etc/blackbox/blackbox.yaml` RO.

### cadvisor

- Nombre: `mobile-support-tickets-prueba-docker-cadvisor-1`; ID: `e50a0821a82c4a98dd3e2a442d3a6a74e093c36bfc0c1c6793fcfa6f2c57eed3`.
- Image ID: `sha256:d280a05f4391d4707f3d2407114e47083989c8dcfb1c6de976676620c2c0d1dd`.
- Tags: `ghcr.io/google/cadvisor:0.60.6`.
- Digest: `ghcr.io/google/cadvisor@sha256:b8e7d1093144fd088f425ff003d75a4aa405de075db78dae3bc563730b1bd07a`.
- Redes: `mobile-support-tickets-prueba-docker_monitoreo`, `mobile-support-tickets-prueba-docker_motor_docker`.
- Entrypoint: `["/usr/bin/entrypoint.sh"]`; comando: `["--docker=tcp://docker_socket_proxy:2375", "--docker_only=true", "--housekeeping_interval=15s", "--max_housekeeping_interval=15s", "--allow_dynamic_housekeeping=false", "--global_housekeeping_interval=30s", "--store_container_labels=false", "--whitelisted_container_labels=com.docker.compose.project,com.docker.compose.service", "--enable_metrics=cpu,memory,network,disk,diskIO", "--profiling=false"]`.
- Estado: running / healthy; OOMKilled=false.
- Healthcheck: `{"Test": ["CMD-SHELL", "wget -q -O /dev/null http://127.0.0.1:8080/healthz"], "Interval": 15000000000, "Timeout": 5000000000, "StartPeriod": 30000000000, "Retries": 5}`.
- Dependencia Compose: docker_socket_proxy healthy.
- Mounts no secretos: `/` → `/rootfs` RO; `/sys` → `/sys` RO; `/var/lib/docker` → `/var/lib/docker` RO.

### docker_socket_proxy

- Nombre: `mobile-support-tickets-prueba-docker-docker_socket_proxy-1`; ID: `07fc501e4c02a9893cd96f10a8deef84ceb40c25e6dcc17510a0eabaf1935070`.
- Image ID: `sha256:a14e639cf2a202e87bb83f21ff041885098f295dbbbb18e2f3a8f078f90dfdcc`.
- Tags: `tecnativa/docker-socket-proxy:v0.5.0`.
- Digest: `tecnativa/docker-socket-proxy@sha256:1f5038b54f06c3e18422902cf00ba21803d1c97805aae032e5e6673d532d3459`.
- Redes: `mobile-support-tickets-prueba-docker_motor_docker`.
- Entrypoint: `["haproxy", "-W", "-db", "-f", "/etc/haproxy/monitoring.cfg"]`; comando: `null`.
- Estado: running / healthy; OOMKilled=false.
- Healthcheck: `{"Test": ["CMD-SHELL", "wget -q -O /dev/null http://127.0.0.1:2375/_ping"], "Interval": 15000000000, "Timeout": 5000000000, "StartPeriod": 30000000000, "Retries": 5}`.
- Dependencia Compose: sin depends_on explícito; ver dependencia funcional en arquitectura.
- Mounts no secretos: `/var/run/docker.sock` → `/var/run/docker.sock` RO; `/home/econt/practica/mobile-support-tickets/infra/monitoring/docker_proxy/haproxy.cfg` → `/etc/haproxy/monitoring.cfg` RO.

### grafana

- Nombre: `mobile-support-tickets-prueba-docker-grafana-1`; ID: `a5a421c1132a1bee319ec5e8d99acfc5a39f653ce8180bb36c1b0b125d426b90`.
- Image ID: `sha256:45900b2eda7da0cbda80b9025e446147d9085fee71675ba86a48a1cad34e4c8a`.
- Tags: `grafana/grafana:13.2.4`.
- Digest: `grafana/grafana@sha256:dbbc38ea21103cefb50396340cd88afec779c7e070b0a7bf5a75b4ce46651d3f`.
- Redes: `mobile-support-tickets-prueba-docker_monitoreo`.
- Entrypoint: `["/run.sh"]`; comando: `null`.
- Estado: running / healthy; OOMKilled=false.
- Healthcheck: `{"Test": ["CMD-SHELL", "wget -q -O /dev/null http://127.0.0.1:3000/api/health"], "Interval": 15000000000, "Timeout": 5000000000, "StartPeriod": 30000000000, "Retries": 5}`.
- Dependencia Compose: prometheus healthy.
- Mounts no secretos: `mobile-support-tickets-prueba-docker_datos_grafana` → `/var/lib/grafana` RW; `/home/econt/practica/mobile-support-tickets/infra/monitoring/grafana/dashboards` → `/var/lib/grafana/dashboards` RO; `/home/econt/practica/mobile-support-tickets/infra/monitoring/grafana/provisioning` → `/etc/grafana/provisioning` RO.
- Credenciales externas RO según Compose; contenido privado excluido del inventario.

### postgres

- Nombre: `mobile-support-tickets-prueba-docker-postgres-1`; ID: `cd93e3357bac9dad5cddc84b5d26130eeedf731610a15b390d67dc274b681363`.
- Image ID: `sha256:327daa8fae7178d61f93142f146b098467b345e10997b9eb79f63bd58e5c8f3c`.
- Tags: `postgres:17`.
- Digest: `postgres@sha256:2d2b8998d31037bf721cfdf764d76ba74171b4fab3431b7f72c27c56ddbdf9e3`.
- Redes: `mobile-support-tickets-prueba-docker_base_datos`.
- Entrypoint: `["docker-entrypoint.sh"]`; comando: `["postgres"]`.
- Estado: running / healthy; OOMKilled=false.
- Healthcheck: `{"Test": ["CMD-SHELL", "pg_isready -U \"${POSTGRES_USER}\" -d \"${POSTGRES_DB}\""], "Interval": 5000000000, "Timeout": 5000000000, "StartPeriod": 10000000000, "Retries": 12}`.
- Dependencia Compose: sin depends_on explícito; ver dependencia funcional en arquitectura.
- Mounts no secretos: `mobile-support-tickets-prueba-docker_datos_postgres` → `/var/lib/postgresql/data` RW.
- Credenciales externas RO según Compose; contenido privado excluido del inventario.

### postgres_exporter

- Nombre: `mobile-support-tickets-prueba-docker-postgres_exporter-1`; ID: `5e12f2773f949336ac4876440d88f856d9234385e56b2a8ab770524cc99692a7`.
- Image ID: `sha256:1dcb30ec16e2379751c9101006ac4e7b13ddfb5ec494bac3845a99bcad0aa141`.
- Tags: `quay.io/prometheuscommunity/postgres-exporter:v0.20.1`.
- Digest: `quay.io/prometheuscommunity/postgres-exporter@sha256:ac5ec343104fae0e2d84a27bb8d69b38430a11910c5382cad85d478d2bab713e`.
- Redes: `mobile-support-tickets-prueba-docker_base_datos`, `mobile-support-tickets-prueba-docker_monitoreo`.
- Entrypoint: `["/bin/postgres_exporter"]`; comando: `["--no-collector.wal", "--no-collector.stat_statements", "--no-collector.stat_activity_autovacuum", "--collector.stat_checkpointer"]`.
- Estado: running / healthy; OOMKilled=false.
- Healthcheck: `{"Test": ["CMD-SHELL", "wget -q -O- http://127.0.0.1:9187/metrics | grep -q '^pg_up 1$'"], "Interval": 15000000000, "Timeout": 5000000000, "StartPeriod": 30000000000, "Retries": 5}`.
- Dependencia Compose: sin depends_on explícito; ver dependencia funcional en arquitectura.
- Mounts no secretos: ninguno adicional a credenciales externas cuando corresponde.
- Credenciales externas RO según Compose; contenido privado excluido del inventario.

### postgres_exporter_lectura

- Nombre: `mobile-support-tickets-prueba-docker-postgres_exporter_lectura-1`; ID: `43e082759188daceaaeb0e01b8480090de7e42627207428064a32e18d519e5bf`.
- Image ID: `sha256:1dcb30ec16e2379751c9101006ac4e7b13ddfb5ec494bac3845a99bcad0aa141`.
- Tags: `quay.io/prometheuscommunity/postgres-exporter:v0.20.1`.
- Digest: `quay.io/prometheuscommunity/postgres-exporter@sha256:ac5ec343104fae0e2d84a27bb8d69b38430a11910c5382cad85d478d2bab713e`.
- Redes: `mobile-support-tickets-prueba-docker_base_datos`, `mobile-support-tickets-prueba-docker_monitoreo`.
- Entrypoint: `["/bin/postgres_exporter"]`; comando: `["--no-collector.wal", "--no-collector.stat_statements", "--no-collector.stat_activity_autovacuum", "--collector.stat_checkpointer", "--collector.stat_wal_receiver"]`.
- Estado: running / healthy; OOMKilled=false.
- Healthcheck: `{"Test": ["CMD-SHELL", "wget -q -O- http://127.0.0.1:9187/metrics | grep -q '^pg_up 1$'"], "Interval": 15000000000, "Timeout": 5000000000, "StartPeriod": 30000000000, "Retries": 5}`.
- Dependencia Compose: sin depends_on explícito; ver dependencia funcional en arquitectura.
- Mounts no secretos: ninguno adicional a credenciales externas cuando corresponde.
- Credenciales externas RO según Compose; contenido privado excluido del inventario.

### postgres_lectura

- Nombre: `mobile-support-tickets-prueba-docker-postgres_lectura-1`; ID: `dee68d6b5af22c1070f98acc220ac082be58c7c3684c26e155530975f09f7dea`.
- Image ID: `sha256:327daa8fae7178d61f93142f146b098467b345e10997b9eb79f63bd58e5c8f3c`.
- Tags: `postgres:17`.
- Digest: `postgres@sha256:2d2b8998d31037bf721cfdf764d76ba74171b4fab3431b7f72c27c56ddbdf9e3`.
- Redes: `mobile-support-tickets-prueba-docker_base_datos`.
- Entrypoint: `["sh", "/opt/replicacion/iniciar_standby.sh"]`; comando: `null`.
- Estado: running / healthy; OOMKilled=false.
- Healthcheck: `{"Test": ["CMD", "sh", "/opt/replicacion/salud_standby.sh"], "Interval": 10000000000, "Timeout": 5000000000, "StartPeriod": 60000000000, "Retries": 6}`.
- Dependencia Compose: sin depends_on explícito; ver dependencia funcional en arquitectura.
- Mounts no secretos: `/home/econt/practica/mobile-support-tickets/infra/replicacion` → `/opt/replicacion` RO; `mobile-support-tickets-prueba-docker_datos_postgres_lectura` → `/var/lib/postgresql/data` RW.
- Credenciales externas RO según Compose; contenido privado excluido del inventario.

### prometheus

- Nombre: `mobile-support-tickets-prueba-docker-prometheus-1`; ID: `c1991829a303ac0c317fdfe85aef3dbcc2da6eff583a782b8cfe5de8d9af8daa`.
- Image ID: `sha256:66416213a3b43651d3521acc3987277b4f97ad0ae29acc581f910ef9bd3959bd`.
- Tags: `prom/prometheus:v3.15.0`.
- Digest: `prom/prometheus@sha256:efd719c99d83b060d9daefdcf00360461adf279f45ef5391f8d111892118753e`.
- Redes: `mobile-support-tickets-prueba-docker_monitoreo`.
- Entrypoint: `["/bin/prometheus"]`; comando: `["--config.file=/etc/prometheus/prometheus.yaml", "--storage.tsdb.path=/prometheus", "--storage.tsdb.retention.time=7d"]`.
- Estado: running / healthy; OOMKilled=false.
- Healthcheck: `{"Test": ["CMD-SHELL", "wget -q -O /dev/null http://127.0.0.1:9090/-/ready"], "Interval": 15000000000, "Timeout": 5000000000, "StartPeriod": 30000000000, "Retries": 5}`.
- Dependencia Compose: sin depends_on explícito; ver dependencia funcional en arquitectura.
- Mounts no secretos: `/home/econt/practica/mobile-support-tickets/infra/monitoring/prometheus` → `/etc/prometheus` RO; `mobile-support-tickets-prueba-docker_datos_prometheus` → `/prometheus` RW.

### supervision_metricas

- Nombre: `mobile-support-tickets-prueba-docker-supervision_metricas-1`; ID: `41252b854bd81add41ac73c30583330b50d79a2fd44a87b77177c40a7c52414c`.
- Image ID: `sha256:30ecbe1509090b38ef3260f3609d64d8261230464eaa4d235901db496e9647fb`.
- Tags: `busybox:1.37.0`.
- Digest: `busybox@sha256:bdf57e528e45e4433820e045b29b4597825a1c9e38353532d90a01445013f82e`.
- Redes: `mobile-support-tickets-prueba-docker_monitoreo`.
- Entrypoint: `["busybox", "httpd", "-f", "-p", "9199", "-h", "/metricas"]`; comando: `null`.
- Estado: running / healthy; OOMKilled=false.
- Healthcheck: `{"Test": ["CMD-SHELL", "wget -q -O /dev/null http://127.0.0.1:9199/supervisor.prom"], "Interval": 15000000000, "Timeout": 3000000000, "Retries": 3}`.
- Dependencia Compose: sin depends_on explícito; ver dependencia funcional en arquitectura.
- Mounts no secretos: `/home/econt/.local/state/tickets-supervision/metricas` → `/metricas` RO.

## Propósito y archivos

API REST/JWT/enrutamiento; postgres primario RW; postgres_lectura standby readonly; Prometheus series/reglas; Grafana visualización; cAdvisor recursos; Blackbox disponibilidad; exporters estadísticas; SocketProxy ACL; supervision_metricas HTTP del archivo supervisor.

- compose.yaml: base API tickets-api:local/primario.
- compose.api-lectura.yaml: imagen activa tickets-api:fase12-3 y dos conexiones.
- compose.replica.yaml: volumen/entrypoint/imagen standby.
- compose.monitoring.yaml: siete servicios de monitoreo, ambos exporters incluidos.
- compose.supervision.yaml: métricas BusyBox.
- compose.api-anterior.yaml: alternativa histórica, requiere imagen local previa no distribuida.
- compose.recursos.yaml: propuestas no aplicadas salvo Grafana ya persistido en monitoring. No incluirlo en arranque normal.

Los puertos internos se determinaron por comandos/configuración, no solo EXPOSE de imagen. Los bindings host reflejan inspect. Healthcheck JSON usa nanosegundos para interval/timeout/start_period. Rutas de mounts no secretos dependen de este host; contenido de los cuatro volúmenes no se publica.


## Bases de compilación Microsoft y alternativas locales

- `mcr.microsoft.com/dotnet/sdk:10.0`: image ID `sha256:9cd0d6fa04def99891bf4d5a29eb9a3878b6041f9cc25cb389ea0df2177d23fd`; RepoDigests `mcr.microsoft.com/dotnet/sdk@sha256:0d99ebf1ccad15037b5c98c9fe8979d6b8dbac23812feae2277a0b277b5c5ffa`.
- `mcr.microsoft.com/dotnet/aspnet:10.0`: referencia real del Dockerfile; no disponible en caché local al auditar, digest no inventado.

Las bases anteriores pertenecen a Microsoft Container Registry. No son servicios Compose. Imágenes locales API disponibles (no constituyen garantía de respaldo/configuración):

```text
tickets-api:fase12-3 218135d79d24
tickets-api:antes-fase12-3 e3c7d068a137
tickets-api:local e3c7d068a137
```
