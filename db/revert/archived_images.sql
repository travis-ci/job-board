-- Revert job-board:archived_images from pg

BEGIN;

DROP TABLE job_board.archived_images;

COMMIT;
