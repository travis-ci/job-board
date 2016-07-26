-- Revert job-board:images from pg

BEGIN;

DROP TABLE job_board.images;

COMMIT;
