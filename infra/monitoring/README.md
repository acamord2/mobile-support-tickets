> Estado consolidado vigente: [manual de infraestructura](../../docs/infraestructura/README.md). Esta nota conserva antecedentes y propuestas de su fase; revisar el manual actual antes de operar.

# Observabilidad local de la práctica Docker

## Estado verificado

Práctica local en Ubuntu 20.04.6 LTS sobre WSL2, rama prueba_docker. API y PostgreSQL funcionan con compose.yaml; PostgreSQL, Prometheus y Grafana están healthy. La API no tiene healthcheck Docker definido: su disponibilidad se comprueba mediante HTTP 200 de /api/health/database, con database=connected.

El monitoreo tiene nueve targets UP y cuatro dashboards con treinta y ocho paneles que recibieron datos reales: docker_local (12), disponibilidad_local (14) y plataforma_local (4), más replica_local (8). Estas son comprobaciones realizadas el 2026-10-20, no una garantía del estado futuro; repetir comprobar.py para confirmar el estado actual.

Ningún servicio de monitoreo publica puertos Docker al host. El único acceso de navegador previsto es el proxy temporal Windows en 127.0.0.1:13000, descrito en [ACCESO_PRIVADO.md](ACCESO_PRIVADO.md). adb reverse tcp:5263 tcp:5263 de Flutter se conserva. La replicación está preparada y todavía no iniciada.

El rol monitor_postgres ya existe: autenticación TCP SCRAM validada, CONNECT y pg_read_all_stats, sin privilegios de escritura en las ocho tablas. No volver a ejecutar su creación durante un arranque normal.

## Versiones comprobadas

- Prometheus v3.15.0, imagen prom/prometheus:v3.15.0.
- Grafana 13.2.4, imagen grafana/grafana:13.2.4.
- cAdvisor 0.60.6, imagen ghcr.io/google/cadvisor:0.60.6.
- PostgreSQL Exporter v0.20.1, imagen quay.io/prometheuscommunity/postgres-exporter:v0.20.1.
- Blackbox Exporter v0.29.0, imagen quay.io/prometheus/blackbox-exporter:v0.29.0.
- Proxy Docker v0.5.0, imagen tecnativa/docker-socket-proxy:v0.5.0 (el prefijo v es necesario).

Se verificaron tags publicados, imágenes linux/amd64, usuarios, digest y flags reales de los binarios. versiones.json conserva esos metadatos. No se usa latest. El primario es PostgreSQL 17 y el exporter declara CI con PostgreSQL 17. El host tiene Engine 27.3.1, API 1.47 y cgroups v2/systemd. Se comprobaron métricas reales de CPU, memoria, red y disco de cAdvisor/WSL2. comprobar.py detecta series ausentes; repetirlo tras cambios.

Fuentes oficiales:
- https://github.com/prometheus/prometheus/releases/tag/v3.15.0
- https://github.com/grafana/grafana/releases/tag/v13.2.4
- https://github.com/google/cadvisor/releases/tag/v0.60.6
- https://github.com/prometheus-community/postgres_exporter/tree/v0.20.1
- https://github.com/prometheus/blackbox_exporter/releases/tag/v0.29.0
- https://github.com/Tecnativa/docker-socket-proxy/tree/v0.5.0

## Funcionamiento

Prometheus scrapea cada 15 segundos y conserva TSDB 7 días en datos_prometheus. Grafana utiliza SQLite y configuración persistente en datos_grafana, datasource Prometheus provisionado y cuatro dashboards activos (Docker, disponibilidad, plataforma Prometheus y réplica) sin descargas externas. El intervalo de dashboards es 15 segundos. Las reglas de alerta se ven en Prometheus; no se configuró Alertmanager ni envío de notificaciones.

Docker: CPU (% de un núcleo, puede superar 100 con varios núcleos), RAM activa, red RX/TX, disco observado y E/S, contenedores presentes, estado y tendencias. cAdvisor ve el motor completo, no solo este proyecto. No mide todo Windows. El número de contenedores es el observado recientemente, no un inventario exacto de todos los contenedores detenidos. Las sondas Docker de API/PostgreSQL sí consultan State.Running y Health.Status. Un contenedor terminado puede desaparecer de las series cAdvisor; no inferir su exit code. El uso de filesystem depende del driver: no representa por sí solo todos los volúmenes o el espacio Windows. La comprobación operativa exige CPU, memoria, red y disco disponibles.

API/PostgreSQL: Blackbox usa GET http://api:8080/api/health/database y exige HTTP 200 y status=ok/database=connected. No supone /metrics en la API. Muestra latencia, disponibilidad 1h, códigos HTTP, conexiones, transacciones, tamaño de base, caché, deadlocks y alertas. up del exporter no equivale a pg_up: el segundo comprueba acceso SQL.

Réplica: exporter activo con perfil monitoreo_replica separado y file_sd habilitado. La plantilla original sigue conservada fuera del provisioning. No se incluye ni ejecuta compose.replica.yaml. No activar hasta que la réplica exista y su HBA autorice explícitamente el monitoreo; actualmente HBA admite monitor_postgres por SCRAM desde la red privada. El rol de monitoreo se replicaría físicamente desde el primario; no crearlo de nuevo en el standby. La antigüedad del último replay no es retraso si no hay nuevas escrituras.

