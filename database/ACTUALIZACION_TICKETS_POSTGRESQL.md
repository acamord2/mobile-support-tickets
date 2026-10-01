# Actualización manual de idempotencia y fotografía

Aplicar únicamente en pgAdmin Query Tool conectado a tickets_db, sobre la base ya migrada. Este archivo no se ejecutó. Incluye solo ClientRequestId, su unicidad y PhotoBase64; no repite Roles, RoleId, IsActive ni ScheduledAt. No instala vistas ni funciones de Tickets todavía.

Ejecutar el bloque completo. Si falla, ejecutar ROLLBACK antes de corregir y repetir; no confirmar una transacción fallida. No se borran filas ni se rellenan las nuevas columnas: los registros anteriores conservan NULL. Los ALTER pueden bloquear tablas mientras termina la transacción.

```sql
BEGIN;

-- Comprueba destino y tipos antes de alterar para proteger instalaciones personalizadas.
-- Aborta si las columnas nuevas preexistentes no coinciden con los tipos autorizados.
DO $$
BEGIN
    IF current_database() <> 'tickets_db' THEN
        RAISE EXCEPTION 'Selecciona tickets_db antes de aplicar esta actualización.';
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND (
            (table_name = 'Tickets' AND column_name = 'ClientRequestId' AND data_type <> 'uuid') OR
            (table_name = 'Evidences' AND column_name = 'PhotoBase64' AND data_type <> 'text'))) THEN
        RAISE EXCEPTION 'Las columnas existentes no tienen los tipos autorizados.';
    END IF;
END;
$$;

-- Conserva el Id entero; la clave nullable se generará una sola vez en el móvil.
ALTER TABLE public."Tickets" ADD COLUMN IF NOT EXISTS "ClientRequestId" uuid NULL;

-- Garantiza idempotencia por técnico incluso frente a solicitudes concurrentes.
-- NULL permanece distinto por defecto y permite varios tickets antiguos sin clave.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public."Tickets"'::regclass
          AND conname = 'UQ_Tickets_TechnicianId_ClientRequestId') THEN
        ALTER TABLE public."Tickets"
            ADD CONSTRAINT "UQ_Tickets_TechnicianId_ClientRequestId"
            UNIQUE ("TechnicianId", "ClientRequestId");
    ELSIF NOT EXISTS (SELECT 1 FROM pg_constraint c
        JOIN pg_index i ON i.indexrelid = c.conindid
        WHERE c.conrelid = 'public."Tickets"'::regclass
          AND c.conname = 'UQ_Tickets_TechnicianId_ClientRequestId'
          AND c.contype = 'u' AND c.convalidated
          AND NOT c.condeferrable AND NOT i.indnullsnotdistinct
          AND c.conkey = ARRAY[
              (SELECT attnum FROM pg_attribute WHERE attrelid = c.conrelid AND attname = 'TechnicianId'),
              (SELECT attnum FROM pg_attribute WHERE attrelid = c.conrelid AND attname = 'ClientRequestId')
          ]::smallint[]) THEN
        RAISE EXCEPTION 'La restricción existente no coincide con la unicidad autorizada.';
    END IF;
END;
$$;

-- Añade contenido Base64 completo opcional y conserva PhotoPath para compatibilidad.
ALTER TABLE public."Evidences" ADD COLUMN IF NOT EXISTS "PhotoBase64" text NULL;

-- Verifica las columnas sin exponer fotografías, hashes ni datos personales.
SELECT table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND (
    (table_name = 'Tickets' AND column_name = 'ClientRequestId') OR
    (table_name = 'Evidences' AND column_name IN ('PhotoBase64', 'PhotoPath')))
ORDER BY table_name, column_name;

SELECT c.conname, pg_get_constraintdef(c.oid) AS definicion,
       i.indisunique, i.indnullsnotdistinct
FROM pg_constraint c JOIN pg_index i ON i.indexrelid = c.conindid
WHERE c.conrelid = 'public."Tickets"'::regclass
  AND c.conname = 'UQ_Tickets_TechnicianId_ClientRequestId';

SELECT count(*) AS pares_duplicados
FROM (
    SELECT "TechnicianId", "ClientRequestId"
    FROM public."Tickets"
    WHERE "ClientRequestId" IS NOT NULL
    GROUP BY "TechnicianId", "ClientRequestId"
    HAVING count(*) > 1
) duplicados;

COMMIT;
```

Resultados esperados: ClientRequestId uuid nullable; PhotoBase64 text nullable; PhotoPath conservado; restricción UNIQUE por las dos columnas, indisunique=true, indnullsnotdistinct=false y cero pares duplicados. La BD garantiza unicidad de claves presentes sin impedir varios NULL por técnico.

La futura API debe devolver el ticket existente al repetir la clave, manejando el conflicto concurrente. SQLite conservará client_request_id con id_local e id_remoto independientes. Para fotografía, se comprimirá antes de Base64 y se validará 1 MB de bytes decodificados; no se trunca contenido. No se implementa runtime hasta confirmar esta actualización manual.
