-- Revert job-board:jobs from pg

BEGIN;

DROP TABLE jobs;

COMMIT;
