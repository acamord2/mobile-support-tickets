# Estructura equivalente SQL Server

**Propuesta pendiente:** el bloque TicketEvents y la clave compuesta de Evidences no están instalados. No ejecutar esta definición hasta aprobarla; para una base existente compatible se prepara ACTUALIZACION_SEGUIMIENTO_SQLSERVER.md.

SQL Server está **documentado/no validado contra instancia real**. PostgreSQL sigue siendo el motor runtime actual. No hay proveedor SQL Server ni instancia configurada en esta prueba; este documento no se ejecutó. Requiere SQL Server 2016 SP1 o posterior para CREATE OR ALTER PROCEDURE, SSMS o herramienta compatible con separadores GO.

Este instalador crea una base nueva equivalente a DATABASE.md PostgreSQL. No sirve para migrar una base SQL Server preexistente incompatible. Las comprobaciones OBJECT_ID permiten repetir solo una instalación con el mismo esquema; no alteran tablas antiguas. Los roles 1/2 son referencias funcionales, no cuentas demo.

## Crear base y estructura

CREATE DATABASE y USE se ejecutan fuera de la transacción de tablas; GO separa lotes del cliente y no es una instrucción SQL enviada por la futura API.

```sql
USE [master];
GO
IF DB_ID(N'tickets_db') IS NULL
    CREATE DATABASE [tickets_db];
GO
USE [tickets_db];
GO
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

    IF EXISTS (SELECT 1 FROM dbo.[Roles]
        WHERE ([Id] = 1 AND [Name] <> N'Administrador')
           OR ([Id] = 2 AND [Name] <> N'Técnico')
           OR ([Name] = N'Administrador' AND [Id] <> 1)
           OR ([Name] = N'Técnico' AND [Id] <> 2))
        THROW 50001, N'El catálogo Roles no coincide con los IDs funcionales 1/2.', 1;

    INSERT INTO dbo.[Roles] ([Id], [Name])
    SELECT 1, N'Administrador' WHERE NOT EXISTS (SELECT 1 FROM dbo.[Roles] WHERE [Id] = 1);
    INSERT INTO dbo.[Roles] ([Id], [Name])
    SELECT 2, N'Técnico' WHERE NOT EXISTS (SELECT 1 FROM dbo.[Roles] WHERE [Id] = 2);

    INSERT INTO dbo.[Roles] ([Id],[Name]) SELECT 3,N'Coordinador' WHERE NOT EXISTS (SELECT 1 FROM dbo.[Roles] WHERE [Id]=3);
    INSERT INTO dbo.[Roles] ([Id],[Name]) SELECT 4,N'Usuario' WHERE NOT EXISTS (SELECT 1 FROM dbo.[Roles] WHERE [Id]=4);

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
```

## Equivalencia funcional

Roles usa Id int explícito para referencias estables 1 Administrador / 2 Técnico. Las tablas de negocio y usuarios usan int identity, como PostgreSQL. Los UUID de tickets y eventos sirven para reintentos; no se añaden objetos de agenda ni auditoría avanzada.

RoleId es FK con default 2. IsActive BIT almacena 0/1 y default 1; SQL Server convierte entradas numéricas a BIT, por lo que la futura API deberá validar entrada lógica y no utilizar el tipo como validador de formularios. Username y Status usan collation binaria para conservar distinción de mayúsculas del contrato actual. Los textos Unicode utilizan NVARCHAR y literales N'...'.

CreatedAt/UpdatedAt/ScheduledAt usan DATETIMEOFFSET(7); la aplicación seguirá escribiendo UTC. PostgreSQL timestamptz conserva el instante normalizado, no el identificador de zona original; SQL Server puede conservar un offset. ScheduledAt es independiente de creación/modificación, sin default que sustituya la cita por la fecha actual.

Evidences mantiene Description, PhotoPath nullable y CreatedAt; PhotoBase64 nullable prepara el almacenamiento Base64 autorizado; todavía no se implementa procesamiento runtime. NVARCHAR(MAX) es la equivalencia de texto largo y podría soportar el campo Base64 futuro, y se usa directamente para PhotoBase64, conservando PhotoPath. Las FK NO ACTION equivalen al comportamiento restrictivo solicitado, sin cascadas de borrado.

