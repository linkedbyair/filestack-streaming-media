# From https://github.com/infowrap/filepicker_client
require 'rest-client'
require 'json'
require 'base64'
require 'active_support/hash_with_indifferent_access'

module Filepicker

  # Client interface for Filepicker's REST API
  class Client
    FP_FILE_PATH = "https://www.filepicker.io/api/file/"    # Path that Filepicker file handles are located under
    FP_API_PATH = "https://www.filepicker.io/api/store/S3"  # Path to access the Filepicker API

    DEFAULT_POLICY_EXPIRY = 5 * 60  # 5 minutes (short for security, but allows for some wiggle room)

    attr_reader :container

    # Creates a client that will use the given Filepicker key and secret for requests and signing operations
    # @param api_key [String] Filepicker API key
    # @param api_secret [String] Filepicker API secret
    # @param filepicker_cert [OpenSSL::X509::Certificate] Optional certificate for verifying HTTPS connections to Filepicker
    def initialize(filepicker_cert=nil)
      @api_key = ENV['FILESTACK_API_KEY']
      @api_secret = ENV['FILESTACK_SECRET_KEY']
      @container = ENV['S3_BUCKET']
      @filepicker_cert = filepicker_cert
    end

    # Create policies and signatures for Filepicker operations.
    #
    # Allowed Options:
    #
    # * expiration_start - Time from which the expiry value should start
    # * expiry - Seconds until the signature should expire (defaults to DEFAULT_POLICY_EXPIRY)
    # * call - Filepicker calls to allow (String, Symbol or Array of the following: 'read', 'stat', 'convert', 'write', 'writeUrl', 'pick', 'store', 'storeUrl')
    # * handle - Handle of the specific file to grant permissions for
    # * path - Path in the storage that Filepicker uploads to that the operations should be restricted to
    # * min_size - Minimum allowed upload size
    # * max_size - Maximum allowed upload size
    #
    # @param options [Hash] Options for generating the desired signature
    # @return [Hash] The policy generated with the encoded policy and signature for use in Filepicker requests
    def sign(options={})
      options = convert_hash(options)
      options[:expiration_start] ||= Time.now
      options[:expiry] ||= DEFAULT_POLICY_EXPIRY

      policy = {
          'call' => options[:call]
      }

      # Restrict the scope of the operation to either the specified file or the path
      if options[:handle]
        policy['handle'] = options[:handle]
      elsif options[:path]
        policy['path'] = (options[:path] + '/').gsub /\/+/, '/' # ensure path has a single, trailing '/'
      end

      if options[:min_size]
        policy['minsize'] = options[:min_size].to_i
      end

      if options[:max_size]
        policy['maxsize'] = options[:max_size].to_i
      end

      # Set expiration for <expiry> seconds from expiration start
      policy['expiry'] = (options[:expiration_start] + options[:expiry]).to_i.to_s

      # Generate policy in URL safe base64 encoded JSON
      encoded_policy = Base64.urlsafe_encode64(policy.to_json)

      # Sign policy using our API secret
      signature = OpenSSL::HMAC.hexdigest('sha256', @api_secret, encoded_policy)

      return convert_hash(
          policy: convert_hash(policy),
          encoded_policy: encoded_policy,
          signature: signature
      )
    end

    # Store the given file at the given storage path through Filepicker.
    # @param path [String] Path the file should be organized under in the destination storage
    # @param file [File] File to upload
    # @return [ClientFile] Object representing the uploaded file in Filepicker
    def store(file, path=nil, params: {})
      signage = sign(path: path, call: :store)

      uri = URI.parse(FP_API_PATH)
      query_params = {
          key: @api_key,
          signature: signage[:signature],
          policy: signage[:encoded_policy],
          container: @container
      }
      query_params[:path] = signage[:policy]['path'] if path
      query_params.merge!(params) if params.present?
      uri.query = encode_uri_query(query_params)
      resource = get_fp_resource uri

      response = resource.post fileUpload: file

      if response.code == 200
        response_data = JSON.parse response.body
        file = ClientFile.new(response_data, self)

        return file
      else
        raise ClientError, "failed to store (code: #{response.code})"
      end
    end

    private

    def get_fp_resource(uri)
      resource = RestClient::Resource.new(
          uri.to_s,
          verify_ssl: (@filepicker_cert ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE),
          ssl_client_cert: @filepicker_cert
      )
    end

    def convert_hash(hash)
      HashWithIndifferentAccess.new(hash)
    end

    # Convert a hash of query params into a string.
    # This method does not encode the signature or policy params, as they are
    # already encoded in the format expected by the Filepicker API
    def encode_uri_query(params)
      encodable = {}
      unencodable = {}
      unencodable_params = ["signature", "policy"]
      params.each_pair do |key, value|
        if unencodable_params.include?(key.to_s)
          unencodable[key] = value
        else
          encodable[key] = value
        end
      end
      query = URI.encode_www_form(encodable)
      unless unencodable.empty?
        query << '&' if query.length > 0
        query << unencodable.map{|k,v| "#{k}=#{v}"}.join('&')
      end
      query
    end
  end

  # Filepicker File Container
  class ClientFile
    attr_accessor :mimetype, :size, :handle, :store_key, :filename, :client, :url

    # Create an object linked to the client to interact with the file in Filepicker
    # @param blob [Hash] Information about the file from Filepicker
    # @param client [FilepickerClient] Client through which actions on this file should be taken
    # @return [ClientFile]
    def initialize(blob, client)
      @mimetype = blob['type']
      @size = blob['size']
      @handle = URI.parse(blob['url']).path.split('/').last.strip unless blob['url'].nil?
      @store_key = blob['key']
      @filename = blob['filename']
      @url = blob['url']

      @client = client

      unless @client
        raise ClientError, "ClientFile client required"
      end
    end
  end

  # Client errors
  class ClientError < StandardError
  end
end
