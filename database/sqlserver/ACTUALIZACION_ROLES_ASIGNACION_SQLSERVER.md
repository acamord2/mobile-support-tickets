# Actualización de roles y asignación — SQL Server

Equivalente documental, no ejecutado. Aplicar una sola vez a una instalación compatible; preserva reportantes históricos desconocidos como NULL.

```sql
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF EXISTS (SELECT ClientRequestId FROM dbo.Tickets WHERE ClientRequestId IS NOT NULL GROUP BY ClientRequestId HAVING COUNT(*) > 1)
    THROW 50001, 'ClientRequestId duplicado', 1;
IF EXISTS (SELECT 1 FROM dbo.Roles WHERE (Id=3 AND Name<>N'Coordinador') OR (Id=4 AND Name<>N'Usuario'))
    THROW 50002, 'IDs de roles incompatibles', 1;
INSERT INTO dbo.Roles (Id,Name) SELECT 3,N'Coordinador' WHERE NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE Id=3);
INSERT INTO dbo.Roles (Id,Name) SELECT 4,N'Usuario' WHERE NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE Id=4);
ALTER TABLE dbo.Tickets ADD ReporterUserId INT NULL;
ALTER TABLE dbo.Tickets ADD CONSTRAINT FK_Tickets_ReporterUserId FOREIGN KEY (ReporterUserId) REFERENCES dbo.Users(Id);
ALTER TABLE dbo.Tickets ALTER COLUMN TechnicianId INT NULL;
DROP INDEX UQ_Tickets_TechnicianId_ClientRequestId ON dbo.Tickets;
CREATE UNIQUE INDEX UQ_Tickets_ClientRequestId ON dbo.Tickets(ClientRequestId) WHERE ClientRequestId IS NOT NULL;
CREATE INDEX IX_Tickets_ReporterUserId ON dbo.Tickets(ReporterUserId);
CREATE TABLE dbo.CoordinatorTechnicians (
    CoordinatorUserId INT NOT NULL REFERENCES dbo.Users(Id),
    TechnicianUserId INT NOT NULL REFERENCES dbo.Users(Id),
    CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    PRIMARY KEY (CoordinatorUserId,TechnicianUserId)
);
CREATE INDEX IX_CoordinatorTechnicians_TechnicianUserId ON dbo.CoordinatorTechnicians(TechnicianUserId);
ALTER TABLE dbo.TicketEvents DROP CONSTRAINT CK_TicketEvents_EventType;
ALTER TABLE dbo.TicketEvents ADD CONSTRAINT CK_TicketEvents_EventType CHECK (EventType IN ('CREADO','PROGRAMADO','REPROGRAMADO','EN_ATENCION','SEGUIMIENTO','RESUELTO','ASIGNADO','REASIGNADO'));
COMMIT;
```
