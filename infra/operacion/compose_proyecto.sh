#!/bin/sh
# Selecciona solo configuración activa; excluye propuestas de recursos e imagen de reversión.
set -eu
cd "$(dirname "$0")/../.."
[ "$#" -gt 0 ] || { echo 'Uso: sh infra/operacion/compose_proyecto.sh config --quiet | ps | ...' >&2; exit 2; }
exec docker compose --env-file .env.example -f compose.yaml -f compose.api-lectura.yaml -f compose.replica.yaml -f compose.monitoring.yaml -f compose.supervision.yaml --profile replicacion --profile monitoreo --profile monitoreo_replica --profile supervision "$@"
