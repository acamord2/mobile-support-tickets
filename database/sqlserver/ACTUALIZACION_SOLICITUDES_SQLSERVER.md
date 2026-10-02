# Equivalente SQL Server — solo documentación

No ejecutado. Conserva las tablas existentes y las FK sin cascadas.

```sql
SET XACT_ABORT ON;
BEGIN TRY
BEGIN TRANSACTION;
ALTER TABLE dbo.Tickets ALTER COLUMN ScheduledAt datetimeoffset(7) NULL;
ALTER TABLE dbo.Tickets DROP CONSTRAINT CK_Tickets_Status;
ALTER TABLE dbo.Tickets ADD CONSTRAINT CK_Tickets_Status CHECK (Status IN ('Pending','InProgress','Resolved','Cancelled'));
ALTER TABLE dbo.TicketEvents DROP CONSTRAINT CK_TicketEvents_EventType;
ALTER TABLE dbo.TicketEvents ALTER COLUMN EventType nvarchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL;
ALTER TABLE dbo.TicketEvents ADD CONSTRAINT CK_TicketEvents_EventType CHECK (EventType IN ('CREADO','PROGRAMADO','REPROGRAMADO','EN_ATENCION','SEGUIMIENTO','RESUELTO','ASIGNADO','REASIGNADO','SOLICITUD_RESOLUCION','SOLICITUD_CANCELACION','RESOLUCION_APROBADA','RESOLUCION_RECHAZADA','CANCELACION_APROBADA','CANCELACION_RECHAZADA','CANCELADO'));
ALTER TABLE dbo.TicketEvents DROP CONSTRAINT CK_TicketEvents_Evidence;
ALTER TABLE dbo.TicketEvents ADD CONSTRAINT CK_TicketEvents_Evidence CHECK (EvidenceId IS NULL OR EventType IN ('CREADO','SEGUIMIENTO'));
CREATE TABLE dbo.TicketStatusRequests (
    Id int IDENTITY(1,1) PRIMARY KEY,
    TicketId int NOT NULL REFERENCES dbo.Tickets(Id) ON DELETE NO ACTION,
    RequesterUserId int NOT NULL REFERENCES dbo.Users(Id) ON DELETE NO ACTION,
    Type nvarchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Reason nvarchar(max) NULL,
    Status nvarchar(20) COLLATE Latin1_General_100_BIN2 NOT NULL DEFAULT 'PENDIENTE',
    CreatedAt datetimeoffset(7) NOT NULL,
    ReviewedByUserId int NULL REFERENCES dbo.Users(Id) ON DELETE NO ACTION,
    ReviewedAt datetimeoffset(7) NULL,
    ClientRequestId uniqueidentifier NOT NULL,
    CONSTRAINT UQ_TicketStatusRequests_ClientRequestId UNIQUE (ClientRequestId),
    CONSTRAINT CK_TicketStatusRequests_Type CHECK (Type IN ('SOLICITUD_RESOLUCION','SOLICITUD_CANCELACION')),
    CONSTRAINT CK_TicketStatusRequests_Status CHECK (Status IN ('PENDIENTE','APROBADA','RECHAZADA')),
    CONSTRAINT CK_TicketStatusRequests_Reason CHECK (Type <> 'SOLICITUD_CANCELACION' OR (Reason IS NOT NULL AND LEN(LTRIM(RTRIM(Reason))) > 0)),
    CONSTRAINT CK_TicketStatusRequests_Review CHECK (
        (Status='PENDIENTE' AND ReviewedByUserId IS NULL AND ReviewedAt IS NULL)
        OR (Status IN ('APROBADA','RECHAZADA') AND ReviewedByUserId IS NOT NULL AND ReviewedAt IS NOT NULL))
);
CREATE INDEX IX_TicketStatusRequests_TicketId ON dbo.TicketStatusRequests(TicketId);
CREATE INDEX IX_TicketStatusRequests_Status_CreatedAt ON dbo.TicketStatusRequests(Status,CreatedAt,Id);
COMMIT TRANSACTION;
END TRY
BEGIN CATCH
IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
THROW;
END CATCH;
```
