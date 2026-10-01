# Estructura equivalente SQL Server

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
            [TechnicianId] int NOT NULL,
            [Title] nvarchar(200) NOT NULL,
            [Description] nvarchar(max) NOT NULL,
            [Status] nvarchar(20) COLLATE Latin1_General_100_BIN2 NOT NULL,
            [CreatedAt] datetimeoffset(7) NOT NULL,
            [UpdatedAt] datetimeoffset(7) NOT NULL,
            [ScheduledAt] datetimeoffset(7) NOT NULL,
            CONSTRAINT [FK_Tickets_Branches] FOREIGN KEY ([BranchId]) REFERENCES dbo.[Branches] ([Id]) ON DELETE NO ACTION,
            CONSTRAINT [FK_Tickets_Users] FOREIGN KEY ([TechnicianId]) REFERENCES dbo.[Users] ([Id]) ON DELETE NO ACTION,
            CONSTRAINT [CK_Tickets_Status] CHECK ([Status] IN (N'Pending', N'InProgress', N'Resolved')),
            CONSTRAINT [CK_Tickets_Dates] CHECK ([UpdatedAt] >= [CreatedAt])
        );
    END;

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Tickets') AND name = N'IX_Tickets_BranchId')
        CREATE INDEX [IX_Tickets_BranchId] ON dbo.[Tickets] ([BranchId]);
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Tickets') AND name = N'IX_Tickets_TechnicianId_Status')
        CREATE INDEX [IX_Tickets_TechnicianId_Status] ON dbo.[Tickets] ([TechnicianId], [Status]);

    IF OBJECT_ID(N'dbo.Evidences', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.[Evidences] (
            [Id] int IDENTITY(1,1) NOT NULL CONSTRAINT [PK_Evidences] PRIMARY KEY,
            [TicketId] int NOT NULL,
            [Description] nvarchar(max) NOT NULL,
            [PhotoPath] nvarchar(max) NULL,
            [CreatedAt] datetimeoffset(7) NOT NULL,
            CONSTRAINT [FK_Evidences_Tickets] FOREIGN KEY ([TicketId]) REFERENCES dbo.[Tickets] ([Id]) ON DELETE NO ACTION
        );
    END;
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Evidences') AND name = N'IX_Evidences_TicketId')
        CREATE INDEX [IX_Evidences_TicketId] ON dbo.[Evidences] ([TicketId]);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
```

## Equivalencia funcional

Roles usa Id int explícito para referencias estables 1 Administrador / 2 Técnico. Las otras cuatro tablas usan int identity, como PostgreSQL. No se añaden UUID, fechas de auditoría ni objetos de agenda pendientes.

RoleId es FK con default 2. IsActive BIT almacena 0/1 y default 1; SQL Server convierte entradas numéricas a BIT, por lo que la futura API deberá validar entrada lógica y no utilizar el tipo como validador de formularios. Username y Status usan collation binaria para conservar distinción de mayúsculas del contrato actual. Los textos Unicode utilizan NVARCHAR y literales N'...'.

CreatedAt/UpdatedAt/ScheduledAt usan DATETIMEOFFSET(7); la aplicación seguirá escribiendo UTC. PostgreSQL timestamptz conserva el instante normalizado, no el identificador de zona original; SQL Server puede conservar un offset. ScheduledAt es independiente de creación/modificación, sin default que sustituya la cita por la fecha actual.

Evidences mantiene Description, PhotoPath nullable y CreatedAt; no se implementa aún almacenamiento Base64. NVARCHAR(MAX) es la equivalencia de texto largo y podría soportar el campo Base64 futuro, pero no se añade ahora otro campo de imagen. Las FK NO ACTION equivalen al comportamiento restrictivo solicitado, sin cascadas de borrado.

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
UNION ALL SELECT N'Evidences', COUNT_BIG(*) FROM dbo.[Evidences];
```

Resultado previsto: Roles 2, restantes tablas 0. Después ejecutar FUNCIONES_SP_SQLSERVER.md; revisar VISTAS_SQLSERVER.md y TRIGGERS_SQLSERVER.md (sin objetos). DATOS_PRUEBA_SQLSERVER.md se ejecuta opcionalmente solo para desarrollo. No necesita un archivo de actualización SQL Server porque no existe una instalación propia que migrar.
