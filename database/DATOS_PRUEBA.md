# Datos de prueba

> Estos datos son únicamente para desarrollo y demostración. No forman parte de la estructura necesaria para crear la base de datos.

Instalar antes DATABASE.md y FUNCIONES_SP.md; revisar VISTAS.md y TRIGGERS.md, actualmente sin objetos requeridos. Ejecutar el bloque manualmente desde pgAdmin Query Tool conectado a tickets_db solo en desarrollo. La API no ejecuta estos INSERT ni hace seed.

Credencial pública demo: **tecnico1 / Demo123*** (Técnico Demo). No reutilizarla para PostgreSQL, GitHub u otros servicios ni habilitarla en producción. La tabla recibe únicamente el hash generado y verificado mediante PasswordHasher<Usuario> de ASP.NET Core .NET 10, nunca la contraseña en texto plano.

La muestra prepara un técnico, dos sucursales, dos tickets y una evidencia descriptiva sin fotografía. ON CONFLICT y NOT EXISTS evitan duplicados en ejecuciones secuenciales sin sobrescribir datos o estados existentes. Si tecnico1 ya existe con otra contraseña, no se modifica y la credencial demo podría no funcionar. Revisar sucursales demo preexistentes duplicadas antes de cargar; el bloque no está diseñado para cargas concurrentes. Si falla, ejecutar ROLLBACK antes de corregir y repetir.

Las consultas finales verifican usuario y tickets sin exponer el hash. En una base limpia se esperan un técnico y dos tickets de la muestra. Esta etapa entrega el SQL y no lo ejecuta sobre la instalación local.

```sql
BEGIN;

-- Inserta solo el técnico demo ausente; el UNIQUE existente evita duplicarlo.
-- Conserva credenciales previas para no modificar cuentas al repetir la carga.
INSERT INTO public."Users" ("Username", "PasswordHash", "Name", "RoleId", "IsActive")
VALUES ('tecnico1', 'AQAAAAIAAYagAAAAECG6+xJ1OmiicKseDoLWq//XHERs/rdTMrsLDXb0cG0M1yctPgH/ccHy5f0oMZfJOw==', 'Técnico Demo', 2, 1)
ON CONFLICT ("Username") DO NOTHING;

-- Asigna explícitamente el rol técnico de la muestra existente sin cambiar password.
-- Se conserva IsActive previo para no reactivar una cuenta desactivada deliberadamente.
UPDATE public."Users" SET "RoleId" = 2 WHERE "Username" = 'tecnico1';

-- Localiza sucursales por nombre y dirección sin imponer una nueva restricción.
-- Las condiciones previenen duplicados al volver a ejecutar manualmente el bloque.
INSERT INTO public."Branches" ("Name", "Address")
SELECT 'Sucursal Demo Centro', 'Calle Demo 10, Centro'
WHERE NOT EXISTS (
    SELECT 1 FROM public."Branches"
    WHERE "Name" = 'Sucursal Demo Centro' AND "Address" = 'Calle Demo 10, Centro'
);

INSERT INTO public."Branches" ("Name", "Address")
SELECT 'Sucursal Demo Norte', 'Avenida Demo 20, Norte'
WHERE NOT EXISTS (
    SELECT 1 FROM public."Branches"
    WHERE "Name" = 'Sucursal Demo Norte' AND "Address" = 'Avenida Demo 20, Norte'
);

-- Relaciona tickets con IDs generados y conserva los estados SQL ya aprobados.
-- Fechas UTC fijas hacen la muestra fácil de explicar y reproducir sin reiniciarla.
INSERT INTO public."Tickets"
    ("BranchId", "TechnicianId", "Title", "Description", "Status", "CreatedAt", "UpdatedAt", "ScheduledAt")
SELECT b."Id", u."Id", 'Demo: revisión de equipo',
       'El equipo de la sucursal no inicia.', 'Pending',
       TIMESTAMPTZ '2026-01-15 10:00:00+00', TIMESTAMPTZ '2026-01-15 10:00:00+00',
       TIMESTAMPTZ '2026-01-15 10:00:00+00'
FROM public."Branches" b CROSS JOIN public."Users" u
WHERE b."Name" = 'Sucursal Demo Centro' AND b."Address" = 'Calle Demo 10, Centro'
  AND u."Username" = 'tecnico1'
  AND NOT EXISTS (
      SELECT 1 FROM public."Tickets" t
      WHERE t."BranchId" = b."Id" AND t."TechnicianId" = u."Id"
        AND t."Title" = 'Demo: revisión de equipo'
  );

INSERT INTO public."Tickets"
    ("BranchId", "TechnicianId", "Title", "Description", "Status", "CreatedAt", "UpdatedAt", "ScheduledAt")
SELECT b."Id", u."Id", 'Demo: conexión intermitente',
       'La conexión del equipo se interrumpe ocasionalmente.', 'InProgress',
       TIMESTAMPTZ '2026-01-15 11:00:00+00', TIMESTAMPTZ '2026-01-15 11:30:00+00',
       TIMESTAMPTZ '2026-01-15 11:00:00+00'
FROM public."Branches" b CROSS JOIN public."Users" u
WHERE b."Name" = 'Sucursal Demo Norte' AND b."Address" = 'Avenida Demo 20, Norte'
  AND u."Username" = 'tecnico1'
  AND NOT EXISTS (
      SELECT 1 FROM public."Tickets" t
      WHERE t."BranchId" = b."Id" AND t."TechnicianId" = u."Id"
        AND t."Title" = 'Demo: conexión intermitente'
  );

-- Aporta información previa descriptiva sin inventar archivos de fotografía.
-- TicketId se obtiene por la relación demo y la descripción evita repetir la evidencia.
INSERT INTO public."Evidences" ("TicketId", "Description", "PhotoPath", "CreatedAt")
SELECT t."Id", 'Demo: se revisó el cableado y continúa el diagnóstico.', NULL,
       TIMESTAMPTZ '2026-01-15 11:30:00+00'
FROM public."Tickets" t
JOIN public."Users" u ON u."Id" = t."TechnicianId"
JOIN public."Branches" b ON b."Id" = t."BranchId"
WHERE u."Username" = 'tecnico1' AND t."Title" = 'Demo: conexión intermitente'
  AND b."Name" = 'Sucursal Demo Norte' AND b."Address" = 'Avenida Demo 20, Norte'
  AND NOT EXISTS (
      SELECT 1 FROM public."Evidences" e
      WHERE e."TicketId" = t."Id"
        AND e."Description" = 'Demo: se revisó el cableado y continúa el diagnóstico.'
  );

COMMIT;

SELECT "Id", "Username", "Name", "RoleId", "IsActive" FROM public."Users" WHERE "Username" = 'tecnico1';

SELECT t."Id", t."Title", t."Status", t."ScheduledAt", b."Name" AS "Branch"
FROM public."Tickets" t
JOIN public."Branches" b ON b."Id" = t."BranchId"
JOIN public."Users" u ON u."Id" = t."TechnicianId"
WHERE u."Username" = 'tecnico1' AND t."Title" IN
    ('Demo: revisión de equipo', 'Demo: conexión intermitente');
```

La muestra requiere el esquema nuevo con Roles, RoleId, IsActive y ScheduledAt. Primero aplicar ACTUALIZACION_POSTGRESQL.md en una base existente, o DATABASE.md en una nueva. Roles base se instalan como referencias funcionales; este documento solo añade desarrollo/demo y asigna tecnico1 al rol 2. No ejecutar sobre producción.
