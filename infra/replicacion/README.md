> Estado consolidado vigente: [manual de infraestructura](../../docs/infraestructura/README.md). Esta nota conserva antecedentes y propuestas de su fase; revisar el manual actual antes de operar.

# Preparación de streaming replication PostgreSQL 17

Estado: fase12.1 cerrada; postgres_lectura está activo, healthy, en recuperación y streaming asíncrono. Primario mantiene lectura/escritura. No hay promoción automática.

## Respaldo restaurado y verificado

El respaldo válido está en /home/econt/backups/tickets/antes_replica_20261020_134144, fuera del repositorio. El dump tiene 29307 bytes y se verificaron las sumas SHA256 del conjunto. Superó una restauración aislada en PostgreSQL 17 de la misma imagen, sin red ni puertos publicados y con PGDATA independiente en tmpfs. Se restauraron roles globales y tickets_db y se comprobaron ocho tablas, public.get_user_by_username, public.agenda_tickets, cuatro filas de Roles, cinco de Users y cero filas en las otras seis tablas. Ninguna instancia existente recibió SQL del ensayo. El recurso temporal se eliminó tras verificar nombre, etiqueta, ausencia de identidad Compose y almacenamiento separado.

El archivo antiguo /home/econt/backups/tickets/tickets_antes_replica.dump, de cero bytes, sigue siendo inválido, pero no bloquea el respaldo posterior ya restaurado. No eliminar ni sobrescribir ninguno de los archivos externos durante una limpieza del repositorio. El ensayo acredita aquel respaldo concreto y su estado al tomarlo; no garantiza incluir cambios posteriores ni autoriza iniciar la réplica.

respaldar.sh se conserva como procedimiento operativo: no sobrescribe destinos existentes y guarda dump, roles globales sensibles, cuatro configuraciones y control del clúster fuera de Git con umask 077. Procesar pg_restore no equivale a restaurar. Los ensayos futuros deben ser aislados, autorizados y sin conexión al primario.

El helper [../monitoring/ensayar_respaldo.py](../monitoring/ensayar_respaldo.py) se conserva SIN MODIFICAR y requiere endurecimiento antes de reutilizarlo. Sus conteos son fijos y sus guardas de eliminación no incorporan todas las comprobaciones usadas en el ensayo verificado. Antes de otro ensayo, revisar conteos esperados para ese dump y verificar ID/nombre/etiqueta, ausencia de etiquetas Compose, red none, cero puertos y almacenamiento sin montajes compartidos. No ejecutar el helper automáticamente ni tomarlo como reproducción íntegra de la prueba realizada.

## Archivos y aislamiento

`compose.replica.yaml` es un complemento opcional al Compose actual. No modifica los servicios api/postgres. Usa perfil replicacion, la misma imagen exacta PostgreSQL 17.11 y volumen nuevo datos_postgres_lectura. Solo accede a base_datos y no publica puertos. No usar docker compose up sin seleccionar expresamente postgres_lectura y --no-deps.

El bootstrap arranca como root solo para asignar dueño 999:999 a un volumen vacío; luego ejecuta gosu postgres. Exige pgpass y una marca externa de respaldo. Volumen vacío: pg_basebackup con --no-clean, WAL streaming y slot exclusivo, pg_verifybackup, standby.signal y marca con identificador físico. Volumen válido: reutiliza la copia. Volumen parcial, promovido o inconsistente: aborta sin borrar ni ejecutar initdb. Un error puede dejar un slot creado y un volumen parcial: revisar ambos antes de reintentar. No quitar automáticamente la marca ni standby.signal.

Se usa configuración y HBA propios del standby, sin copiar el volumen vivo. El HBA del standby conserva diagnóstico local y admite únicamente consultor_api y monitor_postgres por SCRAM a tickets_db desde la red privada real; rechaza demás conexiones. Mientras siga en recuperación todas las conexiones son de solo lectura. Un administrador podría promoverla: no hay automatización de promoción ni failover.

## Variables externas y permisos

No hace falta cambiar .env.example. El complemento admite estas variables opcionales, que solo contienen rutas:

- REPLICA_PGPASS_FILE: /var/lib/mobile-support-tickets/prueba_docker/replicacion.pgpass
- REPLICA_RESPALDO_OK: /var/lib/mobile-support-tickets/prueba_docker/respaldo-verificado.json

El futuro pgpass debe tener dueño 999:999, modo 0400 (o 0600), una línea postgres:5432:replication:replicador_lectura:CONTRASENA_GENERADA. Nunca guardar esa línea en Git ni imprimirla. Usar una contraseña aleatoria sin dos puntos ni barras inversas o escaparlos según libpq. El usuario de replicación no reutiliza la contraseña de aplicación. Crear en fase autorizada con LOGIN REPLICATION NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS y contraseña SCRAM, transmitida sin literales en historial ni registros. replicador_lectura y el pgpass externo ya fueron creados en12.1; no repetir su creación.

Los archivos externos actuales y las credenciales habituales se conservan. El rol de aplicación existente es superusuario: cambiarlo es otra etapa. Con ssl=off SCRAM autentica pero no cifra los datos; solo se usa la red Docker interna local.

## Comandos de aplicación futura (NO ejecutados)

Desde la raíz del repositorio, después de autorizar cada etapa:

```sh
# 1. Crear respaldo NUEVO externo; no altera datos SQL.
RESPALDO_DIR="$HOME/backups/tickets/antes_replica_$(date +%Y%m%d_%H%M%S)" sh infra/replicacion/respaldar.sh
# 2. Para un respaldo nuevo, preparar un ensayo aislado y autorizado con guardas endurecidas.
# No generar una marca de éxito hasta comprobar realmente la restauración.
# 3. Generar propuesta HBA desde la red real, sin aplicarla.
python3 infra/replicacion/generar_hba.py
# 4. Tras el respaldo validado, crear rol/credencial y aplicar SOLO el bloque HBA
# antes de reglas generales, conservando una copia del archivo original.
```

