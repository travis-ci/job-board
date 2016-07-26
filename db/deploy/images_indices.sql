-- Deploy job-board:images_indices to pg
-- requires: appschema
-- requires: images

BEGIN;

CREATE INDEX images_on_infra ON job_board.images(infra);

CREATE INDEX images_on_name ON job_board.images(name);

CREATE INDEX images_on_tags ON job_board.images USING GIST (tags);

COMMIT;
