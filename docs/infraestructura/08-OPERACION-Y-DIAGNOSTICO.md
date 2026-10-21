# Operación y diagnóstico

Trabajar en /home/econt/practica/mobile-support-tickets como econt salvo validadores que requieren leer credenciales externas protegidas. [Wrapper](../../infra/operacion/compose_proyecto.sh) usa los cinco archivos activos, excluyendo propuestas e imagen anterior. Base-only up api podría revertir imagen/secreto: no usarlo para el despliegue actual.

## Consultas seguras

```sh
sh infra/operacion/compose_proyecto.sh config --quiet
sh infra/operacion/compose_proyecto.sh ps
curl --fail --silent --show-error http://127.0.0.1:5263/api/health/database
curl --fail --silent --show-error http://127.0.0.1:5263/api/health/disponibilidad
systemctl is-active tickets-supervisor.service
systemctl is-enabled tickets-supervisor.service
sudo python3 infra/supervision/comprobar_fase14.py --autorreparacion 1
python3 infra/lectura/comprobar_permisos.py
sh infra/operacion/compose_proyecto.sh logs --tail=100 api
sh infra/operacion/compose_proyecto.sh logs --tail=100 postgres_lectura
sh infra/operacion/compose_proyecto.sh logs --tail=100 prometheus
sudo journalctl -u tickets-supervisor.service -n 50 --no-pager
docker network inspect mobile-support-tickets-prueba-docker_base_datos
docker volume inspect mobile-support-tickets-prueba-docker_datos_postgres
ss -lnt
```

Revisar logs localmente y sanear antes de compartir. No imprimir JWT/respuestas de negocio/inspect completo. [Consultas SQL/WAL](03-POSTGRESQL-REPLICACION.md) y [targets/paneles](04-MONITOREO-GRAFANA.md). Comprobar_permisos consulta catálogos, no DML. API no tiene healthcheck Docker; running se complementa con HTTP200/databaseconnected. pg_isready no prueba todas las consultas. No ejecutar pruebas --real de API: crean registros.

## Arranque y parada ordenados

Después de iniciar Ubuntu WSL manualmente, comprobar systemd/Engine sin modificar políticas globales. Unless-stopped puede recuperar procesos previamente activos; detenidos manualmente requieren decisión explícita. Start opera solo sobre existentes; up --no-deps puede crear/recrear el servicio solicitado y exige revisar configuración/secretos/volúmenes/IDs. No up general como reparación.

Orden de arranque: principal→standby validado→API y dependencias de monitoreo→supervisión. Tras recrear un servicio autohealable, revisar/rearmar su nuevo ID explícitamente. No borrar presupuesto ni historial para aceptar identidades.

Parada planificada, NO ejecutada: mantenimiento autorizado, registrar salud/LSN; detener API para cerrar nuevas escrituras, después monitoreo/supervisor según plan y finalmente standby/primario. Cerrar accesos temporales con sus scripts si se apaga WSL. No down -v/prune/borrar slots. Stop administrativo no equivale a caída inesperada; pruebas reales exigen aprobación específica.

## Diagnóstico

| Síntoma | Verificar | Evitar |
|---|---|---|
| API503 | DB/capacidades/caché120s y logs | Promover o fingir escritura |
| API401/403 | JWT, cuenta, rol, alcance | Confundir con caída o ampliar permisos |
| Sin streaming | Emisor/receptor, slot, espacio, HBA/passfile | Borrar PGDATA/slot/repetir basebackup |
| TargetDOWN | Red común/DNS/puerto interno/timeout | Publicar exporters |
| UP con probe fallido | probe_success y SQL real | Declarar disponible por scraping |
| Grafana No data | PromQL/labels/intervalo/datasource | Sustituir por cero |
| SSH | Listener temporal/host key/PermitOpen/IP | Desactivar hostchecking/bind0.0.0.0 |
| OOM | memory.events/swap/PSI/HostConfig/host | Reiniciar repetidamente sin capacidad |
| Supervisor bloqueado | Presupuesto/cooldown/mantenimiento/ID | Borrar estado/otro observador |

## Recuperación y límites

Docker recupera salida inesperada según restart; systemd fallo del supervisor con límites; supervisor solo cinco servicios stateless. No resuelven disco/volumen inválido/corrupción/slot perdido/credencial vencida/host apagado/ID no autorizado. No failover automático.

Si Engine cae no hay servicios Docker; supervisor observa pero no lo inicia. Si WSL cae tampoco corre systemd. No hay tarea Windows de arranque. Al volver comprobar reloj, recursos, estado persistente, API, WAL, targets y paneles; reabrir accesos temporales verificados. Reinicio íntegro WSL y agotamiento real de presupuesto no tienen ensayo controlado acreditado.

No restaurar sobre primario activo. Identificar respaldo externo/SHA256/fecha-RPO/roles/config y ensayo aislado; diseñar instancia separada. No compartir/copiar PGDATA activo. Réplica no es copia histórica. MinIO/backups automáticos pendientes.

## Checklist

- Versiones/digests reales, misma imagen PostgreSQL; configuración completa válida.
- Secretos externos por UID, roles mínimos, HBA CIDR real.
- Esquema manual sin demo, volúmenes independientes, backup ensayado auténtico.
- API200, primarioRW, standbyrecovery/readonly/streaming/slot válido.
- Targets y probes correctos; cinco dashboards/50paneles con series.
- Una instancia supervisor, estado conservado y activación explícita.
- Accesos temporales loopback; puertos ajenos no atribuidos al proyecto.
