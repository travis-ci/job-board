-- Deploy job-board:archived_images to pg
-- requires: appschema

BEGIN;

SET client_min_messages = 'warning';

CREATE EXTENSION IF NOT EXISTS hstore;

CREATE TABLE job_board.archived_images (
  id serial PRIMARY KEY,
  original_id bigint NOT NULL,
  infra character varying(255) NOT NULL,
  name character varying(255) NOT NULL,
  tags hstore NOT NULL DEFAULT ''::hstore,
  is_default boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT false,
  created_at timestamp without time zone NOT NULL DEFAULT (now() at time zone 'UTC'),
  updated_at timestamp without time zone
);

COMMIT;
