-- Deploy job-board:add_is_gpu_column_to_images to pg

BEGIN;

ALTER TABLE job_board.images
ADD COLUMN is_gpu BOOLEAN NOT NULL DEFAULT FALSE;

COMMIT;
