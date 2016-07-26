-- Verify job-board:images on pg

BEGIN;

SELECT id, infra, name, tags, is_default, created_at, updated_at
FROM job_board.images
WHERE false;

SELECT 1/COUNT(*)
FROM pg_catalog.pg_class c
  LEFT JOIN pg_catalog.pg_namespace n
  ON n.oid = c.relnamespace
WHERE c.relkind = 'i'
  AND n.nspname = 'job_board'
  AND c.relname = 'images_is_default_infra';

ROLLBACK;
