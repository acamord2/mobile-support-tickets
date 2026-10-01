# Actualización manual de PostgreSQL existente

Este archivo evoluciona la BD ya instalada; no es el instalador desde cero. No se ha ejecutado sobre tu base local. La API no ejecuta ni instalará esta migración. Para una instalación nueva usar DATABASE.md directamente y después FUNCIONES_SP.md.

Se añade solo la fecha solicitada: Tickets.ScheduledAt. Users y Branches no tienen fechas actuales que migrar; Evidences.CreatedAt y Tickets.CreatedAt/UpdatedAt se conservan. No se añaden auditorías, UUID, campos de evidencia ni índices especulativos.

## Orden exacto

1. Abrir **un mismo pgAdmin Query Tool conectado a tickets_db** y ejecutar la revisión de estructura siguiente. Comprobar que coincide con DATABASE.md anterior y que no hay personalizaciones incompatibles. Conservar un respaldo antes de modificar la instalación existente.
2. Ejecutar el bloque de migración, que inicia BEGIN y deja la transacción abierta.
3. En **ese mismo Query Tool/conexión**, ejecutar únicamente el bloque SQL canónico de [FUNCIONES_SP.md](FUNCIONES_SP.md): actualiza get_user_by_username para filtrar IsActive = 1. No copiar su Markdown. La definición no se duplica aquí para conservar una sola fuente de funciones.
4. Ejecutar el bloque de verificación dentro de la transacción. Deben existir roles 1/2 correctos, cero usuarios con rol nulo/huérfano, cero valores inválidos de IsActive y cero fechas ScheduledAt nulas. Los roles y fechas programadas ya existentes no se sobrescriben al repetir.
5. Solo si los resultados son correctos, ejecutar COMMIT. Si cualquier paso falla, ejecutar ROLLBACK en esa misma conexión y revisar antes de repetir. No dejar la transacción abierta ni cerrar Query Tool entre los pasos.
6. DATOS_PRUEBA.md es **opcional** y se ejecuta después del COMMIT solo si deseas cargar/ajustar la muestra. La asignación explícita de tecnico1 al rol Técnico vive allí, no como INSERT demo en esta migración.

La separación del paso 3 permite incluir estructura y función en una misma transacción sin duplicar la fuente documental de Functions/SP. Ninguna operación de este ajuste requiere ejecutarse fuera de la transacción. Los ALTER pueden tomar bloqueos durante el trabajo; terminar COMMIT/ROLLBACK en cuanto se revisen resultados.

## 1. Revisar estructura real (solo lectura)

```sql
SELECT current_database();

SELECT table_name, column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('Roles', 'Users', 'Branches', 'Tickets', 'Evidences')
ORDER BY table_name, ordinal_position;

SELECT c.conrelid::regclass AS tabla, c.conname, pg_get_constraintdef(c.oid) AS definicion
FROM pg_constraint c
WHERE c.conrelid IN (
    'public."Users"'::regclass, 'public."Tickets"'::regclass,
    'public."Branches"'::regclass, 'public."Evidences"'::regclass
)
ORDER BY tabla, c.conname;
```

## 2. Migrar estructura y valores existentes

