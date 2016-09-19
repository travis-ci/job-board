-- Revert job-board:images_active from pg

BEGIN;

ALTER TABLE job_board.images
DROP COLUMN is_active;

COMMIT;
