# `job-board`

[![Build Status](https://travis-ci.org/travis-ci/job-board.svg?branch=master)](https://travis-ci.org/travis-ci/job-board)
[![Code Climate](https://codeclimate.com/github/travis-ci/job-board/badges/gpa.svg)](https://codeclimate.com/github/travis-ci/job-board)
[![Test Coverage](https://codeclimate.com/github/travis-ci/job-board/badges/coverage.svg)](https://codeclimate.com/github/travis-ci/job-board/coverage)

Job placement for everyone!

## Image API

One of the things that's queryable in job-board is image names on various
infrastructures, as not all platforms provide a native means to tag and select
images based on arbitrary criteria.

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
