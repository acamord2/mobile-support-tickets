#!/bin/sh
# Solo preparar ahora; ejecutar después de autorización, sin mostrar roles ni hashes.
set -eu
umask 077
cd "$(dirname "$0")/../.."
[ -n "${RESPALDO_DIR:-}" ] || { echo 'Define RESPALDO_DIR absoluto y externo.' >&2; exit 1; }
case "$RESPALDO_DIR" in /*) ;; *) exit 1;; esac
RESPALDO_DIR=$(readlink -m -- "$RESPALDO_DIR")
case "$RESPALDO_DIR/" in "$(pwd)/"*) echo 'Destino dentro del repositorio rechazado.' >&2; exit 1;; esac
[ ! -e "$RESPALDO_DIR" ] || { echo 'Destino existente; no se sobrescribe.' >&2; exit 1; }
mkdir -m 700 "$RESPALDO_DIR"
dc() { docker compose --env-file .env.example "$@"; }
dc exec -T postgres pg_dump -U tickets_practica -d tickets_db --format=custom > "$RESPALDO_DIR/tickets_db.dump"
[ -s "$RESPALDO_DIR/tickets_db.dump" ]
dc exec -T postgres pg_dumpall -U tickets_practica --globals-only > "$RESPALDO_DIR/globales.sql"
for archivo in postgresql.conf postgresql.auto.conf pg_hba.conf pg_ident.conf; do
 dc exec -T postgres cat "/var/lib/postgresql/data/$archivo" > "$RESPALDO_DIR/$archivo"
done
dc exec -T postgres pg_controldata /var/lib/postgresql/data > "$RESPALDO_DIR/control_cluster.txt"
dc exec -T postgres pg_restore --list < "$RESPALDO_DIR/tickets_db.dump" > /dev/null
dc exec -T postgres pg_restore --file=/dev/null < "$RESPALDO_DIR/tickets_db.dump"
(cd "$RESPALDO_DIR" && sha256sum tickets_db.dump globales.sql postgresql.conf postgresql.auto.conf pg_hba.conf pg_ident.conf control_cluster.txt > SHA256SUMS)
printf '%s\n' 'Respaldo procesado; falta ensayo de restauración aislado. No se habilita bootstrap automáticamente.'
