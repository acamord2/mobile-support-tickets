# Vista equivalente de agenda SQL Server

SQL Server documentado/no validado contra instancia real. Esta vista equivale a public.agenda_tickets; el futuro acceso de datos deberá filtrar TechnicianId con identidad autenticada. GO separa lotes y CREATE OR ALTER VIEW ocupa su propio lote.

```sql
USE [tickets_db];
GO
-- Combina campos públicos del ticket y sucursal para descarga de agenda,
-- dejando identidad y orden parametrizados en el acceso a datos del motor.
CREATE OR ALTER VIEW dbo.agenda_tickets AS
SELECT t.[Id], t.[BranchId], t.[TechnicianId], t.[Title], t.[Description], t.[Status],
       t.[CreatedAt], t.[UpdatedAt], t.[ScheduledAt], t.[ClientRequestId],
       b.[Name] AS [BranchName], b.[Address] AS [BranchAddress]
FROM dbo.[Tickets] t JOIN dbo.[Branches] b ON b.[Id] = t.[BranchId];
GO
```
