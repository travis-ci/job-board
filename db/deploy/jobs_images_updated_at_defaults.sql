-- Deploy job-board:jobs_images_updated_at_defaults to pg
-- requires: images
-- requires: jobs

BEGIN;

ALTER TABLE job_board.jobs
ALTER COLUMN updated_at
SET DEFAULT (now() at time zone 'UTC');

ALTER TABLE job_board.jobs
ALTER COLUMN updated_at
SET NOT NULL;

ALTER TABLE job_board.images
ALTER COLUMN updated_at
SET DEFAULT (now() at time zone 'UTC');

ALTER TABLE job_board.images
ALTER COLUMN updated_at
SET NOT NULL;

COMMIT;
