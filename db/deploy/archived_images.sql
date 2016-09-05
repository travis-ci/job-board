-- Deploy job-board:archived_images to pg
-- requires: appschema

BEGIN;

SET client_min_messages = 'warning';

CREATE TABLE job_board.archived_images (
  id serial PRIMARY KEY,
  original_id bigint NOT NULL,
  infra character varying(255) NOT NULL,
  name character varying(255) NOT NULL,
  created_at timestamp without time zone NOT NULL DEFAULT (now() at time zone 'UTC'),
  updated_at timestamp without time zone NOT NULL
);

COMMIT;
