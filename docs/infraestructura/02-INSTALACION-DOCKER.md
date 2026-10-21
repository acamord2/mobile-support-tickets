# Instalación por fases

**No se probó un clon limpio ejecutando toda la instalación.** Comandos revisados estáticamente y componentes actuales validados. No repetir preparación SQL/HBA sobre la instalación existente.

## Requisitos y compatibilidad

Entorno probado: Windows11, Ubuntu20.04.6 WSL2, PID1 systemd, Docker27.3.1, Compose2.29.7, cgroupsv2/Linux amd64; Git, Python3.8+ y PyYAML. El build usa SDK .NET10 dentro de Docker; PostgreSQL17 se ejecuta en contenedor, no requiere un segundo servidor apt. Flutter/Android SDK están en Windows. SSH requiere binario sshd existente y cliente OpenSSH Windows.

La [documentación Docker actual](https://docs.docker.com/engine/install/ubuntu/) ya no enumera Ubuntu20.04 entre versiones soportadas. No afirmar que instalar el último paquete en focal reproduzca este entorno. Para otra máquina elegir una distribución soportada o paquetes históricos verificados con evaluación de soporte; no actualizar esta VM automáticamente.

En una distribución soportada nueva, configurar apt oficial tras revisar esa guía:

```sh
sudo apt-get update
sudo apt-get install ca-certificates curl git python3 python3-yaml
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
. /etc/os-release
printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu %s stable\n' "$(dpkg --print-architecture)" "$VERSION_CODENAME" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
sudo apt-get update
apt-cache madison docker-ce docker-ce-cli docker-compose-plugin
```

Seleccionar versiones disponibles aprobadas antes de instalar docker-ce, docker-ce-cli, containerd.io, docker-buildx-plugin y docker-compose-plugin. No eliminar paquetes ni cambiar grupos del host actual. Grupo docker equivale a control administrativo del host. Comprobar docker version, docker compose version, docker info y ps -p1 -o comm=.

## Clon y secretos

```sh
mkdir -p /home/econt/practica
cd /home/econt/practica
git clone --branch prueba_docker https://github.com/acamord2/mobile-support-tickets.git
cd mobile-support-tickets
sh infra/operacion/compose_proyecto.sh config --quiet
```

[compose_proyecto.sh](../../infra/operacion/compose_proyecto.sh) combina compose.yaml, compose.api-lectura.yaml, compose.replica.yaml, compose.monitoring.yaml y compose.supervision.yaml; perfiles replicacion, monitoreo, monitoreo_replica y supervision. Excluye recursos propuestos e imagen anterior. No volcar config completo si se inyectan valores privados.

Preparar secretos fuera de Git según [plantillas](plantillas/README.md) y [seguridad](10-SEGURIDAD-Y-SECRETOS.md), sin copiar los reales del despliegue. API requiere archivo externo dos conexiones y JWT; Escritura/DefaultConnection deben coincidir y Lectura debe usar consultor_api. Permisos de lectura efectiva: API1654, PostgreSQL999, Grafana472 y exporters65534; revisar también recorrido de directorios. Variables/rutas seguras en .env.example. Development/HTTP es solo práctica local; producción exige otra política.

## Generación segura para un clon nuevo

[preparar_archivos_externos.py](../../infra/operacion/preparar_archivos_externos.py) resuelve la generación local sin publicar valores. Requiere root para propietarios, destino externo inexistente y padre ya aprobado. No ejecutado en esta fase; el destino actual existe y se rechazaría.

```sh
# SOLO instalación nueva, nunca sobre secretos actuales:
sudo install -d -m 0755 /var/lib/mobile-support-tickets
sudo python3 infra/operacion/preparar_archivos_externos.py --destino /var/lib/mobile-support-tickets/prueba_docker --preparar
```

Genera postgres.key, secrets.json legado, password Grafana/monitor, replicador_lectura.key y passfile999. No crea consultor: preparar_consultor.py genera su credencial/archivo de dos conexiones después del esquema. No crea roles, HBA, evidencias falsas de restauración ni servicios. Ante fallo parcial, inspeccionar sin borrar/reintentar automáticamente. Releer permisos antes de usar: las rutas deben ser accesibles solo según UID previsto. Credencial de replicación para SQL debe recibirse por canal privado desde su archivo, nunca copiarse a un argumento.

## Build y descarga previa

```sh
docker build -t tickets-api:fase12-3 ./api
docker image inspect tickets-api:fase12-3 --format '{{.Id}}'
```

[Dockerfile](../../api/Dockerfile): sdk:10.0 restaura/publica Tickets.Api.csproj; aspnet:10.0 ejecuta Tickets.Api.dll como usuario sin privilegios en HTTP8080. [.dockerignore](../../api/.dockerignore) excluye secretos/bin/obj y permite fuentes/configuración base. Bases Microsoft móviles: no garantiza idéntico image ID futuro.

Pull_policy never exige descargar antes. Para PostgreSQL nuevo fijar ambos a la misma imagen del inventario; no retaggear instalaciones en uso:

```sh
docker pull postgres@sha256:2d2b8998d31037bf721cfdf764d76ba74171b4fab3431b7f72c27c56ddbdf9e3
# Solo instalación nueva:
docker tag postgres@sha256:2d2b8998d31037bf721cfdf764d76ba74171b4fab3431b7f72c27c56ddbdf9e3 postgres:17
docker pull prom/prometheus:v3.15.0
docker pull grafana/grafana:13.2.4
docker pull ghcr.io/google/cadvisor:0.60.6
docker pull quay.io/prometheus/blackbox-exporter:v0.29.0
docker pull quay.io/prometheuscommunity/postgres-exporter:v0.20.1
docker pull tecnativa/docker-socket-proxy:v0.5.0
docker pull busybox@sha256:bdf57e528e45e4433820e045b29b4597825a1c9e38353532d90a01445013f82e
```

Comparar RepoDigests con [inventario](09-INVENTARIO-DOCKER.md) antes de arrancar; no continuar si un tag cambió sin revisión.

## Orden de instalación NUEVA

1. Secretos externos nuevos; verificar que nombres de volúmenes no pertenecen a otra instalación.
2. Arrancar solo primario e instalar tres scripts sin demo con ON_ERROR_STOP.
3. Crear roles mínimos mediante scripts auditados, HBA real y SCRAM. Es preparación administrativa manual, no automática de API.
4. Respaldo y ensayo aislado auténtico; marca externa verificada. Revisar WAL/retención/HBA antes de standby.
5. Arrancar standby y comprobar rol físico, streaming y permisos.
6. Arrancar API dos conexiones.
7. Preparar propiedad/permisos de volúmenes Prometheus/Grafana antes de iniciar monitoreo; no chown recursivo sobre datos existentes.
8. Preparar estado inicial supervisor solo en instalación nueva y activar métricas/systemd con autorización.

```sh
sh infra/operacion/compose_proyecto.sh up -d --no-deps postgres
for archivo in DATABASE.sql STORED_PROCEDURES.sql VISTAS.sql; do
  sh infra/operacion/compose_proyecto.sh exec -T postgres psql -X -v ON_ERROR_STOP=1 -U tickets_practica -d tickets_db < "database/PostgreSQL/$archivo" || exit 1
done
# DETENERSE hasta completar roles/HBA/respaldo de los pasos3-4.
sh infra/operacion/compose_proyecto.sh up -d --no-deps postgres_lectura
sh infra/operacion/compose_proyecto.sh up -d --no-deps api
sh infra/operacion/compose_proyecto.sh up -d --no-deps docker_socket_proxy cadvisor blackbox postgres_exporter postgres_exporter_lectura prometheus grafana
# Solo después de crear directorio externo con supervisor.prom válido:
sh infra/operacion/compose_proyecto.sh up -d --no-deps supervision_metricas
```

No ejecutar bloques de corrido sin verificaciones. --no-deps no prepara dependencias y no evita recrear el servicio solicitado. DATOS_PRUEBA/BD_COMPLETA no forman parte de la instalación sin demo.

## Comandos y diferencias

| Comando | Efecto |
|---|---|
| build | Compila imagen, no despliega |
| pull | Descarga, no cambia contenedor activo |
| up | Reconcilia; puede crear/recrear |
| start | Arranca existente detenido |
| stop | Detención manual, semántica distinta del fallo inesperado |
| restart | Reinicia mismo contenedor, no aplica todos los cambios Compose |
| down | Retira contenedores/redes; no mantenimiento rutinario |

Nunca down -v/prune como reparación. Inspección: wrapper ps, logs --tail=100 SERVICIO; docker image ls; docker network inspect RED; docker volume inspect VOLUMEN. Ver [lista operativa](08-OPERACION-Y-DIAGNOSTICO.md). Ningún comando de esta fase creó datos de negocio.
