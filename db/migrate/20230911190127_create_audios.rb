class CreateAudios < ActiveRecord::Migration[7.0]
  def change
    create_table :audios do |t|
      t.string :title
      t.string :audio_url
      t.string :audio_url_s3
      t.string :audio_stream_url

      t.timestamps
    end
  end
end
