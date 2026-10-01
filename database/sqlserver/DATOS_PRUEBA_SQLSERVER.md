# Datos demo SQL Server

**SQL Server documentado/no validado contra instancia real.** Ejecutar solo en una instalación nueva de desarrollo creada con DATABASE_SQLSERVER.md y FUNCIONES_SP_SQLSERVER.md. La API actual no se conecta a este motor ni ejecuta seed.

Credencial pública demo: **tecnico1 / Demo123*** (Técnico Demo), exclusivamente para pruebas. Se reutiliza exactamente el hash verificado de DATOS_PRUEBA.md, generado por PasswordHasher<Usuario> .NET 10; no se usa HASHBYTES ni hashing propio del motor.

Los roles base 1 Administrador / 2 Técnico se instalan en DATABASE_SQLSERVER.md como referencias funcionales. Este archivo no duplica su INSERT: verifica que existan y crea un técnico, dos sucursales, dos tickets y una evidencia descriptiva sin foto, equivalentes a PostgreSQL.

Los INSERT son repetibles de forma secuencial, no un cargador concurrente. No reemplazan passwords, estados de Tickets o fechas programadas existentes. La asignación explícita del usuario demo a Técnico sí se aplica al repetir; no se reactiva una cuenta desactivada previamente. Revisar duplicados preexistentes de sucursales antes de ejecutar.

```sql
USE [tickets_db];
GO
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    IF NOT EXISTS (SELECT 1 FROM dbo.[Roles] WHERE [Id] = 1 AND [Name] = N'Administrador')
       OR NOT EXISTS (SELECT 1 FROM dbo.[Roles] WHERE [Id] = 2 AND [Name] = N'Técnico')
        THROW 50002, N'Instalar primero el catálogo funcional de DATABASE_SQLSERVER.md.', 1;

    -- Inserta solo la cuenta demo ausente sin sustituir el hash existente.
    IF NOT EXISTS (SELECT 1 FROM dbo.[Users] WHERE [Username] = N'tecnico1')
        INSERT INTO dbo.[Users] ([Username], [PasswordHash], [Name], [RoleId], [IsActive])
        VALUES (N'tecnico1', N'AQAAAAIAAYagAAAAECG6+xJ1OmiicKseDoLWq//XHERs/rdTMrsLDXb0cG0M1yctPgH/ccHy5f0oMZfJOw==', N'Técnico Demo', 2, 1);
    UPDATE dbo.[Users] SET [RoleId] = 2 WHERE [Username] = N'tecnico1';

    -- Localiza cada sucursal por nombre y dirección, igual que la muestra PostgreSQL.
    IF NOT EXISTS (SELECT 1 FROM dbo.[Branches] WHERE [Name] = N'Sucursal Demo Centro' AND [Address] = N'Calle Demo 10, Centro')
        INSERT INTO dbo.[Branches] ([Name], [Address]) VALUES (N'Sucursal Demo Centro', N'Calle Demo 10, Centro');
    IF NOT EXISTS (SELECT 1 FROM dbo.[Branches] WHERE [Name] = N'Sucursal Demo Norte' AND [Address] = N'Avenida Demo 20, Norte')
        INSERT INTO dbo.[Branches] ([Name], [Address]) VALUES (N'Sucursal Demo Norte', N'Avenida Demo 20, Norte');

    -- Mantiene creación, modificación y cita como columnas separadas con instantes UTC.
    INSERT INTO dbo.[Tickets] ([BranchId], [TechnicianId], [Title], [Description], [Status], [CreatedAt], [UpdatedAt], [ScheduledAt])
    SELECT b.[Id], u.[Id], N'Demo: revisión de equipo', N'El equipo de la sucursal no inicia.', N'Pending',
        CAST('2026-01-15T10:00:00+00:00' AS datetimeoffset(7)),
        CAST('2026-01-15T10:00:00+00:00' AS datetimeoffset(7)),
        CAST('2026-01-15T10:00:00+00:00' AS datetimeoffset(7))
    FROM dbo.[Branches] b CROSS JOIN dbo.[Users] u
    WHERE b.[Name] = N'Sucursal Demo Centro' AND b.[Address] = N'Calle Demo 10, Centro' AND u.[Username] = N'tecnico1'
      AND NOT EXISTS (SELECT 1 FROM dbo.[Tickets] t WHERE t.[BranchId] = b.[Id] AND t.[TechnicianId] = u.[Id] AND t.[Title] = N'Demo: revisión de equipo');

    INSERT INTO dbo.[Tickets] ([BranchId], [TechnicianId], [Title], [Description], [Status], [CreatedAt], [UpdatedAt], [ScheduledAt])
    SELECT b.[Id], u.[Id], N'Demo: conexión intermitente', N'La conexión del equipo se interrumpe ocasionalmente.', N'InProgress',
        CAST('2026-01-15T11:00:00+00:00' AS datetimeoffset(7)),
        CAST('2026-01-15T11:30:00+00:00' AS datetimeoffset(7)),
        CAST('2026-01-15T11:00:00+00:00' AS datetimeoffset(7))
    FROM dbo.[Branches] b CROSS JOIN dbo.[Users] u
    WHERE b.[Name] = N'Sucursal Demo Norte' AND b.[Address] = N'Avenida Demo 20, Norte' AND u.[Username] = N'tecnico1'
      AND NOT EXISTS (SELECT 1 FROM dbo.[Tickets] t WHERE t.[BranchId] = b.[Id] AND t.[TechnicianId] = u.[Id] AND t.[Title] = N'Demo: conexión intermitente');

    -- Evidencia descriptiva previa; no inventa rutas ni imágenes Base64.
    INSERT INTO dbo.[Evidences] ([TicketId], [Description], [PhotoPath], [CreatedAt])
    SELECT t.[Id], N'Demo: se revisó el cableado y continúa el diagnóstico.', NULL,
        CAST('2026-01-15T11:30:00+00:00' AS datetimeoffset(7))
    FROM dbo.[Tickets] t
    JOIN dbo.[Users] u ON u.[Id] = t.[TechnicianId]
    JOIN dbo.[Branches] b ON b.[Id] = t.[BranchId]
    WHERE u.[Username] = N'tecnico1' AND t.[Title] = N'Demo: conexión intermitente'
      AND b.[Name] = N'Sucursal Demo Norte' AND b.[Address] = N'Avenida Demo 20, Norte'
      AND NOT EXISTS (SELECT 1 FROM dbo.[Evidences] e WHERE e.[TicketId] = t.[Id] AND e.[Description] = N'Demo: se revisó el cableado y continúa el diagnóstico.');

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

SELECT [Id], [Username], [Name], [RoleId], [IsActive] FROM dbo.[Users] WHERE [Username] = N'tecnico1';
SELECT t.[Id], t.[Title], t.[Status], t.[ScheduledAt], b.[Name] AS [Branch]
FROM dbo.[Tickets] t
JOIN dbo.[Branches] b ON b.[Id] = t.[BranchId]
JOIN dbo.[Users] u ON u.[Id] = t.[TechnicianId]
WHERE u.[Username] = N'tecnico1' AND t.[Title] IN (N'Demo: revisión de equipo', N'Demo: conexión intermitente');
```

