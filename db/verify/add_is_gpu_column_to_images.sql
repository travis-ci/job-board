-- Verify job-board:add_is_gpu_column_to_images on pg

BEGIN;

SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'images' AND column_name = 'is_gpu'
) AS column_exists;

ROLLBACK;
