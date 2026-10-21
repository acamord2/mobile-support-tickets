-- Cuenta nueva de consulta, sin cambios sobre cuentas o privilegios PUBLIC existentes.
-- La contraseña se incorpora exclusivamente en memoria por preparar_consultor.py.
\set ON_ERROR_STOP on
BEGIN;
CREATE ROLE consultor_api LOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE
 NOREPLICATION NOBYPASSRLS CONNECTION LIMIT 12;
GRANT CONNECT ON DATABASE tickets_db TO consultor_api;
GRANT USAGE ON SCHEMA public TO consultor_api;
GRANT SELECT ("Id", "Name", "Address") ON TABLE public."Branches" TO consultor_api;
GRANT SELECT ("Id", "BranchId", "TechnicianId", "ReporterUserId", "Title", "Description", "Status", "CreatedAt", "UpdatedAt", "ScheduledAt", "ClientRequestId") ON TABLE public."Tickets" TO consultor_api;
GRANT SELECT ("Id", "Name", "RoleId", "IsActive") ON TABLE public."Users" TO consultor_api;
GRANT SELECT ("CoordinatorUserId", "TechnicianUserId") ON TABLE public."CoordinatorTechnicians" TO consultor_api;
GRANT SELECT ("Id", "TicketId", "Description", "PhotoBase64", "CreatedAt") ON TABLE public."Evidences" TO consultor_api;
GRANT SELECT ("Id", "TicketId", "EventType", "Description", "CreatedAt", "UserId", "ClientRequestId", "PreviousScheduledAt", "ScheduledAt", "EvidenceId") ON TABLE public."TicketEvents" TO consultor_api;
GRANT SELECT ("Id", "TicketId", "RequesterUserId", "Type", "Reason", "Status", "CreatedAt", "ReviewedByUserId", "ReviewedAt", "ClientRequestId") ON TABLE public."TicketStatusRequests" TO consultor_api;
ALTER ROLE consultor_api SET default_transaction_read_only=on;
ALTER ROLE consultor_api SET statement_timeout='3s';
COMMIT;
