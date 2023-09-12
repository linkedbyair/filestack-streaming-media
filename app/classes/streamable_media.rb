class StreamableMedia
  # Hitting an endpoint will trigger Filestack to convert the video to HLS.
  # The endpoint specifies how the media should be converted. In this case,
  # we're converting to HLS with a variant playlist, which means that the
  # video will be converted to HLS and a playlist will be generated that
  # contains links to the different quality versions of the video.
  def self.conversion_endpoint(url)
    handle = url&.match(%r{https?://www.filepicker.io/api/file/(\w+)}) { |m| m[1] }

    throw StandardError.new("Could not find filestack handle in #{url}") if handle.nil?

    "https://cdn.filestackcontent.com/#{ENV['FILESTACK_API_KEY']}/video_convert=preset:hls.variant.playlist/#{handle}"
  end

  def self.request_conversion(url)
    uri = URI(
      StreamableMedia.conversion_endpoint(url)
    )
    req = Net::HTTP::Get.new(uri)
    req["Content-Type"] = "application/json"
    req["Accept"] = "application/json"
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(req)
    end

    JSON.parse(response.body)
  rescue => e
    throw StandardError.new("Encountered error while converting #{url} to HLS: #{e.message}")
  end

  def self.cdn_stream_url(stream_url)
    handle=stream_url.split("/").last
    "https://cdn.filestackcontent.com/video_playlist/#{handle}"
  end
end
