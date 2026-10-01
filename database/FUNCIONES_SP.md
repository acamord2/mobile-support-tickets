# Funciones y procedimientos almacenados

Se conserva únicamente `public.get_user_by_username` como infraestructura existente. La implementación PostgreSQL del acceso a datos la invoca mediante un parámetro DbCommand; los controllers no conocen su SQL. No se agregan funciones de tickets ni procedimientos adicionales.

Requisito: estructura instalada desde DATABASE.md. Abrir pgAdmin Query Tool conectado a `tickets_db` y ejecutar este bloque. CREATE OR REPLACE permite actualizar la misma función sin duplicarla. La API la invoca para leer usuarios; no ejecuta el SQL de instalación. No hay Stored Procedures ni funciones de tickets requeridas.

```sql
-- Obtiene la identidad y el hash interno de un usuario mediante su nombre exacto.
-- Encapsula la lectura en PostgreSQL para mantener el SQL específico fuera de los
-- controllers. El parámetro permite consultar sin construir SQL dinámico.
-- Es una función de lectura STABLE: no inserta usuarios ni modifica la estructura.
CREATE OR REPLACE FUNCTION public.get_user_by_username(p_username varchar)
RETURNS TABLE ("Id" integer, "Username" varchar, "PasswordHash" text, "Name" varchar)
LANGUAGE sql
STABLE
AS $$
    SELECT u."Id", u."Username", u."PasswordHash", u."Name"
    FROM public."Users" AS u
    WHERE u."Username" = p_username;
$$;
```
