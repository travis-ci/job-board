-- Revert job-board:add_is_gpu_column_to_images from pg

BEGIN;

ALTER TABLE images
DROP COLUMN IF EXISTS is_gpu;

COMMIT;
