-- Revert job-board:jobs_images_updated_at_defaults from pg

BEGIN;

ALTER TABLE job_board.jobs
ALTER COLUMN updated_at
DROP DEFAULT;

ALTER TABLE job_board.jobs
ALTER COLUMN updated_at
DROP NOT NULL;

ALTER TABLE job_board.images
ALTER COLUMN updated_at
DROP DEFAULT;

ALTER TABLE job_board.images
ALTER COLUMN updated_at
DROP NOT NULL;

COMMIT;
