# typed: true
# frozen_string_literal: true

module Prusalink
  # Base class for all API resources.
  class BaseResource
    class << self
      extend T::Sig

      # Defines the path for the resource's endpoint
      #
      # @param [String] path      The API's endpoint path
      sig { params(path: String).void }
      def resource_path(path)
        @path = path
      end

      # Gets a single resource and instantiates the object.
      #
      # @param path [String, nil]   appended to the resource path
      # @param deserialize [Boolean] whether to build an object from the response
      # @param options [Hash]       query string parameters
      # @return [BaseResource, Hash, nil] nil when the printer answers 204 No Content
      def fetch_resource(path = nil, deserialize: true, options: {})
        path = [@path, path].compact.join("/")
        path += "?#{Faraday::Utils.build_query(options)}" if options.any?
        response = client.request(path, http_method: :get)
        return nil if response.nil?
        return deserialize(response) if deserialize

        response
      end

      # Sends a POST request to the resource's endpoint.
      sig do
        params(path: String, params: T.untyped, headers: T::Hash[T.any(String, Symbol), String]).returns(T.untyped)
      end
      def post(path: @path, params: nil, headers: {})
        client.request(path, http_method: :post, body: params, headers: headers)
      end

      # Sends a PUT request to the resource's endpoint. `params` may be a Hash (sent as JSON),
      # a String or an IO (sent as-is).
      sig do
        params(path: String, params: T.untyped, headers: T::Hash[T.any(String, Symbol), String]).returns(T.untyped)
      end
      def put(path: @path, params: nil, headers: {})
        client.request(path, http_method: :put, body: params, headers: headers)
      end

      # Sends a PATCH request to the resource's endpoint.
      sig do
        params(path: String, params: T.untyped, headers: T::Hash[T.any(String, Symbol), String]).returns(T.untyped)
      end
      def patch(path: @path, params: nil, headers: {})
        client.request(path, http_method: :patch, body: params, headers: headers)
      end

      # Sends a DELETE request to the resource's endpoint.
      sig { params(path: String, headers: T::Hash[T.any(String, Symbol), String]).returns(T.untyped) }
      def delete(path: @path, headers: {})
        client.request(path, http_method: :delete, headers: headers)
      end

      # Sends a HEAD request to the resource's endpoint and returns the response headers.
      sig { params(path: String).returns(T::Hash[String, String]) }
      def head(path: @path)
        client.head(path)
      end

      # Instantiates an object from a hash. Can be overridden by child classes
      #
      # @param [Hash] attrs      the object's attributes
      # @return [BaseResource]
      def deserialize(attrs)
        new(**attrs)
      end

      private

      sig { returns(Client) }
      def client
        client = Prusalink.client
        raise Exceptions::NotConfiguredError, "No client configured. Use Prusalink.configure" unless client

        client
      end
    end

    def initialize(**attrs); end
  end
end
