-- Prepara únicamente el rol Técnico y un usuario para probar login y /me.
-- No ejecutar sin autorización. No contiene contraseña ni hash reales.
-- Requiere psql y HASH_USUARIO_PRUEBA en su entorno: un hash generado y
-- verificado con PasswordHasher<Usuario> de ASP.NET Core Identity .NET 10.
-- El hash se recibe fuera del archivo; nunca se usa una contraseña SQL en texto plano.
-- Es una carga manual independiente: no agregar a BD_COMPLETA.sql ni al arranque.
\set ON_ERROR_STOP on
\set ECHO none
\getenv hash_password HASH_USUARIO_PRUEBA
\if :{?hash_password}
\else
  \echo 'Falta HASH_USUARIO_PRUEBA; no se insertó ningún registro.'
  \quit 3
\endif

\if :{?usuario_prueba}
\else
  \set usuario_prueba 'auth_practica'
\endif
\if :{?nombre_prueba}
\else
  \set nombre_prueba 'Usuario de prueba de autenticación'
\endif

-- Comprueba el destino y formato básico; la verificación criptográfica se hace en .NET.
SELECT current_database() = 'tickets_db'
   AND current_user = 'tickets_practica'
   AND length(:'usuario_prueba') BETWEEN 1 AND 100
   AND length(btrim(:'usuario_prueba')) > 0
   AND length(:'nombre_prueba') BETWEEN 1 AND 200
   AND length(btrim(:'nombre_prueba')) > 0
   AND length(:'hash_password') >= 80
   AND :'hash_password' ~ '^AQAAAA[A-Za-z0-9+/=]+$'
   AS parametros_validos
\gset
\if :parametros_validos
\else
  \echo 'Destino o parámetros inválidos; no se insertó ningún registro.'
  \quit 3
\endif

BEGIN;
SET LOCAL search_path = public, pg_catalog;

-- Reutiliza Id 2 solo si ya corresponde exactamente al rol esperado; nunca lo renombra.
INSERT INTO public."Roles" ("Id", "Name")
VALUES (2, 'Técnico')
ON CONFLICT ("Id") DO NOTHING;

SELECT EXISTS (
  SELECT 1 FROM public."Roles" WHERE "Id" = 2 AND "Name" = 'Técnico'
) AS rol_correcto
\gset
\if :rol_correcto
\else
  ROLLBACK;
  \echo 'El rol Id 2 tiene otro nombre; operación cancelada sin modificar registros existentes.'
  \quit 3
\endif

-- Un Username existente provoca error y revierte la transacción; no cambia su contraseña.
-- Se omite Id para utilizar la identidad de PostgreSQL y se activa explícitamente el usuario.
INSERT INTO public."Users" ("Username", "PasswordHash", "Name", "RoleId", "IsActive")
VALUES (:'usuario_prueba', :'hash_password', :'nombre_prueba', 2, 1);

COMMIT;
\unset hash_password
\echo 'Usuario de prueba creado; no se muestran contraseña ni hash.'
