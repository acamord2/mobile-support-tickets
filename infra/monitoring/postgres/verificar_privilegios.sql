-- Solo lectura, después de crear el rol y antes de iniciar PostgreSQL Exporter.
SELECT rolname,rolsuper,rolcreatedb,rolcreaterole,rolreplication,rolbypassrls
FROM pg_roles WHERE rolname='monitor_postgres';
SELECT pg_has_role('monitor_postgres','pg_read_all_stats','MEMBER') AS lee_estadisticas,
 has_database_privilege('monitor_postgres','tickets_db','CONNECT') AS conectar;
SELECT c.relname,
 has_table_privilege('monitor_postgres',c.oid,'INSERT') AS puede_insertar,
 has_table_privilege('monitor_postgres',c.oid,'UPDATE') AS puede_actualizar,
 has_table_privilege('monitor_postgres',c.oid,'DELETE') AS puede_borrar,
 has_table_privilege('monitor_postgres',c.oid,'TRUNCATE') AS puede_truncar
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relkind='r' ORDER BY c.relname;
-- Todas las columnas de escritura deben devolver false; no se ensayan escrituras sobre tablas reales.
