FROM jekyll/jekyll:3.8
COPY . /srv/jekyll
EXPOSE 4000
RUN jekyll build
CMD ["jekyll","serve","--watch","--drafts"]