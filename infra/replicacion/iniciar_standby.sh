#!/bin/sh
# Solo copia un volumen vacío. No borra datos ni ejecuta initdb como alternativa.
set -eu
umask 077
export LC_ALL=C
fallar() { printf '%s\n' "$1" >&2; exit 1; }
[ "${PGDATA:-}" = /var/lib/postgresql/data ] || fallar 'PGDATA inesperado.'
[ -s /run/preparacion/respaldo-verificado.json ] || fallar 'Falta control externo de respaldo.'
grep -Eq '"restauracion_verificada"[[:space:]]*:[[:space:]]*true' /run/preparacion/respaldo-verificado.json || fallar 'Falta ensayo de restauración aprobado.'
[ -f "$PGPASSFILE" ] || fallar 'Falta pgpass externo.'
[ "$(stat -c %u "$PGPASSFILE")" = 999 ] || fallar 'pgpass debe ser de UID 999.'
case "$(stat -c %a "$PGPASSFILE")" in 400|600) ;; *) fallar 'pgpass debe tener modo 0400 o 0600.' ;; esac
mkdir -p "$PGDATA"
if [ "$(id -u)" = 0 ]; then
  if [ -z "$(ls -A "$PGDATA")" ]; then chown 999:999 "$PGDATA"; chmod 700 "$PGDATA"; fi
  exec gosu postgres sh "$0"
fi
[ "$(id -u)" = 999 ] && [ -r "$PGPASSFILE" ] || fallar 'UID 999 no puede leer pgpass.'
[ "$(stat -c %u "$PGDATA")" = 999 ] && [ "$(stat -c %a "$PGDATA")" = 700 ] || fallar 'PGDATA debe ser de UID 999 y modo 0700.'
if [ -z "$(ls -A "$PGDATA")" ]; then
  if ! pg_basebackup --dbname="host=postgres port=5432 user=replicador_lectura application_name=postgres_lectura passfile=$PGPASSFILE" --pgdata="$PGDATA" --format=plain --wal-method=stream --checkpoint=spread --create-slot --slot=slot_postgres_lectura --write-recovery-conf --no-clean --no-password >/dev/null 2>&1; then
    fallar 'Falló backup inicial; revisar copia parcial y slot sin borrar automáticamente.'
  fi
  pg_verifybackup "$PGDATA" >/dev/null 2>&1 || fallar 'Backup físico inválido; revisión manual requerida.'
  [ "$(cat "$PGDATA/PG_VERSION")" = 17 ] && [ -f "$PGDATA/standby.signal" ] || fallar 'Copia incompatible o sin standby.signal.'
  pg_controldata "$PGDATA" | sed -n 's/^Database system identifier: *//p' > "$PGDATA/.replica_preparada"
fi
[ -s "$PGDATA/.replica_preparada" ] && [ -f "$PGDATA/standby.signal" ] || fallar 'Volumen inconsistente; no se inicia como primario.'
[ "$(cat "$PGDATA/PG_VERSION")" = 17 ] || fallar 'Versión incompatible.'
identificador=$(pg_controldata "$PGDATA" | sed -n 's/^Database system identifier: *//p')
[ -n "$identificador" ] && [ "$identificador" = "$(cat "$PGDATA/.replica_preparada")" ] || fallar 'Identificador de clúster inconsistente.'
# Sobrescribe parámetros heredados críticos sin editar los archivos copiados del primario.
exec postgres -D "$PGDATA" -c config_file=/opt/replicacion/standby.conf -c hba_file=/opt/replicacion/pg_hba_standby.conf -c primary_conninfo="host=postgres port=5432 user=replicador_lectura application_name=postgres_lectura passfile=$PGPASSFILE" -c primary_slot_name=slot_postgres_lectura -c hot_standby=on -c archive_mode=off -c restore_command=
