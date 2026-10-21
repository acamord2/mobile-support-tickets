# Plantillas seguras

Copiar solo a destino externo protegido y completar por canal privado. No ejecutar sobre roles/archivos existentes. No marcar respaldo true sin ensayo auténtico documentado.

- secrets-api.json.example: formato anidado compatible; Escritura/DefaultConnection coinciden y Lectura usa consultor_api.
- replicacion.pgpass.example: UID/GID999,0400/0600, escapar : y barra inversa según libpq; database replication para basebackup.
- respaldo-verificado.json.example: false deliberado; hash/directorio/evidencia reales requeridos.
- replicador.sql.example: creación nueva con password del entorno de psql; sesión/logging revisados y autorización SQL separada. No ejecutado aquí ni por API.

Generar passwords aleatorios independientes para PostgreSQL/Grafana/exporter, fuera de Git. Marcadores no son contraseñas utilizables. No producir credenciales divergentes del rol usando dos generadores diferentes. Verificar lectura efectiva por UID y evitar chmod777.
