#!/bin/sh
# Comprueba disponibilidad y rol; el retraso se consulta por separado.
set -eu
[ -f /var/lib/postgresql/data/standby.signal ] || exit 1
resultado=$(psql -X -qAt -v ON_ERROR_STOP=1 -U tickets_practica -d tickets_db -c "SELECT pg_is_in_recovery() AND current_setting('transaction_read_only')='on';" 2>/dev/null) || exit 1
[ "$resultado" = t ]
