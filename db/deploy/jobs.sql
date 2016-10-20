-- Deploy job-board:jobs to pg
-- requires: appschema

BEGIN;

SET client_min_messages = 'warning';

CREATE TABLE job_board.jobs (
  id serial PRIMARY KEY,
  job_id character varying(255) NOT NULL,
  queue character varying(255) NOT NULL,
  data json NOT NULL,
  created_at timestamp without time zone NOT NULL DEFAULT (now() at time zone 'UTC'),
  updated_at timestamp without time zone,
  CONSTRAINT unique_job_id UNIQUE(job_id)
);

COMMIT;
