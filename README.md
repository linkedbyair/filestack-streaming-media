# Streaming audio reproduction

## About this repo

This is a pared-down reproduction of an app that uses Filestack to stream audio. When an mp3 is uploaded, it is stored in S3 through Filestack. A job is then run to convert that MP3 into streamable media, which powers an audio player written in [Stimulus.js](https://stimulus.hotwired.dev/) and supported by [HLS.js](https://github.com/video-dev/hls.js).

## Prerequisites

* Ruby 3.2.2 installed. Consider using [`rbenv`](https://github.com/rbenv/rbenv) if you don't have this version already.
* [Bundler](https://bundler.io/) installed
* [Postgres](https://postgresapp.com/) installed and running

## Set up

1. `bundle install`
2. Create `config/application.yml` to store environment variables, which will be read by [Figaro](https://github.com/laserlemon/figaro)
3. Add Filestack credentials in that file like so:

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

## Walkthrough

The `Audio` model represents any audio that has been uploaded to the site. The table has a column called `audio_url`, which stores the URL for the MP3 uploaded to Filestack. The table also has a column called `audio_stream_url` which will store the URL for an M3U8 which can be used to stream the media.

When an Audio record is saved, if the `audio_url` value has changed (as reported by [`ActiveModel::Dirty`](https://api.rubyonrails.org/classes/ActiveModel/Dirty.html)) then a job `CreateStreamableMediaJob` runs. 

The `CreateStreamableMediaJob` job works by polling [Filestack's `/video_convert` endpoint](https://www.filestack.com/docs/api/video_processing/#video-transcoding-options). The first time this endpoint is hit, it should communicate to Filestack that we want to convert a stored file using the HLS variant preset. Filestack responds to that endpoint with a JSON object detailing the status of the conversion. While the status is `'pending'`, our `CreateStreamableMediaJob` will wait 60 seconds then poll again. When the status returns `'complete'`, the job will extract the m3u8's URL and update the Audio record's `audio_stream_url` column.

The audio record is now ready for streaming. This is accomplished using a Stimulus controller/view partial. If a browser can stream HLS natively, then we will use a `<video>` tag to stream the saved `audio_stream_url`. If the browser supports the media source extension API, we will use HLS.js to provide streaming. If the browser does not support native HLS streaming nor MSE, then we offer the raw mp3 file to users to play with a progressive download in an `<audio>` element.

## Issue we encounter in production

Our Filestack app is charged for transformations every time the MP3 is streamed (which on many days occurs tens of thousands of times per day). We should only be charged when the media is uploaded (which occurs extremely rarely, since this product does not include user-generated content).
