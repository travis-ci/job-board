-- Verify job-board:images_active on pg

BEGIN;

SELECT is_active FROM job_board.images
WHERE false;

ROLLBACK;
