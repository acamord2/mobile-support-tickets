# PostgreSQL y réplica física

Nodos17.11 con mismo image ID/digest; primario postgres:17 es tag móvil y standby fija digest. No actualizar un nodo unilateralmente. Volúmenes datos_postgres y datos_postgres_lectura separados aunque ambos usen PGDATA=/var/lib/postgresql/data.

## Esquema y roles

Instalar manualmente DATABASE.sql→STORED_PROCEDURES.sql→VISTAS.sql con psql -X -v ON_ERROR_STOP=1. Ocho tablas, public.get_user_by_username y public.agenda_tickets. API no instala SQL. DATOS_PRUEBA y BD_COMPLETA contienen demo; excluirlos. SQLServer es equivalencia documental. Fuentes actuales no tienen TRIGGERS.sql: no inventar ese requisito.

agenda_tickets es vista SQL, no endpoint ni pantalla Flutter; la API conserva SQL propio con alcance por usuario. get_user_by_username participa en login primario.

| Rol | Privilegios/uso |
|---|---|
| tickets_practica | Propietario amplio de práctica/escritura; no usar para exporters/lectura |
| consultor_api | CONNECT, USAGE, SELECT por columna en siete tablas; sin PasswordHash/escritura/CREATE; TEMP heredado de PUBLIC permanece |
| monitor_postgres | CONNECT, pg_read_all_stats; sin datos de aplicación ni acceso amplio a archivos |
| replicador_lectura | LOGIN REPLICATION, sin SUPERUSER/CREATEDB/CREATEROLE ni tablas de aplicación |

Read_only por defecto no sustituye ACL en primario. Roles/ACL se replican físicamente: aplicar cambios administrativos solo en primario, nunca CREATE/GRANT en standby. Consultor SQL en primario es read_only por ajuste propio; no significa que el servidor no pueda escribir para otra cuenta.

Preparación nueva: [preparar_consultor.py](../../infra/lectura/preparar_consultor.py), [crear_consultor.sql](../../infra/lectura/crear_consultor.sql), [autorizar_usuario.py](../../infra/monitoring/postgres/autorizar_usuario.py), [crear_usuario.sql](../../infra/monitoring/postgres/crear_usuario.sql). Wrappers requieren --aplicar y roles/archivos inexistentes; no son rotación ni arranque habitual. Usan credenciales privadas y logging de sesión suprimido; no pasar passwords en -v/argumentos. Revisar antes de ejecutar con autorización.

## HBA y bootstrap

`python3 infra/replicacion/generar_hba.py` obtiene CIDR real, propone reglas y no aplica. El HBA standby guardado contiene la subred específica actual; otro clon debe regenerar/revisar su variante. Primario permite host replication replicador_lectura CIDR_REAL scram-sha-256 antes de rechazos, y rechaza uso normal de la cuenta replicadora. Standby permite consultor_api/monitor_postgres sobre tickets_db desde el origen aprobado y rechaza los demás. Verificar origen bridge usado por SSH sin ampliar automáticamente.

Antes de ajustar: copia externa protegida HBA/config, consulta pg_hba_file_rules, orden y recarga pg_reload_conf solo tras autorización; no reinicio. Nada de ello se ejecutó por Fase16.

Passfile externo UID/GID999,0400/0600, legible efectivamente. [Plantilla](plantillas/replicacion.pgpass.example). primary_conninfo no contiene contraseña. Bootstrap usa pg_basebackup --wal-method=stream --create-slot --slot=slot_postgres_lectura --write-recovery-conf, pg_verifybackup, standby.signal y marca de identidad. No crear previamente slot en un bootstrap nuevo: --create-slot exige que no exista. Copia parcial/slot residual requieren diagnóstico manual, nunca borrar/reintentar automáticamente.

Volumen vacío se copia; válido se verifica con PG_VERSION/standby.signal/system identifier; inconsistente se rechaza. No fallback initdb, no PGDATA compartido y no copiar directamente volumen activo.

## WAL y verificaciones

Asíncrono no garantiza lectura inmediata ni pérdida cero del último commit. Slot exclusivo slot_postgres_lectura; retención max_slot_wal_keep_size=1GB verificada. Réplica atrasada puede invalidar slot al superar retención; no es una cuota rígida instantánea de todo pg_wal. Vigilar disco/slot/LSN y no cambiar WAL por un panel.

```sh
sh infra/operacion/compose_proyecto.sh exec -T postgres psql -X -v ON_ERROR_STOP=1 -U tickets_practica -d tickets_db <<'SQL'
SELECT pg_is_in_recovery(),current_setting('transaction_read_only');
SELECT application_name,state,sync_state,sent_lsn,write_lsn,flush_lsn,replay_lsn FROM pg_stat_replication;
SELECT slot_name,active,restart_lsn,wal_status,safe_wal_size FROM pg_replication_slots;
SHOW max_slot_wal_keep_size;
SELECT pg_current_wal_lsn();
SQL
sh infra/operacion/compose_proyecto.sh exec -T postgres_lectura psql -X -v ON_ERROR_STOP=1 -U tickets_practica -d tickets_db <<'SQL'
SELECT pg_is_in_recovery(),current_setting('transaction_read_only');
SELECT status,received_lsn,latest_end_lsn,last_msg_receipt_time FROM pg_stat_wal_receiver;
SELECT pg_last_wal_receive_lsn(),pg_last_wal_replay_lsn(),pg_last_xact_replay_timestamp();
SQL
```

Esperado: primario false/off, standby true/on; emisor/receptor streaming, sync_state async, slot activo válido. Comparar LSN con pg_wal_lsn_diff; última transacción antigua en servidor ocioso no prueba atraso. Conexiones abiertas no prueban destino de consulta: combinar X-Destino-Lectura y validación del rol físico/SQL real.

## Backup y recuperación

Respaldo externo antes_replica_20261020_134144 superó restauración aislada: ocho tablas/una función/una vista y conteos de esa fecha. Marca externa y SHA256 vinculan dump ensayado. No distribuir dump/globales/HBA/marca en Git. Es respaldo lógico verificado de esa base y configuración guardada, no prueba de recuperación integral/PITR ni de cambios posteriores. Archivo antiguo de cero bytes no es el respaldo vigente ni bloqueo actual.

[respaldar.sh](../../infra/replicacion/respaldar.sh) genera dump custom, globales (hashes sensibles), configuración y SHA256 en RESPALDO_DIR absoluto nuevo externo. No programa backups. [ensayar_respaldo.py](../../infra/monitoring/ensayar_respaldo.py) se conserva sin cambios y exige endurecimiento antes de reutilizar: conteos fijos, posibles conflictos globales, identidad/limpieza, tmpfs y evidencia durable. No presentarlo como instalador automático; nuevo ensayo requiere recursos aislados, sin puertos y autorización.

Réplica no es backup: propaga errores/borrados y comparte dominio host. MinIO, programación y PITR pendientes. [Referencia PostgreSQL17](https://www.postgresql.org/docs/17/warm-standby.html).