## Redes, puertos y seguridad

monitoreo y motor_docker son redes internal:true. Grafana, Prometheus, exporters, cAdvisor y Socket Proxy no publican puertos al host. Grafana -> Prometheus y Prometheus -> recolectores comparten monitoreo. cAdvisor y Blackbox acceden al proxy por motor_docker; PostgreSQL Exporter y Blackbox se unen a base_datos existente para PostgreSQL y API, sin modificar sus servicios.

El acceso Windows bajo demanda se documenta únicamente en ACCESO_PRIVADO.md. No añadir publicaciones Docker para acceder. La prueba LAN del proxy debe realizarse mientras localhost funciona; no se certifica por inferencia a partir de un puerto cerrado.

cAdvisor no recibe directamente docker.sock. El proxy lo monta ro y permite exclusivamente GET/HEAD para _ping, version, info, events, listado e inspección de contenedores. Niega POST, PUT, DELETE, logs, archive y exec. Un socket ro no es una API de solo lectura: la limitación real la aplica HAProxy. El proxy es un componente de confianza administrativa. cAdvisor requiere acceso amplio a host PID/cgroups, rootfs/sys/Docker root en ro y capacidades SYS_ADMIN/DAC_READ_SEARCH; no se usa privileged:true. Se enmascaran run, home, root y el directorio de secretos bajo rootfs para reducir exposición accidental. Esto no convierte cAdvisor en una frontera fuerte frente a un proceso comprometido: SYS_ADMIN y los archivos Docker son sensibles. No usar imágenes no confiables. No hay montaje de /dev/kmsg, que puede no existir en WSL.

No se exportan variables de entorno como etiquetas; solo project/service de Compose están permitidas. No habilitar perfiles de debug o logging de cuerpos/SQL. Los datos de observabilidad pueden revelar nombres internos y carga del resto del motor.

## Secretos y usuario PostgreSQL

Directorio externo: /var/lib/mobile-support-tickets/prueba_docker/monitoring (0711).
- grafana_admin.key: dueño 472:472, modo 0400. GF_SECURITY_ADMIN_PASSWORD__FILE. Usuario inicial admin_monitoreo.
- postgres_monitor.key: dueño 65534:65534, modo 0400. DATA_SOURCE_PASS_FILE. Rol activo monitor_postgres.

Ambos montajes son de solo lectura y create_host_path:false. Se comprobó lectura efectiva bajo cada UID y ausencia de permiso de escritura. No reutilizan claves de aplicación o replicación. variables.example solo contiene rutas. Las reglas Git actuales ignoran .env, *.key y secretos locales; los valores reales están además fuera del repositorio. La contraseña inicial de Grafana solo se usa al inicializar su base: cambiar el archivo después no rota automáticamente la cuenta persistida. Para consultar la credencial, usar un canal privado local con sudo; no copiarla al chat, terminal compartida ni logs.

crear_usuario.sql conserva el procedimiento de reconstrucción con LOGIN, CONNECT a tickets_db y pg_read_all_stats, con NOREPLICATION, NOSUPERUSER, NOCREATEDB, NOCREATEROLE, NOBYPASSRLS, límite de 3 conexiones, transacciones de solo lectura y timeout 5s. No concede SELECT sobre Users ni crea extensiones, funciones o tablas. pg_read_all_stats permite estadísticas de todo el clúster y puede ver consultas: tratar esa cuenta como sensible. No se concede pg_monitor porque incluye capacidades adicionales innecesarias. El collector de textos de consultas está desactivado.

El instalador postgres/autorizar_usuario.py se conserva para reconstrucciones autorizadas. Usa el archivo externo, SCRAM y una sesión con logging SQL deshabilitado. Una colisión con un rol existente aborta; no ejecutarlo como parte del arranque ni para rotar contraseñas. postgres/verificar_privilegios.sql permite comprobar atributos y ausencia de escritura sin modificar tablas. default_transaction_read_only es solo un valor predeterminado; la barrera real son los permisos efectivos. TEMP heredado de PUBLIC permite tablas temporales, no escritura en tablas de aplicación.

## Validación sin arrancar servicios

Desde /home/econt/practica/mobile-support-tickets:

```sh
python3 infra/monitoring/validar.py
sudo python3 infra/monitoring/validar.py --permisos
```

El validador compara API/primario con compose.yaml, valida YAML/JSON, datasource, dashboards, imágenes fijadas, PromQL con promtool, reglas y pruebas de alertas, Blackbox --config.check, HAProxy -c, redes internas y ausencia de publicaciones de monitoreo. Usa solo contenedores temporales de validación, --rm y --network none; no arranca servicios. No ejecuta SQL. Grafana no proporciona aquí una comprobación offline equivalente a importar los dashboards: el provisioning y las consultas contra datos reales se prueban después del arranque.

## Operación y arranque explícito

