BEGIN;

CREATE EXTENSION IF NOT EXISTS hstore;

CREATE SCHEMA imgref;

CREATE TABLE imgref.images (
  id serial PRIMARY KEY,
  infra character varying(255) NOT NULL,
  name character varying(255) NOT NULL,
  tags hstore NOT NULL DEFAULT ''::hstore,
  is_default boolean NOT NULL DEFAULT false,
  created_at timestamp without time zone NOT NULL DEFAULT (now() at time zone 'UTC'),
  updated_at timestamp without time zone
);

CREATE UNIQUE INDEX images_is_default_infra ON imgref.images(infra, is_default) WHERE is_default IS true;

CREATE INDEX images_on_infra ON imgref.images(infra);

CREATE INDEX images_on_name ON imgref.images(name);

CREATE INDEX images_on_tags ON imgref.images USING GIST (tags);

CREATE TABLE imgref.overrides (
  id serial PRIMARY KEY,
  image_id bigint NOT NULL,
  slug character varying(255),
  owner character varying(255),
  os character varying(255),
  language character varying(255),
  dist character varying(255),
  osx_image character varying(255),
  services text[][],
  importance integer NOT NULL DEFAULT 0,
  created_at timestamp without time zone NOT NULL DEFAULT (now() at time zone 'UTC'),
  updated_at timestamp without time zone
);

CREATE INDEX overrides_on_image_id ON imgref.overrides(image_id);

CREATE INDEX overrides_on_slug ON imgref.overrides(slug);

CREATE INDEX overrides_on_owner ON imgref.overrides(owner);

CREATE INDEX overrides_on_os ON imgref.overrides(os);

CREATE INDEX overrides_on_language ON imgref.overrides(language);

CREATE INDEX overrides_on_dist ON imgref.overrides(dist);

CREATE INDEX overrides_on_osx_image ON imgref.overrides(osx_image);

CREATE INDEX overrides_on_services ON imgref.overrides USING GIN (services);

COMMIT;