## Verificación de una instalación nueva

```sql
USE [tickets_db];
GO
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'dbo'
ORDER BY TABLE_NAME, ORDINAL_POSITION;

SELECT N'Roles' AS tabla, COUNT_BIG(*) AS filas FROM dbo.[Roles]
UNION ALL SELECT N'Users', COUNT_BIG(*) FROM dbo.[Users]
UNION ALL SELECT N'Branches', COUNT_BIG(*) FROM dbo.[Branches]
UNION ALL SELECT N'Tickets', COUNT_BIG(*) FROM dbo.[Tickets]
UNION ALL SELECT N'Evidences', COUNT_BIG(*) FROM dbo.[Evidences]
UNION ALL SELECT N'TicketEvents', COUNT_BIG(*) FROM dbo.[TicketEvents];
```

Resultado previsto: Roles 2, restantes tablas 0. Después ejecutar FUNCIONES_SP_SQLSERVER.md; revisar VISTAS_SQLSERVER.md y TRIGGERS_SQLSERVER.md (sin objetos). DATOS_PRUEBA_SQLSERVER.md se ejecuta opcionalmente solo para desarrollo. Para una instalación existente compatible, la propuesta de seguimiento se prepara en ACTUALIZACION_SEGUIMIENTO_SQLSERVER.md, sin ejecución.

## Idempotencia y fotografía equivalentes

ClientRequestId UNIQUEIDENTIFIER NULL es una clave móvil persistente independiente del Id int. El índice UNIQUE filtrado por ClientRequestId IS NOT NULL garantiza unicidad por técnico para claves presentes y permite múltiples tickets sin clave, como PostgreSQL. No usar un UNIQUE compuesto sin filtro: SQL Server trata NULL de forma distinta. El filtro evita restringir los tickets antiguos sin identificador.

PhotoBase64 NVARCHAR(MAX) NULL almacena el contenido íntegro sin prefijo, conservando PhotoPath. El límite futuro de 1 MB se aplica sobre los bytes de imagen comprimidos/decodificados, no sobre longitud textual. No hay datos demo ni claves generadas nuevas en este ajuste.

SQL Server documentado/no validado contra instancia real. La actualización de seguimiento es únicamente documental; no existe provider runtime SQL Server. Referencia: [CREATE INDEX y filtro](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-index-transact-sql).


## TicketEvents — propuesta no instalada

Equivale a TicketEvents de PostgreSQL: mismos diez campos, seis tipos, autor FK, UUID obligatorio por usuario, programación anterior/nueva y enlace opcional a Evidence del mismo Ticket mediante FK compuesta. Se añaden UQ_Evidences_TicketId_Id e índice cronológico TicketId/CreatedAt/Id. No hay Base64 en eventos, datos demo, backfill, nuevos triggers o SP. Las fechas se escribirán UTC conservando el instante del evento offline.

El diseño de autoría, previsualización, SQLite y reutilización de cola se detalla en DATABASE.md de PostgreSQL. Esta definición de instalación nueva anticipa la propuesta; debe aprobarse antes de ejecutarla. SQL Server permanece documental/no validado contra instancia real.

## Portabilidad de roles y asignación

IDs: 1 Administrador, 2 Técnico, 3 Coordinador, 4 Usuario. ReporterUserId y TechnicianId nullable, identidad global ClientRequestId mediante índice único filtrado, relación CoordinatorTechnicians y ocho tipos de evento. ACTUALIZACION_ROLES_ASIGNACION_SQLSERVER.md migra una instalación compatible; no fue ejecutada. Las reglas y límites del alcance se describen en DATABASE.md de PostgreSQL.

## Solicitudes

ScheduledAt nullable, Cancelled y TicketStatusRequests corresponden a ACTUALIZACION_SOLICITUDES_SQLSERVER.md. Equivalente documental, sin ejecución SQL Server.
