-- Verify job-board:jobs_images_updated_at_defaults on pg

BEGIN;

SELECT 1/COUNT(*)
FROM information_schema.columns
WHERE table_schema = 'job_board'
  AND table_name = 'jobs'
  AND column_name = 'updated_at'
  AND is_nullable = 'NO'
  AND column_default = E'timezone(\'UTC\'::text, now())';

SELECT 1/COUNT(*)
FROM information_schema.columns
WHERE table_schema = 'job_board'
  AND table_name = 'images'
  AND column_name = 'updated_at'
  AND is_nullable = 'NO'
  AND column_default = E'timezone(\'UTC\'::text, now())';

ROLLBACK;
