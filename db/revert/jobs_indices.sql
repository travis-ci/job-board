-- Revert job-board:jobs_indices from pg

BEGIN;

DROP INDEX jobs_on_queue;

COMMIT;
