# Actualización de roles y asignación — PostgreSQL

Aplicada y verificada localmente el 01/10/2026, con cero UUID duplicados. Para otra instalación, aplicar una sola vez sobre la base existente. Preserva tickets, eventos y evidencias. ReporterUserId queda nullable para historia cuyo creador no se conoce; las nuevas creaciones lo informan obligatoriamente desde la identidad autenticada. No se utiliza TechnicianId para atribuir reportantes.

```sql
BEGIN;
LOCK TABLE public."Tickets" IN ACCESS EXCLUSIVE MODE;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM public."Tickets" WHERE "ClientRequestId" IS NOT NULL GROUP BY "ClientRequestId" HAVING count(*) > 1) THEN
        RAISE EXCEPTION 'ClientRequestId duplicado; detener actualización';
    END IF;
    IF EXISTS (SELECT 1 FROM public."Roles" WHERE ("Id" = 3 AND "Name" <> 'Coordinador') OR ("Id" = 4 AND "Name" <> 'Usuario')) THEN
        RAISE EXCEPTION 'IDs de roles incompatibles';
    END IF;
END $$;
INSERT INTO public."Roles" ("Id", "Name") VALUES (3, 'Coordinador'), (4, 'Usuario') ON CONFLICT ("Id") DO NOTHING;
ALTER TABLE public."Tickets" ADD COLUMN "ReporterUserId" integer NULL REFERENCES public."Users" ("Id") ON DELETE RESTRICT;
ALTER TABLE public."Tickets" ALTER COLUMN "TechnicianId" DROP NOT NULL;
ALTER TABLE public."Tickets" DROP CONSTRAINT "UQ_Tickets_TechnicianId_ClientRequestId";
ALTER TABLE public."Tickets" ADD CONSTRAINT "UQ_Tickets_ClientRequestId" UNIQUE ("ClientRequestId");
CREATE INDEX "IX_Tickets_ReporterUserId" ON public."Tickets" ("ReporterUserId");
CREATE TABLE public."CoordinatorTechnicians" (
    "CoordinatorUserId" integer NOT NULL REFERENCES public."Users" ("Id") ON DELETE RESTRICT,
    "TechnicianUserId" integer NOT NULL REFERENCES public."Users" ("Id") ON DELETE RESTRICT,
    "CreatedAt" timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY ("CoordinatorUserId", "TechnicianUserId")
);
CREATE INDEX "IX_CoordinatorTechnicians_TechnicianUserId" ON public."CoordinatorTechnicians" ("TechnicianUserId");
ALTER TABLE public."TicketEvents" DROP CONSTRAINT "CK_TicketEvents_EventType";
ALTER TABLE public."TicketEvents" ADD CONSTRAINT "CK_TicketEvents_EventType" CHECK (
    "EventType" IN ('CREADO', 'PROGRAMADO', 'REPROGRAMADO', 'EN_ATENCION', 'SEGUIMIENTO', 'RESUELTO', 'ASIGNADO', 'REASIGNADO'));
COMMIT;
```

La API valida roles de la relación. La identidad de creación permanece estable aunque TechnicianId cambie; PostgreSQL permite múltiples NULL históricos en ClientRequestId. La descripción legible de asignación conserva técnicos anterior/nuevo con nombre e Id; UserId conserva estructuradamente al autor. No se agregan columnas a TicketEvents ni triggers.
