class Audio < ApplicationRecord
  after_commit :create_streamable_media, if: :audio_url_previously_changed?

  def create_streamable_media(now: false)
    if now
      CreateStreamableMediaJob.perform_now(self, :audio_url, :audio_stream_url)
    else
      CreateStreamableMediaJob.perform_later(self, :audio_url, :audio_stream_url)
    end
  end
end
