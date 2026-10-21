-- Ejecutar en Query Tool de cada perfil. Solo SELECT; no modifica configuración ni datos.
SELECT current_user, inet_server_addr(), inet_client_addr(),
       pg_is_in_recovery() AS es_standby,
       current_setting('transaction_read_only') AS solo_lectura;
SELECT has_database_privilege(current_user,'tickets_db','CONNECT') AS conectar,
       has_database_privilege(current_user,'tickets_db','CREATE') AS crear_en_base,
       has_schema_privilege(current_user,'public','CREATE') AS crear_en_public,
       has_database_privilege(current_user,'tickets_db','TEMP') AS temporal_heredado;
SELECT tablename,
       has_any_column_privilege(current_user,format('%I.%I',schemaname,tablename),'SELECT') AS lee_alguna_columna,
       has_table_privilege(current_user,format('%I.%I',schemaname,tablename),'INSERT,UPDATE,DELETE,TRUNCATE')
       OR has_any_column_privilege(current_user,format('%I.%I',schemaname,tablename),'INSERT,UPDATE') AS escribe
FROM pg_tables WHERE schemaname='public' ORDER BY tablename;
SELECT "Id","Name","Address" FROM public."Branches";
SELECT count(*) AS tickets FROM public."Tickets";
SELECT has_column_privilege(current_user,'public."Users"','PasswordHash','SELECT') AS lee_hash;