```sql
BEGIN;

-- Protege contra ejecutar por error en otra base o sobre tipos incompatibles.
-- Revisa columnas afectadas antes del ALTER; un conflicto aborta sin borrar datos.
DO $$
BEGIN
    IF current_database() <> 'tickets_db' THEN
        RAISE EXCEPTION 'Selecciona tickets_db antes de aplicar esta actualización.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'Tickets'
          AND column_name = 'CreatedAt' AND data_type = 'timestamp with time zone') THEN
        RAISE EXCEPTION 'Tickets.CreatedAt no coincide con la estructura esperada.';
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND (
            (table_name = 'Users' AND column_name = 'RoleId' AND data_type <> 'integer') OR
            (table_name = 'Users' AND column_name = 'IsActive' AND data_type <> 'smallint') OR
            (table_name = 'Tickets' AND column_name = 'ScheduledAt'
                AND data_type <> 'timestamp with time zone'))) THEN
        RAISE EXCEPTION 'Hay columnas preexistentes con tipos incompatibles; revisar antes de ALTER.';
    END IF;
END;
$$;

-- Catálogo funcional: conserva IDs estables y no introduce cuentas de demostración.
CREATE TABLE IF NOT EXISTS public."Roles" (
    "Id" integer PRIMARY KEY,
    "Name" varchar(100) NOT NULL,
    CONSTRAINT "UQ_Roles_Name" UNIQUE ("Name")
);

-- No reasigna IDs de un catálogo personalizado silenciosamente.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM public."Roles"
        WHERE ("Id" = 1 AND "Name" <> 'Administrador')
           OR ("Id" = 2 AND "Name" <> 'Técnico')
           OR ("Name" = 'Administrador' AND "Id" <> 1)
           OR ("Name" = 'Técnico' AND "Id" <> 2)) THEN
        RAISE EXCEPTION 'El catálogo Roles existente no coincide con los IDs funcionales 1/2.';
    END IF;
END;
$$;

INSERT INTO public."Roles" ("Id", "Name")
VALUES (1, 'Administrador'), (2, 'Técnico')
ON CONFLICT ("Id") DO NOTHING;

-- La línea base anterior solo tenía técnicos; completa únicamente los roles ausentes.
-- Si ya se asignó un administrador u otro rol válido, conserva esa asignación.
ALTER TABLE public."Users" ADD COLUMN IF NOT EXISTS "RoleId" integer;
UPDATE public."Users" SET "RoleId" = 2 WHERE "RoleId" IS NULL;
ALTER TABLE public."Users" ALTER COLUMN "RoleId" SET DEFAULT 2;
ALTER TABLE public."Users" ALTER COLUMN "RoleId" SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public."Users"'::regclass AND conname = 'FK_Users_Roles') THEN
        ALTER TABLE public."Users" ADD CONSTRAINT "FK_Users_Roles"
            FOREIGN KEY ("RoleId") REFERENCES public."Roles" ("Id") ON DELETE RESTRICT;
    END IF;
END;
$$;

-- Inicializa los usuarios de la estructura anterior como activos.
-- Una segunda ejecución conserva cualquier desactivación deliberada ya registrada.
ALTER TABLE public."Users" ADD COLUMN IF NOT EXISTS "IsActive" smallint;
UPDATE public."Users" SET "IsActive" = 1 WHERE "IsActive" IS NULL;
ALTER TABLE public."Users" ALTER COLUMN "IsActive" SET DEFAULT 1;
ALTER TABLE public."Users" ALTER COLUMN "IsActive" SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public."Users"'::regclass AND conname = 'CK_Users_IsActive') THEN
        ALTER TABLE public."Users" ADD CONSTRAINT "CK_Users_IsActive"
            CHECK ("IsActive" IN (0, 1));
    END IF;
END;
$$;

-- Inicialización de la cita solo donde falta; no reemplaza fechas de creación/modificación.
ALTER TABLE public."Tickets" ADD COLUMN IF NOT EXISTS "ScheduledAt" timestamptz;
UPDATE public."Tickets" SET "ScheduledAt" = "CreatedAt" WHERE "ScheduledAt" IS NULL;
ALTER TABLE public."Tickets" ALTER COLUMN "ScheduledAt" SET NOT NULL;

-- NO hacer COMMIT todavía: ejecutar ahora el SQL de FUNCIONES_SP.md en esta conexión.
```

## 3. Actualizar función canónica

Copiar el bloque SQL de FUNCIONES_SP.md y ejecutarlo en la transacción todavía abierta. Su salida interna conserva Id, Username, PasswordHash y Name; únicamente añade el filtro IsActive = 1. No se cambia el tipo de retorno ni se elimina la función. No usar la versión anterior sin ese filtro para confirmar la migración.

## 4. Verificación, sin exponer hashes

```sql
SELECT "Id", "Name" FROM public."Roles" ORDER BY "Id";

SELECT count(*) AS usuarios_sin_rol
FROM public."Users" u LEFT JOIN public."Roles" r ON r."Id" = u."RoleId"
WHERE u."RoleId" IS NULL OR r."Id" IS NULL;

SELECT count(*) AS usuarios_con_activo_invalido
FROM public."Users" WHERE "IsActive" IS NULL OR "IsActive" NOT IN (0, 1);

SELECT count(*) AS tickets_sin_fecha_programada
FROM public."Tickets" WHERE "ScheduledAt" IS NULL;

SELECT "Id", "Username", "RoleId", "IsActive" FROM public."Users" ORDER BY "Id";
SELECT "Id", "CreatedAt", "ScheduledAt", "UpdatedAt" FROM public."Tickets" ORDER BY "Id";

-- Impide confirmar por olvido si todavía sigue instalada la función anterior.
-- Comprueba el filtro exacto del bloque canónico sin duplicar su definición.
DO $$
BEGIN
    IF position('u."IsActive" = 1' IN
        pg_get_functiondef('public.get_user_by_username(character varying)'::regprocedure)) = 0 THEN
        RAISE EXCEPTION 'Falta actualizar FUNCIONES_SP.md; ejecutar ROLLBACK y repetir el orden completo.';
    END IF;
END;
$$;

-- La función no debe devolver ninguna cuenta inactiva; solo cuenta filas, no muestra hashes.
SELECT count(*) AS inactivos_devuelto_por_login
FROM public."Users" u
CROSS JOIN LATERAL public.get_user_by_username(u."Username") f
WHERE u."IsActive" = 0;
```

## 5. Confirmar o cancelar

Confirmar **solo después** de ejecutar la función y verificar resultados:

```sql
COMMIT;
```

Para cancelar ante un fallo, ejecutar en lugar de COMMIT:

```sql
ROLLBACK;
```

No hay DROP TABLE, DROP DATABASE, TRUNCATE ni eliminación de registros. No se ejecutó este documento. Esperamos tu confirmación de la aplicación antes de actualizar modelos/DTOs, sesión local o Tickets. La desactivación impide nuevos logins tras instalar la función; un JWT ya emitido y una sesión offline no se revocan automáticamente en este ajuste.
