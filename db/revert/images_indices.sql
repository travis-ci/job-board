-- Revert job-board:images_indices from pg

BEGIN;

DROP INDEX job_board.images_on_tags;

DROP INDEX job_board.images_on_name;

DROP INDEX job_board.images_on_infra;

COMMIT;
