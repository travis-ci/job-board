-- Verify job-board:jobs_indices on pg

BEGIN;

SELECT 1/COUNT(*)
FROM pg_catalog.pg_class c
  LEFT JOIN pg_catalog.pg_namespace n
  ON n.oid = c.relnamespace
WHERE c.relkind = 'i'
  AND n.nspname = 'job_board'
  AND c.relname = 'jobs_on_queue';

ROLLBACK;
