-- Verify job-board:archived_images on pg

BEGIN;

SELECT id, original_id, infra, name, created_at, updated_at
FROM job_board.archived_images
WHERE false;

ROLLBACK;
