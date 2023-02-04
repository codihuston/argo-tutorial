FROM ruby

WORKDIR /app
COPY Gemfile Gemfile.lock ./

RUN bundle install

COPY . .
