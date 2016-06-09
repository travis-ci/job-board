# `job-board`

[![Build Status](https://travis-ci.org/travis-ci/job-board.svg?branch=master&cachebust=1)](https://travis-ci.org/travis-ci/job-board)
[![Code Climate](https://codeclimate.com/github/travis-ci/job-board/badges/gpa.svg?cachebust=1)](https://codeclimate.com/github/travis-ci/job-board)
[![Test Coverage](https://codeclimate.com/github/travis-ci/job-board/badges/coverage.svg?cachebust=1)](https://codeclimate.com/github/travis-ci/job-board/coverage)

Job placement for everyone!

**job-board** stores metadata about images for each of our infrastructures:

* **docker** The container-based infrastructure on AWS.
* **gce** The VM based infrastructure on Google Compute Platform.
* **jupiterbrain** The OSX infrastructure on MacStadium (jupiterbrain is our API that we use to talk to it).

Some of these environments do not provide a means for tagging and querying images.

## Status

Actively running in production.

## How does it fit into the rest of the system

* **Deployment**: Heroku
* **gcloud-cleanup** ([github](https://github.com/travis-ci/gcloud-cleanup)): gcloud-cleanup queries job-board over HTTP, and deletes old images from it
* **worker** ([github](https://github.com/travis-ci/worker)): The worker's image `api_selector` queries job-board via HTTP and matches against a particular combination of: `Language`, `OsxImage`, `Dist`, `Group`, `OS` which are provided as part of the `startAttributes` field of the amqp job.

Worker uses job-board to pick which image to launch a build instance from.

## Image API

One of the things that's queryable in job-board is image names on various
infrastructures.

Creating an image reference:

``` bash
curl -s -X POST https://example.com/images\?infra\=gce\&tags\=org:true\&name=floo-flah-trusty-1438203722
```

Updating the image's tags:

``` bash
curl -s -X PUT https://example.com/images\?infra\=gce\&tags\=production:true,org:true\&name=floo-flah-trusty-1438203722
```

Querying for an image via `infra` and `tags`:

``` bash
curl -s https://example.com/images\?infra\=gce\&tags\=production:true,org:true | \
  jq -r '.data | .[0] | .name'
# => floo-flah-trusty-1438203722
```
