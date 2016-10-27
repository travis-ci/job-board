-- Deploy job-board:jobs to pg
-- requires: appschema

BEGIN;

CREATE TABLE job_board.jobs (
  id serial PRIMARY KEY,
  job_id text NOT NULL,
  queue text NOT NULL,
  data json NOT NULL,
  site text NOT NULL,
  created_at timestamp without time zone NOT NULL DEFAULT (now() at time zone 'UTC'),
  updated_at timestamp without time zone,
  CONSTRAINT unique_job_id UNIQUE(job_id)
);

COMMIT;
