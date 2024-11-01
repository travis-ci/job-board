FROM ruby:3.2.5-slim
LABEL maintainer Travis CI GmbH <support+travis-api-docker-images@travis-ci.com>
# packages required for bundle install
RUN ( \
   apt-get update ; \
   apt-get install -y --no-install-recommends git make gcc g++ libpq-dev curl jq libjemalloc-dev \
   && rm -rf /var/lib/apt/lists/* \
)
# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

RUN mkdir -p /app
WORKDIR /app
COPY Gemfile      /app
COPY Gemfile.lock /app

RUN gem install bundler -v '2.5.11'
RUN bundler install --verbose --retry=3 --deployment --without development test

COPY . /app

CMD bin/job-board-pgbouncer-exec bin/job-board-server
