# Ampliación preparada; sin desplegar (2026-10-21)

Se conservan los cuatro dashboards/38paneles, scrape15s/retención7d, nueve targets UP y --no-collector.wal en ambos exporters. Grafana/Prometheus no se recrearon ni recargaron. Se propone un quinto dashboard separado, sin reemplazar existentes. ADB, API, SQL, HBA y slots quedan intactos.

## Métricas reales comprobadas en Prometheus

| Objetivo | PromQL base | Alcance y límite |
|---|---|---|
| Conexiones | pg_stat_database_numbackends{datname="tickets_db",job=~"postgres|postgres_replica"} | Ambos nodos; no prueba destino de SELECT por sí sola |
| Lectura disco | rate(pg_stat_database_blks_read{datname="tickets_db",job=~"postgres|postgres_replica"}[5m]) | Bloques, no bytes sin verificar block_size |
| Cache | rate(pg_stat_database_blks_hit{datname="tickets_db",job=~"postgres|postgres_replica"}[5m]) | Contadores locales; no equivale a peticiones API |
| Filas devueltas | rate(pg_stat_database_tup_returned{datname="tickets_db",job=~"postgres|postgres_replica"}[5m]) | Actividad, no evidencia causal de ruteo HTTP |
| Tamaño lógico | pg_database_size_bytes{datname="tickets_db",job=~"postgres|postgres_replica"} | No muestra espacio libre del disco WSL/VHDX |
| Cola replicación | pg_stat_replication_pg_wal_lsn_diff{job="postgres",application_name="postgres_lectura"} | Bytes entre posiciones LSN |
| Retraso | pg_replication_lag_seconds{job="postgres_replica"} | Complementar con streaming/LSN; tiempo desde último replay crece sin transacciones |
| Standby | pg_replication_is_replica{job="postgres_replica"} | Debe ser1 |
| Slot activo | pg_replication_slots_active{job="postgres",slot_name="slot_postgres_lectura"} | No modificar slot |
| Margen WAL | pg_replication_slots_safe_wal_size_bytes{job="postgres",slot_name="slot_postgres_lectura"} | Margen antes de riesgo por límite, no tamaño actual pg_wal |
| Receptor | time()-max(pg_stat_wal_receiver_last_msg_receipt_time{job="postgres_replica",status="streaming"}) | Heartbeat separado de actividad de negocio |
| Disco contenedores | container_fs_usage_bytes y container_fs_limit_bytes | Verificar labels/dispositivos; no sumar64series ciegamente ni atribuir overlay a volumen PGDATA |

Todas las bases anteriores tienen series presentes; no se inventó una métrica de backup ni de espacio libre de PGDATA. pg_ls_waldir sigue sin EXECUTE para monitor_postgres; no habilitar collector.wal. No otorgar pg_read_server_files ni superusuario.

## Almacenamiento sin ampliar privilegios SQL

Primero mapear volumen PGDATA->mountpoint->filesystem y comparar df/du externos en lectura. df libre filesystem y tamaño de datos son medidas distintas; el VHDX dinámico y espacio libre NTFS Windows son otro nivel. No instalar node_exporter ni montar /var/lib/docker entero adicionalmente como parte de esta auditoría. Si se necesita serie de filesystem: colector externo mínimo de statvfs sobre el punto autorizado y sus bytes total/libre, sin montar docker.sock. Su identidad/permisos y ruta se presentan para aprobación, sin root permanente ni lectura de archivos de aplicación. Monitorear VHDX/NTFS desde Windows con mecanismo independiente aprobado. No usar container_fs_limit_bytes como prueba de capacidad disponible para PostgreSQL.

## Backups: evidencia, no réplica

Respaldo externo antes_replica_20261020_134144 en /home/econt/backups/tickets: tickets_db.dump29307bytes, SHA256SUMS, globales/config/control. Existe marca externa /var/lib/mobile-support-tickets/prueba_docker/respaldo-verificado.json. Superó ensayo lógico aislado documentado. No constituye recuperación física completa, no cubre necesariamente el ticket/sucursal creados después y no debe anunciarse como backup reciente por estar el standby sincronizado. No se ejecutó restauración nueva en esta auditoría. infra/monitoring/ensayar_respaldo.py requiere endurecimiento antes de reutilizarse.

Diseño propuesto: proceso de backup autorizado genera manifiesto externo atómico con ID, inicio/fin UTC, código de salida, bytes, digest, rutas permitidas y versión; comprobador independiente verifica existencia/tamaño/digest y catálogo (pg_restore --list), y ensayo aislado genera OTRO resultado con objetos/conteos y alcance. No publicar hashes, rutas privadas, usernames ni secretos como labels Prometheus. No inferir restore_success por dump válido. Mantener en externo los manifiestos detallados y logs con permisos restrictivos.

Familias propuestas (AÚN NO disponibles): tickets_backup_last_success_timestamp_seconds, tickets_backup_size_bytes, tickets_backup_integrity_last_success_timestamp_seconds, tickets_backup_restore_last_success_timestamp_seconds, tickets_backup_last_run_success, tickets_backup_evidence_available. Timestamp proviene de evidencia validada; ausencia debe quedar como sin datos/no verificado, nunca valor actual automático. Umbrales de antigüedad requieren acordar RPO/RTO y frecuencia antes de crear alertas.

Transporte mínimo futuro: endpoint estático interno que sirva archivo .prom generado atómicamente por un verificador local con acceso solo a manifiestos y backup seleccionado. Sin docker.sock, SQL ni claves DB dentro del servidor HTTP; RO del directorio de métricas, UID sin privilegios, sin puertos publicados, solo red monitoreo. No iniciar recolector/servicio ahora. El job Prometheus tendría labels acotadas y alertas por evidencia ausente/backup vencido/último fallo, distintas de réplica. Ningún éxito se fabrica si falta manifiesto.

## Inventario exacto de cambios FUTUROS

1. Nuevo infra/monitoring/grafana/dashboards/almacenamiento_respaldos.json: quinto dashboard con SQL/LSN ya disponibles y secciones explícitas no verificadas hasta contar con evidencia.
2. Nuevo verificador de manifiestos y emisor .prom fuera de los scripts de ensayo anteriores, con pruebas fixtures (válido/truncado/hash erróneo/restauración ausente/evidencia vieja).
3. Nuevo servicio interno mínimo en compose.monitoring.yaml solo tras aprobar transporte/permisos; volumen RO de métricas externas, sin socket Docker.
4. Job en prometheus/prometheus.yaml y alertas/pruebas en reglas.yaml y pruebas_reglas.yaml; no modificar jobs ni paneles actuales.
5. Extender comprobar.py para exigir métricas nuevas reales, timestamps coherentes y distinguir absent de0.

Pruebas antes de desplegar: Compose config --quiet, promtool check config/rules/test rules, JSON de dashboard, validación de cada PromQL con samples, todos los dashboards actuales y38paneles, matriz de fallos de manifiestos, comprobar no secretos y no publicaciones. Presentar diff y obtener autorización antes de arrancar endpoint, recargar Prometheus o provisionar dashboard. Reinicios no son necesarios si se acuerda reload; nunca recrear PostgreSQL/API.

Reversión: retirar solo job/reglas/nuevo dashboard y servicio externo añadidos, recargar bajo autorización, conservando volúmenes Prometheus/Grafana y respaldos. No borrar series históricas ni cambiar los cuatro dashboards existentes.
