BEGIN;

--
-- ACTION ALTER TABLE
--
-- Keep existing client orders while adding the order-flow columns. The
-- Serverpod analyzer asks for a table recreation when a JSON column is added,
-- but these columns are safe to add in place and existing rows must survive.
ALTER TABLE "order"
    ADD COLUMN "projectDescription" text NOT NULL DEFAULT '',
    ADD COLUMN "budgetCents" bigint NOT NULL DEFAULT 0,
    ADD COLUMN "assignedProjectId" bigint;

UPDATE "order"
SET "projectDescription" = "description"
WHERE "projectDescription" = '';

ALTER TABLE "order"
    ALTER COLUMN "projectDescription" DROP DEFAULT,
    ALTER COLUMN "budgetCents" DROP DEFAULT;

-- Indexes
CREATE INDEX "order_status_updated_idx" ON "order" USING btree ("status", "updatedAt");

--
-- ACTION ALTER TABLE
--
ALTER TABLE "revision"
    ADD COLUMN "revisionText" text NOT NULL DEFAULT '',
    ADD COLUMN "attachmentUrls" json,
    ADD COLUMN "resultSummary" text;

UPDATE "revision"
SET "revisionText" = "description"
WHERE "revisionText" = '';

ALTER TABLE "revision"
    ALTER COLUMN "revisionText" DROP DEFAULT;

-- Indexes


--
-- MIGRATION VERSION FOR fixer_dashboard
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('fixer_dashboard', '20260721175443919-client-order-flow', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260721175443919-client-order-flow', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260129180959368', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260129180959368', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod_auth_core
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_core', '20260129181112269', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260129181112269', "timestamp" = now();


COMMIT;
