-- Revert job-board:appschema from pg

BEGIN;

DROP SCHEMA job_board;

COMMIT;
