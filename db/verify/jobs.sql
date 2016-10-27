-- Verify job-board:jobs on pg

BEGIN;

SELECT
  id, job_id, queue, data::json, site, created_at, updated_at
FROM job_board.jobs
WHERE false;

ROLLBACK;
