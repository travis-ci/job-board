FROM ruby:2.5-alpine
LABEL maintainer Travis CI GmbH <support+travis-app-docker-images@travis-ci.com>
WORKDIR /usr/src/app

RUN apk add --no-cache ca-certificates bash curl git postgresql-dev
RUN apk add --no-cache --virtual builddep build-base gcc abuild binutils
COPY Gemfile Gemfile.lock ./
RUN bundle config --global frozen 1
RUN bundle install
RUN apk del builddep
COPY . .

CMD ["bin/job-board-server"]
