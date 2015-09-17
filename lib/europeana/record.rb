require "europeana"
require "uri"

module Europeana
  ##
  # Interface to the Europeana API Record method
  #
  # @see http://labs.europeana.eu/api/record/
  #
  class Record
    # Europeana ID of the record
    attr_accessor :id
    
    # Request parameters to send to the API
    attr_accessor :params
    
    ##
    # @param [String] id Europeana ID of the record
    # @param [Hash] params Request parameters
    #
    def initialize(id, params = {})
      self.id = id
      self.params = params
    end
    
    ##
    # Returns query params with API key added
    #
    # @return [Hash]
    #
    def params_with_authentication
      raise Europeana::Errors::MissingAPIKeyError unless Europeana.api_key.present?
      params.merge(:wskey => Europeana.api_key)
    end
    
    ##
    # Sets record ID attribute after validating format.
    #
    # @param [String] id Record ID
    #
    def id=(id)
      raise ArgumentError, "Invalid Europeana record ID." unless id.is_a?(String) && id.match(/\A\/[^\/]+\/[^\/]+\B/)
      @id = id
    end
    
    ##
    # Sets request parameters after validating keys
    #
    # Valid parameter keys:
    # * :callback
    #
    # For explanations of these request parameters, see: http://labs.europeana.eu/api/record/
    #
    # @param (see #initialize)
    # @return [Hash] Request parameters
    #
    def params=(params = {})
      params.assert_valid_keys(:callback)
      @params = params
    end
    
    ##
    # Gets the URI for this Record request with parameters
    #
    # @return [URI]
    #
    def request_uri
      uri = URI.parse(Europeana::URL + "/record" + "#{@id}.json")
      uri.query = params_with_authentication.to_query
      uri
    end
    
    ##
    # Sends a request for this record to the API
    #
    # @return [Hash] Record data
    #
    def get
      uri = request_uri
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Get.new(uri.request_uri)
      retries = Europeana.max_retries
      
      begin
        response = http.request(request)
      rescue Timeout::Error, Errno::ECONNREFUSED, EOFError
        retries -= 1
        raise unless retries > 0
        sleep Europeana.retry_delay
        retry
      end
      
      json = JSON.parse(response.body)
      raise Errors::RequestError, json['error'] unless json['success']
      json
    rescue JSON::ParserError
      if response.code.to_i == 404
        # Handle HTML 404 responses on malformed record ID, emulating API's
        # JSON response.
        raise Errors::RequestError, "Invalid record identifier: #{@id}"
      else
        raise Errors::ResponseError
      end
    end
  end
end
