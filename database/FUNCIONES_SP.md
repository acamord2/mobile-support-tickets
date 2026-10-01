# Funciones y procedimientos almacenados

Se conserva únicamente `public.get_user_by_username` como infraestructura existente. La implementación PostgreSQL del acceso a datos la invoca mediante un parámetro DbCommand; los controllers no conocen su SQL. Se actualiza su cuerpo para excluir IsActive = 0 después de aplicar el esquema nuevo, sin agregar funciones de Tickets.

Requisito: estructura instalada desde DATABASE.md. Abrir pgAdmin Query Tool conectado a `tickets_db` y ejecutar este bloque. CREATE OR REPLACE permite actualizar la misma función sin duplicarla. La API la invoca para leer usuarios; no ejecuta el SQL de instalación. No hay Stored Procedures ni funciones de tickets requeridas.

```sql
-- Obtiene la identidad y el hash interno de un usuario mediante su nombre exacto.
-- Encapsula la lectura en PostgreSQL para mantener el SQL específico fuera de los
-- controllers. El parámetro permite consultar sin construir SQL dinámico.
-- Excluye cuentas inactivas como usuarios no encontrados, sin revelar su existencia.
-- Conserva las cuatro columnas de salida para no romper la API ni reemplazar dependencias.
-- Es una función de lectura STABLE: no inserta usuarios ni modifica la estructura.
CREATE OR REPLACE FUNCTION public.get_user_by_username(p_username varchar)
RETURNS TABLE ("Id" integer, "Username" varchar, "PasswordHash" text, "Name" varchar)
LANGUAGE sql
STABLE
AS $$
    SELECT u."Id", u."Username", u."PasswordHash", u."Name"
    FROM public."Users" AS u
    WHERE u."Username" = p_username AND u."IsActive" = 1;
$$;
```

## Compatibilidad y orden

No ejecutar esta versión contra el esquema antiguo sin Users.IsActive. En una instalación nueva ejecutar después de DATABASE.md; para una base existente insertar este bloque canónico entre los pasos estructurales y el COMMIT de ACTUALIZACION_POSTGRESQL.md. No se duplica su definición en otro documento.

Se conservan Id, Username, PasswordHash y Name en la salida interna. PostgreSQL no permite cambiar RETURNS TABLE con CREATE OR REPLACE; mantener el contrato evita DROP FUNCTION y conserva consumidores. PasswordHash solo llega al acceso interno/PasswordHasher y nunca a JSON público. Después de aplicar esta función, una cuenta inactiva resulta indistinguible de una cuenta inexistente y Login conserva su 401 genérico.

RoleId permanece en Users: ampliar modelo, DTO público y salida interna con rol será una modificación posterior a la confirmación de la BD. No se cambia ahora JWT, /me ni sesión SQLite. El SP SQL Server equivalente está en sqlserver/FUNCIONES_SP_SQLSERVER.md.
