# `job-board`

[![Build Status](https://travis-ci.org/travis-ci/job-board.svg?branch=master&cachebust=1)](https://travis-ci.org/travis-ci/job-board)
[![Code Climate](https://codeclimate.com/github/travis-ci/job-board/badges/gpa.svg?cachebust=1)](https://codeclimate.com/github/travis-ci/job-board)
[![Test Coverage](https://codeclimate.com/github/travis-ci/job-board/badges/coverage.svg?cachebust=1)](https://codeclimate.com/github/travis-ci/job-board/coverage)

Job placement for everyone!

**job-board** Is intended to be responsible for job delivery to
[worker](https://github.com/travis-ci/worker) over HTTP as a replacement for
RabbitMQ/AMQP.  A separate image-specific API is also provided, which has been
historically used as a test bed for per-job HTTP querying across various worker
infrastructures.

For a detailed explanation of the APIs provided by **job-board**, and the
behaviors expected from consumers, please consult see the [API section](#API)
below.

## Status

Actively running in production, albeit with mixed levels of API adoption across
infrastructures.

## How does it fit into the rest of the system

* **Deployment**: Heroku
* **scheduler** ([github](https://github.com/travis-ci/travis-scheduler)):
  scheduler sends job payloads to job-board over HTTP.
* **worker** ([github](https://github.com/travis-ci/worker)): worker repeatedly
  sends "heartbeat" requests to job-board via HTTP for job delivery and job
claim renewal.  Once worker internally begins processing a job, an additional
HTTP request fetches the full job payload from job-board.  Some of the backend
providers in worker may be configured to select images via HTTP queries to
job-board, although this API is slated for eventual removal as the job delivery
API provides the same data in the job payload.
* **gcloud-cleanup** ([github](https://github.com/travis-ci/gcloud-cleanup)):
  gcloud-cleanup queries job-board over HTTP, and deletes old images from it

## API

### Job Delivery API

#### Unique source identifier (`${UNIQUE_ID}`)

The `${UNIQUE_ID}` string used in the `From:` header is intended to be a unique
identifier.  As the value of `${UNIQUE_ID}` must be in the form of
`${SOMETHING}@${SOMETHING}` (like an email address) in order to be a valid `From:`
header.  In the case of Worker communicating with Job Board, the scope of
uniqueness we need is limited to "one Worker", which is used on the Job Board
side as a way to track job IDs claimed by Workers.  In implementation terms,
each Worker has a redis set that includes the job IDs Job Board expects it is
actively processing.

```
worker+${SHA}@${PID}.${HOSTNAME}
```

#### Delivery workflow

A given Worker's [Processor
Pool](https://github.com/travis-ci/worker/blob/9aed935dc3e67df7d4793560d08fc5947982e249/processor_pool.go)
will have an HTTP Job Queue that is responsible for repeatedly placing `POST
/jobs` requests  to Job Board for purposes of transferring state information
about the actively executing jobs and claiming any jobs that are available for
delivery.

Any job IDs that are successfully claimed are consumed by one of the
ProcessorPool's processors, at which point the skeletal Job is "hydrated" via a
`GET /jobs/:job_id` request and job processing continues.

If any subsequent response from `POST /jobs` states that an active job has
become unavailable, then the Processor Pool will cancel any matching job(s).
In practice, such a collision *should be rare*, and explicit job cancellations
should only come *from* the Job State API.

#### `POST /jobs{?count,queue}`

This resource is intended to act as a "heartbeat" where a given Worker's
Processor Pool sends a list of job IDs it is actively executing and expects to
receive back a list of job IDs that are confirmed to be claimed by the
requesting Worker or are available for claim as `"jobs"`.

As shown below, the `count` query param is optional, but the `queue` query
param is required.

##### Requests

If the Worker's Processor Pool with capacity 20 is "empty", such as when the
process first initializes:

```
POST /jobs?count=20&queue=flah
Content-Type: application/json
Travis-Site: ${SITE}
Authorization: basic ${BASE64_BASIC_AUTH}
From: ${UNIQUE_ID}

{
  "jobs": []
}
```

If the Worker's Processor Pool with capacity 20 has 17 available processors and
is working on 3 jobs:

```
POST /jobs?count=17&queue=flah
Content-Type: application/json
Travis-Site: ${SITE}
Authorization: basic ${BASE64_BASIC_AUTH}
From: ${UNIQUE_ID}

{
  "jobs": [
    "${JOB_ID}",
    "${JOB_ID}",
    "${JOB_ID}"
  ]
}
```

##### Responses

If all of the job IDs reported by Worker are available for claim:

```
HTTP/1.1 200 OK
Content-Type: application/json

{
  "jobs": [
    "${JOB_ID}",
    "${JOB_ID}",
    "${JOB_ID}",
    // … however many job IDs there were in the request
  ],
  "@count": ${COUNT},
  "@queue": "${QUEUE}"
}
```

If the queue param is omitted or empty:

```
HTTP/1.1 400 Bad Request
Content-Type: application/json

{
  "@type": "error",
  "error": "missing queue param"
}
```

If some of the job IDs are unavailable for claim:

```
HTTP/1.1 409 Conflict
Content-Type: application/json

{
  "jobs": [
    "${JOB_ID}",
    "${JOB_ID}",
    // … excluding the jobs unavailable for claim
  ],
  "@count": ${COUNT},
  "@queue": "${QUEUE}"
}
```

If the `Authorization` header is missing, `401`.

If the `Authorization` header is invalid, `403`.

#### `POST /jobs/add`

This resource is intended to be used by
[scheduler](https://github.com/travis-ci/travis-scheduler) to add to the pool
of jobs available for delivery.  It is the rough equivalent of Scheduler
"enqueueing" a job to RabbitMQ.  The reason why this isn't a `PUT` is because
the Scheduler representation of a job has significantly less information in it
than the representation returned by `GET /jobs/:job_id`.

##### Request

```
Authorization: basic ${BASE64_BASIC_AUTH}
Travis-Site: ${SITE}
Content-Type: application/json

{
  "@type": "job",
  "id": "${JOB_ID}"
  "config": {
    // … other job representation bits
  }
}
```

##### Responses

If request is valid and the job does not already exist:

```
HTTP/1.1 201 Created
Content-Length: 0
```

If the request is valid but the job already exists, the request acts as an
update, and will alter all persistested fields except for the job id:

```
HTTP/1.1 204 No Content
```

If the request is invalid:

```
HTTP/1.1 400 Bad Request
Content-Type: application/json

{
  "@type": "error",
  "error": "${ERROR_MESSAGE}"
}
```

If the `Travis-Site` header is missing, `412`.

If the `Authorization` header is missing, `401`.

If the `Authorization` header is invalid, `403`.

#### `GET /jobs/{job_id}`

This resource is intended to be used by a given Worker Processor after the
above "heartbeat" request has succeeded as a way to retrieve the ful job
representation as needed by Worker, which includes the job script and URI
templates used for communicating with the Job State and Log Parts APIs.

##### Request

```
Travis-Site: ${SITE}
Travis-Infrastructure: ${INFRASTRUCTURE}
Authorization: basic ${BASE64_BASIC_AUTH}
From: ${UNIQUE_ID}
```

##### Responses

If the request and auth are valid:

```
HTTP/1.1 200 OK
Content-Type: application/json

{
  "@type": "job",
  "id": "${JOB_ID}",
  "data": {
    "queue": "${QUEUE}",
    "config": {
      "os": "linux",
      "dist": "trusty",
      // ... other config bits
    },
  },
  // … other job representation bits
  "job_script": {
    "name": "main",
    "encoding": "base64",
    "content": "MjBiZGQzOTk0Mjc...(base64-encoded build.sh)"
  },
  "job_state_url": "${JOB_STATE_URL}",
  "log_parts_url": "${LOG_PARTS_URL}",
  "jwt": "${JOB_SPECIFIC_JWT}",
  "image_name": "${IMAGE_NAME}"
}
```

If the `Travis-Site` header is missing, `412`.

If the `Authorization` header is missing, `401`.

If the `Authorization` header is invalid, `403`.

#### `DELETE /jobs/{job_id}`

This resource is intended to be used by Worker as a way to mark the job as
"completed" with Job Board.  This is the rough equivalent of what Worker does
when communicating via AMQP by sending an "ACK" for the job message.  The
Authorization should use the `JWT` that was issued by Job Board specifically
for this job.

##### Request

```
Travis-Site: ${SITE}
Authorization: Bearer ${JWT}
From: ${UNIQUE_ID}
```

##### Responses

If the request and auth are valid:

```
HTTP/1.1 204 No Content
```

If the `Travis-Site` header is missing, `412`.

If the `Authorization` header is missing, `401`.

If the `Authorization` header is invalid, `403`.

### Image API

One of the things that's queryable in job-board is image names on various
infrastructures.

#### `POST /images{?infra,tags,name,is_default}`

Creates an image record.

##### Request

```
POST /images?infra=gce&tags=org:true&name=floo-flah-trusty-1438203722&limit=1
Authorization: basic ${BASE64_BASIC_AUTH}
```

##### Responses

If the request and auth are valid:

```
HTTP/1.1 201 Created
Content-Type: application/json

{
  "data": [
    {
      "id": "${IMAGE_ID}"
      // ... other stuff
    }
  ],
}
```

If the request is invalid, `400`.

If the `Authorization` header is missing, `401`.

If the `Authorization` header is invalid, `403`.


#### `PUT /images{?infra,tags,name,is_default}`

Updates an image record.

##### Request

```
PUT /images?infra=gce&tags=production:true,org:true&name=floo-flah-trusty-1438203722
Authorization: basic ${BASE64_BASIC_AUTH}
```

##### Responses

If the request and auth are valid:

```
HTTP/1.1 200 OK
Content-Type: application/json

{
  "data": [
    {
      "id": "${IMAGE_ID}"
      // ... other stuff
    }
  ],
}
```

If the request is invalid, `400`.

If the `Authorization` header is missing, `401`.

If the `Authorization` header is invalid, `403`.

#### `GET /images{?infra,tags,name,is_default,limit}`

Query for an image record.

##### Request

```
GET /images?infra=gce&tags=production:true,org:true
Authorization: basic ${BASE64_BASIC_AUTH}
```

##### Responses

If the request and auth are valid:

```
HTTP/1.1 200 OK
Content-Type: application/json

{
  "data": [
    {
      "id": "${IMAGE_ID}"
      // ... other stuff
    }
  ],
}
```

If the request is invalid, `400`.

If the `Authorization` header is missing, `401`.

If the `Authorization` header is invalid, `403`.

#### `POST /images/search`

Perform the equivalent of multiple `GET
/images{?infra,tags,name,is_default,limit}` requests within one request via
newline-delimited `application/x-www-form-urlencoded` queries.

##### Request

```
Content-Type: application/x-www-form-urlencoded; boundary=NL
Authorization: basic ${BASE64_BASIC_AUTH}

infra=gce&tags=os:linux,group:stable,language_ruby:true&is_default=false&fields[images]=name&limit=1
infra=gce&tags=group:stable,language_ruby:true&is_default=false&fields[images]=name&limit=1
infra=gce&tags=language_ruby:true&is_default=false&fields[images]=name&limit=1
infra=gce&tags=os:linux&is_default=true&fields[images]=name&limit=1
```

##### Responses

If the request and auth are valid, noting that the above example includes
`fields[images]=name`, which has the potential to reduce the response body size
substantially.

```
HTTP/1.1 200 OK
Content-Type: application/json

{
  "data": [
    {
      "name": "floo-flah-trusty-1438203722"
    }
  ]
  "meta": {
    "limit": 1,
    "matching_query": {
      "infra": "gce",
      "tags": {
        "group": "stable",
        "language_ruby": "true",
      },
      "is_default": false,
      "limit": 1
    }
  }
}
```

If the request is invalid, `400`.

If the `Authorization` header is missing, `401`.

If the `Authorization` header is invalid, `403`.
