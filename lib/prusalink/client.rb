# typed: true
# frozen_string_literal: true

require "faraday"

module Prusalink
  # The API client object.
  #
  # @example Digest authentication (current firmware)
  #   client = Prusalink::Client.new(host: "http://prusa-mk4.local", password: "s3cr3t")
  #
  # @example API key (older firmware)
  #   client = Prusalink::Client.new(host: "http://prusa-mini.local", api_key: "abcdef")
  #
  # @example Allow more time for large file uploads
  #   client = Prusalink::Client.new(host: "http://prusa-mk4.local", password: "s3cr3t", timeout: 300)
  #
  # @attr [String] host
  # @attr [String] username
  # @attr [String, nil] password
  # @attr [String, nil] api_key
  # @attr [Numeric, nil] open_timeout  Seconds to wait for the connection to open
  # @attr [Numeric, nil] timeout       Seconds to wait for a read or a write
  class Client
    extend T::Sig

    # PrusaLink's default username for Digest authentication
    DEFAULT_USERNAME = "maker"
    # Default number of seconds to wait for the connection to open
    DEFAULT_OPEN_TIMEOUT = 3
    # Default number of seconds to wait for a read or a write. Printers on Wi-Fi can be slow.
    DEFAULT_TIMEOUT = 10

    ERRORS = T.let({
      400 => Exceptions::BadRequestError,
      401 => Exceptions::AuthenticationError,
      403 => Exceptions::AuthenticationError,
      404 => Exceptions::NotFoundError,
      409 => Exceptions::ConflictError,
      415 => Exceptions::UnsupportedMediaTypeError,
      500 => Exceptions::InternalServerError,
      501 => Exceptions::NotImplementedError,
      503 => Exceptions::ServiceUnavailableError
    }.freeze, T::Hash[Integer, T.class_of(Exceptions::Error)])

    attr_reader :host, :username, :password, :api_key, :open_timeout, :timeout

    # @param host [String, URI]            Printer's address
    # @param password [String, nil]        PrusaLink password (Digest auth)
    # @param username [String]             PrusaLink username (Digest auth)
    # @param api_key [String, nil]         PrusaLink API key (older firmware)
    # @param open_timeout [Numeric, nil]   Seconds to wait for the connection to open
    # @param timeout [Numeric, nil]        Seconds to wait for a read or a write
    # @raise [Exceptions::MissingCredentialsError] if host is missing, or both password and api_key are missing
    sig do
      params(
        host: T.nilable(T.any(String, URI::Generic)),
        password: T.nilable(String),
        username: String,
        api_key: T.nilable(String),
        open_timeout: T.nilable(Numeric),
        timeout: T.nilable(Numeric)
      ).void
    end
    def initialize(host:, password: nil, username: DEFAULT_USERNAME, api_key: nil,
                   open_timeout: DEFAULT_OPEN_TIMEOUT, timeout: DEFAULT_TIMEOUT)
      raise Exceptions::MissingCredentialsError if host.nil? || (password.nil? && api_key.nil?)

      @host         = host
      @username     = username
      @password     = password
      @api_key      = api_key
      @open_timeout = open_timeout
      @timeout      = timeout
      @connection   = new_connection
    end

    # Sends a request to the printer and parses the JSON response.
    #
    # @param path [String]                 the path of the request
    # @param http_method [Symbol]          :get, :post, :put, :patch, :delete or :head
    # @param body [Hash, String, IO, nil]  a Hash is sent as JSON. A String or an IO is sent as-is
    # @param headers [Hash]                extra request headers
    # @return [Hash, Array, true, nil]     the parsed body. true when the printer answers without a body.
    #                                      nil when it answers 204 No Content to a GET
    # @raise [Exceptions::Error] a subclass matching the HTTP status when the request fails
    # @raise [Exceptions::TimeoutError] if the printer doesn't respond within the configured timeouts
    # @raise [Exceptions::ConnectionError] if the printer can't be reached
    # @raise [Exceptions::InvalidResponseError] if the printer answers with invalid JSON
    sig do
      params(
        path: String,
        http_method: Symbol,
        body: T.untyped,
        headers: T::Hash[T.any(String, Symbol), String]
      ).returns(T.untyped)
    end
    def request(path, http_method: :get, body: nil, headers: {})
      response = perform(http_method, path, body, headers)

      process_error(response) if response.status >= 400
      return nil if response.status == 204 && http_method == :get
      return true if response.body.to_s.strip.empty?

      parse_json(response.body)
    end

    # Sends a HEAD request and returns the response headers.
    #
    # @param path [String] the path of the request
    # @return [Hash{String => String}] the response headers, with lowercase names
    # @raise [Exceptions::Error] a subclass matching the HTTP status when the request fails
    sig { params(path: String).returns(T::Hash[String, String]) }
    def head(path)
      response = perform(:head, path, nil, {})
      process_error(response) if response.status >= 400

      response.headers.to_h.transform_keys(&:downcase)
    end

    # Every request inside the block is sent with this client, without affecting the
    # client configured for the thread.
    #
    # @example
    #   mk4.use { Prusalink::Status.get }
    sig { params(block: T.proc.returns(T.untyped)).returns(T.untyped) }
    def use(&block)
      previous_client = Prusalink.client
      Prusalink.client = self
      block.call
    ensure
      Prusalink.client = previous_client
    end

    private

    def perform(http_method, path, body, headers)
      payload = body.is_a?(Hash) ? body.to_json : body
      headers = headers.merge("Content-Type" => "application/json") if body.is_a?(Hash)

      @connection.run_request(http_method, path, payload, headers)
    rescue Faraday::TimeoutError => e
      raise Exceptions::TimeoutError, e.message
    rescue Faraday::ConnectionFailed, Faraday::SSLError => e
      # Faraday reports open timeouts (Net::OpenTimeout) as connection failures
      error_class = e.wrapped_exception.is_a?(Timeout::Error) ? Exceptions::TimeoutError : Exceptions::ConnectionError
      raise error_class, e.message
    end

    def process_error(response)
      error_class = ERRORS[response.status] || Exceptions::UnknownError

      raise error_class, "[#{response.status}] #{error_message(response)}"
    end

    # PrusaLink answers errors with JSON ({ title:, text: }) when asked for JSON, plain text otherwise
    def error_message(response)
      parsed = parse_json(response.body)
      return response.body.to_s unless parsed.is_a?(Hash)

      [parsed[:title], parsed[:text]].compact.join(": ").presence || response.body.to_s
    rescue Exceptions::InvalidResponseError
      response.body.to_s
    end

    def parse_json(body)
      transform_keys(JSON.parse(body))
    rescue JSON::ParserError => e
      # Seen on XL firmware: the job's JSON ends with a trailing comma when its file was deleted
      raise Exceptions::InvalidResponseError, "The printer answered with invalid JSON (#{e.message}): #{body}"
    end

    def transform_keys(obj)
      case obj
      when Hash
        obj.to_h { |key, value| [key.to_s.underscore.to_sym, transform_keys(value)] }
      when Array
        obj.map { |item| transform_keys(item) }
      else
        obj
      end
    end

    def new_connection
      Faraday.new(host) do |connection|
        connection.use DigestAuth, username, password if password
        connection.headers["X-Api-Key"] = api_key if api_key && password.nil?
        connection.headers["Accept"] = "application/json"
        connection.options.open_timeout = open_timeout
        connection.options.timeout = timeout
      end
    end
  end
end
