BEGIN;

CREATE EXTENSION IF NOT EXISTS hstore;

CREATE SCHEMA imgref;

CREATE SEQUENCE imgref.images_id_seq;

CREATE TABLE imgref.images (
  id bigint NOT NULL DEFAULT nextval('imgref.images_id_seq') UNIQUE,
  infra character varying(255) NOT NULL,
  name character varying(255) NOT NULL,
  tags hstore NOT NULL DEFAULT ''::hstore,
  created_at timestamp without time zone NOT NULL DEFAULT (now() at time zone 'UTC'),
  updated_at timestamp without time zone NULL
);

CREATE INDEX images_on_infra ON imgref.images(infra);

CREATE INDEX images_on_name ON imgref.images(name);

CREATE INDEX images_on_tags ON imgref.images USING GIST (tags);

COMMIT;