La marca y el pgpass fueron creados y comprobados durante12.1; volver a verificarlos antes de cualquier reconstrucción. La marca externa es JSON con restauracion_verificada=true, respaldo_dir absoluto y sha256_dump del dump realmente restaurado. Es una aprobación del operador, no una certificación automática. Debe ser legible por UID 999 y de solo lectura en el montaje; no contiene secretos.

En la fase de cambios al primario se necesita autorización expresa. No aumentar wal_level/max_wal_senders/max_replication_slots: ya están en replica/10/10. Mantener replicación asíncrona y synchronous_standby_names vacío. max_slot_wal_keep_size=1GB ya está activo tras dimensionar WAL; el parámetro es recargable y puede invalidar el slot si la réplica se atrasa demasiado. Nunca dejar retención ilimitada sin supervisión. Registrar valor anterior y si provenía de postgresql.auto.conf antes de ALTER SYSTEM.

Generar HBA otra vez justo antes de aplicarlo; nunca asumir 172.27.0.0/16. Revisar pg_hba_file_rules y solo entonces ejecutar pg_reload_conf. No se proporciona un instalador automático del primario para evitar cambios antes del respaldo/permiso.

```sh
# Validación sin arrancar servicios (disponible ahora).
python3 infra/replicacion/validar_preparacion.py
# Verificar archivos externos reales y lectura UID 999 (cuando existan).
sudo python3 infra/replicacion/validar_preparacion.py --permisos-y-respaldo
# Arranque exclusivamente del standby, solo con autorización y precondiciones aprobadas.
docker compose --env-file .env.example -f compose.yaml -f compose.replica.yaml --profile replicacion up -d --no-deps postgres_lectura
# Supervisión de solo lectura, después del arranque.
docker compose --env-file .env.example -f compose.yaml -f compose.replica.yaml --profile replicacion exec -T postgres_lectura psql -X -v ON_ERROR_STOP=1 -U tickets_practica -d tickets_db < infra/replicacion/supervisar.sql
```

En el primario consultar pg_stat_replication (state, sync_state, sent_lsn, write_lsn, flush_lsn, replay_lsn) y pg_replication_slots (active, restart_lsn, wal_status, safe_wal_size). No mostrar conninfo. Comparar pg_current_wal_lsn capturado en el primario con pg_last_wal_replay_lsn en la réplica. No interpretar antigüedad de pg_last_xact_replay_timestamp como retraso en un sistema sin escrituras.

## Reversión sin promoción

Detener exclusivamente postgres_lectura; mantener su volumen para diagnóstico. Cuando el slot esté inactivo, retirarlo con autorización para liberar WAL. Revocar acceso del rol de replicación, retirar exclusivamente el bloque HBA agregado y restaurar el valor WAL previo; recargar después de validar. API y volumen primario permanecen intactos. Nunca ejecutar down -v ni eliminar el volumen del primario. Si hubo promoción o divergencia, no reconectar automáticamente: con wal_log_hints y checksums actuales desactivados no se puede asumir pg_rewind; planificar reconstrucción desde un nuevo backup.

## Límites

La réplica copia todo el clúster, roles y hashes, no solo tickets_db. Consume espacio adicional y WAL. Es asíncrona: puede servir lecturas antiguas y perder últimas transacciones ante promoción. Consultas largas pueden cancelarse por conflictos de replay. Ambos servicios comparten host/disco WSL; no sustituye respaldo. La API sigue en Host=postgres, sin balanceo ni separación C# de lecturas/escrituras.


## Recuperación ante pérdida de datos

Conservar siempre el volumen primario y el respaldo original. Preparar un PostgreSQL 17 temporal de la misma imagen, sin red ni puertos publicados y con almacenamiento independiente; identificarlo inequívocamente como ensayo y comprobar que no pertenece al proyecto activo. Verificar SHA256SUMS antes de usar el dump. El flujo de restauración, exclusivamente dentro de ese entorno aislado, es restaurar globales con psql -X -v ON_ERROR_STOP=1, crear tickets_db con propietario tickets_practica y restaurar tickets_db.dump mediante pg_restore --exit-on-error. Transportar archivos por stdin sin imprimir roles, hashes o filas sensibles. Globales sensibles no deben aparecer en logs del servidor ni historial.

Comprobar nombres de tablas, función y vista, propietarios/permisos y conteos esperados para el respaldo seleccionado. Conservar evidencia sin datos sensibles. Solo después de verificar ID, etiquetas, red y almacenamiento se pueden retirar los recursos temporales autorizados; no tocar el proyecto activo. Una recuperación sobre el servicio real, sustitución de volumen o cambio de conexión requiere un plan separado y autorización expresa; no se ofrece como comando automático de esta práctica.

La réplica física no sustituye estos respaldos: replica errores y eliminaciones. El monitoreo actual permanece privado, con ocho targets UP y tres dashboards/treinta paneles verificados; consultar [../monitoring/README.md](../monitoring/README.md). Su acceso Windows se describe en [../monitoring/ACCESO_PRIVADO.md](../monitoring/ACCESO_PRIVADO.md). La cuenta existente monitor_postgres se copia físicamente con el clúster; no crearla de nuevo en el standby y no habilitar su exporter hasta autorizar las reglas HBA de lectura necesarias.

La API de fases12.2/12.3 usa dos conexiones; la configuración previa de API solo primaria quedó conservada como reversión. Ver [../lectura/FASE12_3.md](../lectura/FASE12_3.md).
