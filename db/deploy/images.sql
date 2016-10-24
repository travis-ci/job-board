-- Deploy job-board:images to pg
-- requires: appschema

BEGIN;

CREATE EXTENSION IF NOT EXISTS hstore;

CREATE TABLE job_board.images (
  id serial PRIMARY KEY,
  infra character varying(255) NOT NULL,
  name character varying(255) NOT NULL,
  tags hstore NOT NULL DEFAULT ''::hstore,
  is_default boolean NOT NULL DEFAULT false,
  created_at timestamp without time zone NOT NULL DEFAULT (now() at time zone 'UTC'),
  updated_at timestamp without time zone
);

CREATE UNIQUE INDEX images_is_default_infra ON job_board.images(infra, is_default) WHERE is_default IS true;

COMMIT;
