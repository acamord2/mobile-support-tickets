CREATE OR ALTER VIEW dbo.agenda_tickets AS
SELECT t.[Id], t.[BranchId], t.[TechnicianId], t.[Title], t.[Description], t.[Status],
       t.[CreatedAt], t.[UpdatedAt], t.[ScheduledAt], t.[ClientRequestId],
       b.[Name] AS [BranchName], b.[Address] AS [BranchAddress]
FROM dbo.[Tickets] t JOIN dbo.[Branches] b ON b.[Id] = t.[BranchId];
GO
