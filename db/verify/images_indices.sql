-- Verify job-board:images_indices on pg

BEGIN;

SELECT 1/COUNT(*)
FROM pg_catalog.pg_class c
  LEFT JOIN pg_catalog.pg_namespace n
  ON n.oid = c.relnamespace
WHERE c.relkind = 'i'
  AND n.nspname = 'job_board'
  AND c.relname = 'images_on_infra';

SELECT 1/COUNT(*)
FROM pg_catalog.pg_class c
  LEFT JOIN pg_catalog.pg_namespace n
  ON n.oid = c.relnamespace
WHERE c.relkind = 'i'
  AND n.nspname = 'job_board'
  AND c.relname = 'images_on_name';

SELECT 1/COUNT(*)
FROM pg_catalog.pg_class c
  LEFT JOIN pg_catalog.pg_namespace n
  ON n.oid = c.relnamespace
WHERE c.relkind = 'i'
  AND n.nspname = 'job_board'
  AND c.relname = 'images_on_tags';

ROLLBACK;
