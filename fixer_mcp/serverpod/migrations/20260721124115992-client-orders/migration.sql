BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "order" (
    "id" bigserial PRIMARY KEY,
    "clientId" uuid NOT NULL,
    "title" text NOT NULL,
    "description" text NOT NULL,
    "status" text NOT NULL,
    "createdAt" timestamp without time zone NOT NULL,
    "updatedAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE INDEX "order_client_updated_idx" ON "order" USING btree ("clientId", "updatedAt");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "revision" (
    "id" bigserial PRIMARY KEY,
    "orderId" bigint NOT NULL,
    "revisionNumber" bigint NOT NULL,
    "description" text NOT NULL,
    "status" text NOT NULL,
    "branchName" text,
    "previewUrl" text,
    "createdAt" timestamp without time zone NOT NULL,
    "updatedAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "revision_order_number_idx" ON "revision" USING btree ("orderId", "revisionNumber");
CREATE INDEX "revision_order_updated_idx" ON "revision" USING btree ("orderId", "updatedAt");


--
-- MIGRATION VERSION FOR fixer_dashboard
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('fixer_dashboard', '20260721124115992-client-orders', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260721124115992-client-orders', "timestamp" = now();

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
