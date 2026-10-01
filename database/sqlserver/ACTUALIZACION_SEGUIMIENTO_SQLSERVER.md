# Propuesta de actualización de seguimiento — SQL Server

Solo documental, no ejecutada ni validada contra instancia real. PostgreSQL sigue siendo runtime. Pendiente de aprobación; este archivo no añade proveedor SQL Server a la API.

DATABASE_SQLSERVER.md conserva la definición canónica; este script reproduce el bloque TicketEvents y la clave compuesta de Evidences necesarios para una base existente compatible. No modifica datos, no genera eventos históricos y no crea triggers, funciones ni vistas. Los guards permiten repetir una instalación compatible; no corrigen objetos preexistentes con otra definición.

```sql
USE [tickets_db];
GO
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM sys.key_constraints
        WHERE parent_object_id = OBJECT_ID(N'dbo.Evidences') AND name = N'UQ_Evidences_TicketId_Id')
        ALTER TABLE dbo.[Evidences]
            ADD CONSTRAINT [UQ_Evidences_TicketId_Id] UNIQUE ([TicketId], [Id]);

    IF OBJECT_ID(N'dbo.TicketEvents', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.[TicketEvents] (
            [Id] int IDENTITY(1,1) NOT NULL CONSTRAINT [PK_TicketEvents] PRIMARY KEY,
            [TicketId] int NOT NULL,
            [EventType] nvarchar(20) COLLATE Latin1_General_100_BIN2 NOT NULL,
            [Description] nvarchar(max) NOT NULL,
            [CreatedAt] datetimeoffset(7) NOT NULL,
            [UserId] int NOT NULL,
            [ClientRequestId] uniqueidentifier NOT NULL,
            [PreviousScheduledAt] datetimeoffset(7) NULL,
            [ScheduledAt] datetimeoffset(7) NULL,
            [EvidenceId] int NULL,
            CONSTRAINT [FK_TicketEvents_Tickets] FOREIGN KEY ([TicketId]) REFERENCES dbo.[Tickets] ([Id]) ON DELETE NO ACTION,
            CONSTRAINT [FK_TicketEvents_Users] FOREIGN KEY ([UserId]) REFERENCES dbo.[Users] ([Id]) ON DELETE NO ACTION,
            CONSTRAINT [UQ_TicketEvents_UserId_ClientRequestId] UNIQUE ([UserId], [ClientRequestId]),
            CONSTRAINT [FK_TicketEvents_Evidences] FOREIGN KEY ([TicketId], [EvidenceId])
                REFERENCES dbo.[Evidences] ([TicketId], [Id]) ON DELETE NO ACTION,
            CONSTRAINT [CK_TicketEvents_EventType] CHECK (
                [EventType] IN (N'CREADO', N'PROGRAMADO', N'REPROGRAMADO', N'EN_ATENCION', N'SEGUIMIENTO', N'RESUELTO')),
            CONSTRAINT [CK_TicketEvents_Description] CHECK (
                LEN(LTRIM(RTRIM([Description]))) > 0 OR ([EventType] = N'SEGUIMIENTO' AND [EvidenceId] IS NOT NULL)),
            CONSTRAINT [CK_TicketEvents_Evidence] CHECK ([EvidenceId] IS NULL OR [EventType] = N'SEGUIMIENTO'),
            CONSTRAINT [CK_TicketEvents_Schedule] CHECK (
                ([EventType] = N'PROGRAMADO' AND [PreviousScheduledAt] IS NULL AND [ScheduledAt] IS NOT NULL)
                OR ([EventType] = N'REPROGRAMADO' AND [PreviousScheduledAt] IS NOT NULL
                    AND [ScheduledAt] IS NOT NULL AND [PreviousScheduledAt] <> [ScheduledAt])
                OR ([EventType] NOT IN (N'PROGRAMADO', N'REPROGRAMADO')
                    AND [PreviousScheduledAt] IS NULL AND [ScheduledAt] IS NULL))
        );
    END;
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.TicketEvents') AND name = N'IX_TicketEvents_TicketId_CreatedAt_Id')
        CREATE INDEX [IX_TicketEvents_TicketId_CreatedAt_Id] ON dbo.[TicketEvents] ([TicketId], [CreatedAt], [Id]);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
```

Equivalencias: int IDENTITY, nvarchar, datetimeoffset(7), uniqueidentifier NOT NULL y FK NO ACTION. EventType usa collation binaria para conservar los seis tipos exactos. La clave UNIQUE por usuario/UUID no necesita filtro porque el UUID del evento es obligatorio. Validación de fotografía real y autoría JWT corresponde a la futura API.
