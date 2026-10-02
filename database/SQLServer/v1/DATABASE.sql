-- Equivalente documental; ejecutar en una base vacía de SQL Server.
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.Roles', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.[Roles] (
            [Id] int NOT NULL CONSTRAINT [PK_Roles] PRIMARY KEY,
            [Name] nvarchar(100) NOT NULL,
            CONSTRAINT [UQ_Roles_Name] UNIQUE ([Name])
        );
    END;




    IF OBJECT_ID(N'dbo.Users', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.[Users] (
            [Id] int IDENTITY(1,1) NOT NULL CONSTRAINT [PK_Users] PRIMARY KEY,
            [Username] nvarchar(100) COLLATE Latin1_General_100_BIN2 NOT NULL,
            [PasswordHash] nvarchar(max) NOT NULL,
            [Name] nvarchar(200) NOT NULL,
            [RoleId] int NOT NULL CONSTRAINT [DF_Users_RoleId] DEFAULT (2),
            [IsActive] bit NOT NULL CONSTRAINT [DF_Users_IsActive] DEFAULT (1),
            CONSTRAINT [UQ_Users_Username] UNIQUE ([Username]),
            CONSTRAINT [FK_Users_Roles] FOREIGN KEY ([RoleId]) REFERENCES dbo.[Roles] ([Id]) ON DELETE NO ACTION
        );
    END;

    IF OBJECT_ID(N'dbo.CoordinatorTechnicians', N'U') IS NULL
        CREATE TABLE dbo.CoordinatorTechnicians (
            CoordinatorUserId INT NOT NULL REFERENCES dbo.Users(Id),
            TechnicianUserId INT NOT NULL REFERENCES dbo.Users(Id),
            CreatedAt DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
            PRIMARY KEY (CoordinatorUserId,TechnicianUserId)
        );
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.CoordinatorTechnicians') AND name=N'IX_CoordinatorTechnicians_TechnicianUserId')
        CREATE INDEX IX_CoordinatorTechnicians_TechnicianUserId ON dbo.CoordinatorTechnicians(TechnicianUserId);

    IF OBJECT_ID(N'dbo.Branches', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.[Branches] (
            [Id] int IDENTITY(1,1) NOT NULL CONSTRAINT [PK_Branches] PRIMARY KEY,
            [Name] nvarchar(200) NOT NULL,
            [Address] nvarchar(500) NOT NULL
        );
    END;

    IF OBJECT_ID(N'dbo.Tickets', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.[Tickets] (
            [Id] int IDENTITY(1,1) NOT NULL CONSTRAINT [PK_Tickets] PRIMARY KEY,
            [BranchId] int NOT NULL,
            [TechnicianId] int NULL,
            [ReporterUserId] int NULL,
            [Title] nvarchar(200) NOT NULL,
            [Description] nvarchar(max) NOT NULL,
            [Status] nvarchar(20) COLLATE Latin1_General_100_BIN2 NOT NULL,
            [CreatedAt] datetimeoffset(7) NOT NULL,
            [UpdatedAt] datetimeoffset(7) NOT NULL,
            [ScheduledAt] datetimeoffset(7) NULL,
            [ClientRequestId] uniqueidentifier NULL,
            CONSTRAINT [FK_Tickets_Branches] FOREIGN KEY ([BranchId]) REFERENCES dbo.[Branches] ([Id]) ON DELETE NO ACTION,
            CONSTRAINT [FK_Tickets_ReporterUserId] FOREIGN KEY ([ReporterUserId]) REFERENCES dbo.[Users] ([Id]) ON DELETE NO ACTION,
            CONSTRAINT [FK_Tickets_Users] FOREIGN KEY ([TechnicianId]) REFERENCES dbo.[Users] ([Id]) ON DELETE NO ACTION,
            CONSTRAINT [CK_Tickets_Status] CHECK ([Status] IN (N'Pending', N'InProgress', N'Resolved', N'Cancelled')),
            CONSTRAINT [CK_Tickets_Dates] CHECK ([UpdatedAt] >= [CreatedAt])
        );
    END;

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Tickets') AND name = N'UQ_Tickets_ClientRequestId')
        CREATE UNIQUE INDEX [UQ_Tickets_ClientRequestId]
            ON dbo.[Tickets] ([ClientRequestId])
            WHERE [ClientRequestId] IS NOT NULL;
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Tickets') AND name = N'IX_Tickets_BranchId')
        CREATE INDEX [IX_Tickets_BranchId] ON dbo.[Tickets] ([BranchId]);
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Tickets') AND name = N'IX_Tickets_TechnicianId_Status')
        CREATE INDEX [IX_Tickets_TechnicianId_Status] ON dbo.[Tickets] ([TechnicianId], [Status]);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.Tickets') AND name=N'IX_Tickets_ReporterUserId')
        CREATE INDEX IX_Tickets_ReporterUserId ON dbo.Tickets(ReporterUserId);

    IF OBJECT_ID(N'dbo.Evidences', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.[Evidences] (
            [Id] int IDENTITY(1,1) NOT NULL CONSTRAINT [PK_Evidences] PRIMARY KEY,
            [TicketId] int NOT NULL,
            [Description] nvarchar(max) NOT NULL,
            [PhotoPath] nvarchar(max) NULL,
            [PhotoBase64] nvarchar(max) NULL,
            [CreatedAt] datetimeoffset(7) NOT NULL,
            CONSTRAINT [FK_Evidences_Tickets] FOREIGN KEY ([TicketId]) REFERENCES dbo.[Tickets] ([Id]) ON DELETE NO ACTION,
            CONSTRAINT [UQ_Evidences_TicketId_Id] UNIQUE ([TicketId], [Id])
        );
    END;
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Evidences') AND name = N'IX_Evidences_TicketId')
        CREATE INDEX [IX_Evidences_TicketId] ON dbo.[Evidences] ([TicketId]);

    IF OBJECT_ID(N'dbo.TicketEvents', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.[TicketEvents] (
            [Id] int IDENTITY(1,1) NOT NULL CONSTRAINT [PK_TicketEvents] PRIMARY KEY,
            [TicketId] int NOT NULL,
            [EventType] nvarchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
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
                [EventType] IN (N'CREADO', N'PROGRAMADO', N'REPROGRAMADO', N'EN_ATENCION', N'SEGUIMIENTO', N'RESUELTO', N'ASIGNADO', N'REASIGNADO', N'SOLICITUD_RESOLUCION', N'SOLICITUD_CANCELACION', N'RESOLUCION_APROBADA', N'RESOLUCION_RECHAZADA', N'CANCELACION_APROBADA', N'CANCELACION_RECHAZADA', N'CANCELADO')),
            CONSTRAINT [CK_TicketEvents_Description] CHECK (
                LEN(LTRIM(RTRIM([Description]))) > 0 OR ([EventType] = N'SEGUIMIENTO' AND [EvidenceId] IS NOT NULL)),
            CONSTRAINT [CK_TicketEvents_Evidence] CHECK ([EvidenceId] IS NULL OR [EventType] IN (N'CREADO',N'SEGUIMIENTO')),
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

    IF OBJECT_ID(N'dbo.TicketStatusRequests', N'U') IS NULL
    BEGIN
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
    END;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
