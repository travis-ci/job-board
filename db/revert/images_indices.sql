-- Revert job-board:images_indices from pg

BEGIN;

DROP INDEX images_on_tags;

DROP INDEX images_on_name;

DROP INDEX images_on_infra;

COMMIT;
