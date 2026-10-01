# Procedimientos SQL Server

**SQL Server documentado/no validado contra instancia real.** Requiere DATABASE_SQLSERVER.md aplicado. PostgreSQL continúa como motor runtime; no se implementa AccesoUsuariosSqlServer ni se añade Microsoft.Data.SqlClient.

Único equivalente funcional real:

| PostgreSQL | SQL Server |
|---|---|
| public.get_user_by_username(p_username varchar) | dbo.GetUserByUsername @Username nvarchar(100) |
| SELECT * FROM función parametrizada | Procedimiento parametrizado que devuelve resultset |

```sql
USE [tickets_db];
GO
-- Lee identidad/hash interno de un usuario activo con parámetro, sin SQL dinámico.
-- No revela cuentas inactivas y mantiene las cuatro columnas del contrato interno actual.
CREATE OR ALTER PROCEDURE dbo.[GetUserByUsername]
    @Username nvarchar(100)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.[Id], u.[Username], u.[PasswordHash], u.[Name]
    FROM dbo.[Users] u
    WHERE u.[Username] = @Username
      AND DATALENGTH(u.[Username]) = DATALENGTH(@Username)
      AND u.[IsActive] = 1;
END;
GO
```

CREATE OR ALTER PROCEDURE empieza su propio lote. GO es un separador de SSMS/sqlcmd, no sintaxis para el futuro DbCommand. El parámetro y la collation de Username preservan comparación de mayúsculas; DATALENGTH impide que el padding de comparación SQL Server iguale un nombre con espacios finales a otro sin ellos.

PasswordHash es información interna para PasswordHasher<Usuario>, no una respuesta JSON pública. No usar este procedimiento para imprimir hashes durante verificaciones. La futura implementación Data Access leería el resultset y reutilizaría PasswordHasher: no se cambia el algoritmo por motor. RoleId existe en la tabla; exponer rol en modelos/DTOs y la salida interna queda para después de confirmar la migración PostgreSQL.

No hay procedimientos de Tickets, Views de agenda ni triggers en esta etapa.
