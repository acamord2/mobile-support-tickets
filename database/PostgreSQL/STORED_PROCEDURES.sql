-- Excluye usuarios inactivos; PasswordHash es exclusivamente interno.
CREATE OR REPLACE FUNCTION public.get_user_by_username(p_username character varying)
 RETURNS TABLE("Id" integer, "Username" character varying, "PasswordHash" text, "Name" character varying)
 LANGUAGE sql
 STABLE
AS $function$
    SELECT u."Id", u."Username", u."PasswordHash", u."Name"
    FROM public."Users" AS u
    WHERE u."Username" = p_username AND u."IsActive" = 1;
$function$;
