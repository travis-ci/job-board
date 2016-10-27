-- Deploy job-board:jobs_indices to pg
-- requires: appschema
-- requires: jobs

BEGIN;

CREATE INDEX jobs_on_queue ON job_board.jobs(queue);

COMMIT;
