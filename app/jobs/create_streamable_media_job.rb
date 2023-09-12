class CreateStreamableMediaJob < ApplicationJob
  def perform(record, source_attribute, target_attribute)
    # If this job is running, we assume the audio has changed, so we should
    # clear out the old stream value.
    record.update(target_attribute => nil)

    url = record.send(source_attribute)
    response = StreamableMedia.request_conversion(url)

    # The response will contain a status of conversion. When "completed", the response
    # will contain a data object that contains a URL to the converted video, which we should
    # persist to the database. When "pending", we should poll again later.
    case response["status"]
    when "completed"
      begin
        record.update_attribute(
          target_attribute,
          StreamableMedia.cdn_stream_url(response["data"]["url"])
        )
      rescue => e
        Rails.logger.error("Encountered error while updating #{record.class} #{record.id} with #{target_attribute}: #{e.message}")
      end
    when "pending"
      CreateStreamableMediaJob.set(wait: 1.minute).perform_later(record, source_attribute, target_attribute)
    else
      Rails.logger.error("Encountered error while converting #{url} to HLS: #{response.to_json}")
    end
  end
end
