-- Deploy job-board:images_active to pg
-- requires: appschema
-- requires: images

BEGIN;

ALTER TABLE job_board.images
ADD COLUMN is_active boolean DEFAULT 'f' NULL;

-- Default all existing images to active
UPDATE job_board.images
SET is_active = 't';

ALTER TABLE job_board.images
ALTER COLUMN is_active SET NOT NULL;

COMMIT;
