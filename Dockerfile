FROM ruby:2.4.1

WORKDIR /src
COPY Gemfile /src/Gemfile
COPY Gemfile.lock /src/Gemfile.lock
RUN bundle install

COPY . /src
CMD ["bin/job-board-server"]

EXPOSE 5555
