FROM ruby:3.1
WORKDIR /srv/jekyll
COPY . .
RUN bundle install
CMD ["bundle", "exec", "jekyll", "serve", "--host=0.0.0.0"]