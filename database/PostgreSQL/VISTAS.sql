CREATE OR REPLACE VIEW public.agenda_tickets AS
 SELECT t."Id",
    t."BranchId",
    t."TechnicianId",
    t."Title",
    t."Description",
    t."Status",
    t."CreatedAt",
    t."UpdatedAt",
    t."ScheduledAt",
    t."ClientRequestId",
    b."Name" AS "BranchName",
    b."Address" AS "BranchAddress"
   FROM ("Tickets" t
     JOIN "Branches" b ON ((b."Id" = t."BranchId")));
