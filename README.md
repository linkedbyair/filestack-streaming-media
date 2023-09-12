# Streaming audio reproduction

## About this repo

This is a pared-down reproduction of an app that uses Filestack to stream audio using HLS.js. When an mp3 is uploaded, a job automatically 

## Pre-requisites

* Ruby 3.2.2 installed. Consider using [`rbenv`](https://github.com/rbenv/rbenv) if you don't have this version already.
* [Bundler](https://bundler.io/) installed
* [Postgres](https://postgresapp.com/) installed and running

## Set up

1. `bundle install`
2. Create `config/application.yml`
3. Add Filestack credentials like so:

```
FILESTACK_API_KEY: <your api key>
FILESTACK_SECRET_KEY: <your secret key>
S3_BUCKET: <your s3 bucket>
```

4. `bin/rails db:create`
5. `bin/rails db:migrate`
6. `bin/rails s`
7. Visit http://localhost:3000
8. Upload an MP3 file
9. Wait for a few minutes for the mp3 to be converted
10. Refresh the page to stream media