La muestra nueva espera un usuario Técnico activo (RoleId 2, IsActive 1), dos sucursales, dos tickets y una evidencia. Las verificaciones no muestran PasswordHash. Este bloque principal crea solo la muestra del Técnico. El bloque independiente siguiente añade la cuenta administradora demo admin1.


## Administrador admin1 para validar roles

Credencial pública exclusivamente de desarrollo: **admin1 / AdminDemo123***. Nombre: Administrador Demo; RoleId 1 (Administrador), IsActive 1. El hash ASP.NET es exactamente el generado y verificado en DATOS_PRUEBA.md. Este bloque independiente conserva las cuentas existentes. SQL Server continúa documentado, sin validación contra instancia real; no habilita funcionalidades administrativas.

```sql
USE [tickets_db];
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF NOT EXISTS (SELECT 1 FROM dbo.[Roles] WHERE [Id] = 1 AND [Name] = N'Administrador')
    THROW 50003, N'Instalar primero el rol Administrador.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.[Users] WITH (UPDLOCK, HOLDLOCK) WHERE [Username] = N'admin1')
    INSERT INTO dbo.[Users] ([Username], [PasswordHash], [Name], [RoleId], [IsActive])
    VALUES (N'admin1', N'AQAAAAIAAYagAAAAEPeyUp5aPa5HMUJF63XNzJg6pTjdPAUNbC6T+QFbvR+ZZEBAW+TAJvumKNRSkWKO8Q==', N'Administrador Demo', 1, 1);
COMMIT;

SELECT u.[Id], u.[Username], u.[Name], u.[RoleId], r.[Name] AS [Role], u.[IsActive]
FROM dbo.[Users] u JOIN dbo.[Roles] r ON r.[Id] = u.[RoleId]
WHERE u.[Username] = N'admin1';
GO
```

El equivalente admin1 comparte el hash demo de PostgreSQL. SQL Server no se ejecutó ni se validó contra instancia real; la validación local de autenticación/rol corresponde a PostgreSQL y está registrada en DATOS_PRUEBA.md.
