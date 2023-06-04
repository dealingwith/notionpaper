# Dockerfile

FROM ruby:3.1.4

WORKDIR ./
COPY . ./
RUN bundle install

EXPOSE 4567

CMD ["bundle", "exec", "rackup", "--host", "0.0.0.0", "-p", "4567"]
