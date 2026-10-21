-- PREPARADO, NO EJECUTADO. Requiere autorización independiente.
-- No contiene contraseña; se asigna después por canal privado, antes de iniciar exporter.
\set ON_ERROR_STOP on
BEGIN;
CREATE ROLE monitor_postgres LOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE
  NOREPLICATION NOBYPASSRLS CONNECTION LIMIT 3;
GRANT CONNECT ON DATABASE tickets_db TO monitor_postgres;
GRANT pg_read_all_stats TO monitor_postgres;
ALTER ROLE monitor_postgres SET default_transaction_read_only = on;
ALTER ROLE monitor_postgres SET statement_timeout = '5s';
COMMIT;
-- No concede SELECT a Users ni a las demás tablas de aplicación.
-- Un rol ya existente provoca error; no cambia sus atributos o contraseña.