Los servicios ya están activos. Para consultar estado y métricas no hace falta reiniciarlos. El comando up se conserva para un arranque solicitado expresamente, no como paso de validación.

```sh
dcmon() {
  docker compose --env-file .env.example -f compose.yaml     -f compose.monitoring.yaml --profile monitoreo "$@"
}
dcmon config --quiet
# Solo cuando se solicite arrancar o aplicar configuración; el rol ya existe:
dcmon up -d --no-deps docker_socket_proxy cadvisor blackbox postgres_exporter prometheus grafana
dcmon ps
sudo python3 infra/monitoring/comprobar.py
```

--no-deps y la lista explícita evitan iniciar/recrear API o PostgreSQL. No usar un up global. La comprobación accede desde WSL a las IP privadas actuales y usa la credencial externa en memoria para Grafana; no imprime contraseñas ni tokens.

Para verificar los privilegios existentes, sin crear roles:

```sh
docker compose --env-file .env.example exec -T postgres psql -X -v ON_ERROR_STOP=1 -U tickets_practica -d tickets_db < infra/monitoring/postgres/verificar_privilegios.sql
```

Prometheus se consulta desde Grafana o desde WSL por su dirección Docker actual. No se documentan puertos host para su interfaz. El procedimiento de navegador está en ACCESO_PRIVADO.md.

Las seis unidades tienen restart:unless-stopped. Un healthcheck unhealthy NO reinicia automáticamente un contenedor en Compose: restart actúa al salir el proceso. Investigar fallos; no crear reinicios en bucle que oculten permisos incorrectos.

## Exporter de réplica activo: procedimiento de reconstrucción

Ya está activo. Los comandos siguientes solo sirven para reconstrucción autorizada, con standby/HBA y comprobaciones LSN válidas:

```sh
# Cambia únicamente el archivo de descubrimiento de Prometheus.
cp infra/monitoring/prometheus/targets/postgres_replica.example.json    infra/monitoring/prometheus/targets/postgres_replica.json
# Añade solo el exporter opcional; NO incluye compose.replica.yaml.
docker compose --env-file .env.example -f compose.yaml   -f compose.monitoring.yaml --profile monitoreo --profile monitoreo_replica   up -d --no-deps postgres_exporter_lectura
```

## Recursos estimados y reversión

Para un motor pequeño: 0.5-1.2 GiB de RAM y aproximadamente 1-3 GiB de disco TSDB por 7 días, más imágenes y base Grafana. Son estimaciones; dependen de contenedores, series, interfaces y actividad. Límites configurados suman unos 1952 MiB y 3.4 CPU para las seis unidades, no reservados. Prometheus 768 MiB, Grafana 512, cAdvisor 384, exporter 128, Blackbox 96 y proxy 64. No se fija límite de tamaño TSDB que recorte silenciosamente los 7 días; vigilar espacio. El exporter de réplica añadiría 128 MiB.

Para revertir, detener/remover SOLO las seis unidades de monitoreo con dcmon stop y dcmon rm de sus nombres explícitos, conservando datos_prometheus/datos_grafana. Nunca usar down -v. El rol dedicado se retiraría únicamente con autorización y después de parar sus exporters. API, primario, datos, contraseñas existentes y adb reverse no cambian.

## Dashboards activos y recuperación

La plantilla grafana/plantillas/replica.json está fuera del provisioning activo: no se presenta como operativa sin réplica. El tercer dashboard activo es plataforma_local, con cuatro paneles de Prometheus. Se conservan los3 dashboards originales y30 paneles; se añaden8 de réplica; comprobar.py exige datos en cada consulta de cada panel y espera al menos dos scrapes para tasas. Nunca considerar una serie ausente como un cero válido. Activar la plantilla de réplica más adelante será una etapa separada.


El respaldo /home/econt/backups/tickets/antes_replica_20261020_134144 superó una restauración aislada con PostgreSQL 17: ocho tablas, get_user_by_username, agenda_tickets, cuatro roles de aplicación, cinco usuarios y las otras seis tablas vacías. No se modificó el primario. El contenedor del ensayo, sin red ni puertos y con almacenamiento independiente tmpfs, se eliminó tras comprobar su identidad. Las sumas SHA256 del conjunto habían sido verificadas. El respaldo incluye roles globales sensibles: no mostrar su contenido ni copiarlo a Git.

Los procedimientos de respaldo nuevo, comprobación y recuperación están en [../replicacion/README.md](../replicacion/README.md). ensayar_respaldo.py se conserva SIN CAMBIOS, pero requiere endurecimiento antes de reutilizarlo: tiene conteos fijos y comprobaciones de limpieza más limitadas que las empleadas en el ensayo autorizado. No tratar su ejecución actual como reproducción completa de aquel ensayo ni ejecutarlo automáticamente.

Incidencia de arranque resuelta: Prometheus v3.15.0 rechazaba --web.enable-lifecycle=false con «unexpected false». Se retiró ese argumento; lifecycle quedó deshabilitado por defecto. No se cambiaron permisos ni datos del volumen. Conservar esta corrección al revisar el Compose.
