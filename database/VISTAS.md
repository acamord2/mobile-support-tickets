# Vista de agenda PostgreSQL

La vista combina tickets y sucursales para la sincronización; no contiene datos demo. El acceso a datos filtra TechnicianId desde JWT y ordena por ScheduledAt, CreatedAt e Id. No concede acceso directo a Flutter ni filtra por un usuario fijo.

Instalar manualmente en tickets_db. La API no instala objetos SQL. Este objeto nuevo es compatible con el esquema confirmado; no altera tablas.

```sql
-- Presenta los campos públicos de agenda junto a la sucursal para evitar consultas
-- duplicadas en la API. La identidad se filtra con parámetros en el acceso a datos.
CREATE OR REPLACE VIEW public.agenda_tickets AS
SELECT t."Id", t."BranchId", t."TechnicianId", t."Title", t."Description", t."Status",
       t."CreatedAt", t."UpdatedAt", t."ScheduledAt", t."ClientRequestId",
       b."Name" AS "BranchName", b."Address" AS "BranchAddress"
FROM public."Tickets" t
JOIN public."Branches" b ON b."Id" = t."BranchId";
```
