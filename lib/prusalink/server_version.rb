# typed: true
# frozen_string_literal: true

module Prusalink
  # Version information about the PrusaLink server and the printer's firmware.
  #
  # @example
  #   version = Prusalink::ServerVersion.get
  #   version.text     # => "PrusaLink 0.7.0"
  #   version.firmware # => "6.1.3+8098"
  #   version.upload_by_put? # => true
  class ServerVersion < BaseResource
    include AutoInitializable
    include Deserializable

    resource_path("/api/version")

    # @!attribute [r] api
    #   @return [String] The API version
    auto_attr :api, type: String

    # @!attribute [r] version
    #   @return [String] The PrusaLink version
    auto_attr :version, type: String

    # @!attribute [r] printer
    #   @return [String] The printer's version
    auto_attr :printer, type: String

    # @!attribute [r] text
    #   @return [String] Server version including the "PrusaLink" prefix
    auto_attr :text, type: String

    # @!attribute [r] firmware
    #   @return [String] The printer's firmware version
    auto_attr :firmware, type: String

    # @!attribute [r] sdk
    #   @return [String] The PrusaLink SDK version
    auto_attr :sdk, type: String

    # @!attribute [r] capabilities
    #   @return [Hash] Optional capabilities, e.g. { upload_by_put: true }
    auto_attr :capabilities, type: Hash

    # The next three fields are sent by MK4, XL and MINI firmware, but aren't in the OpenAPI spec.

    # @!attribute [r] server
    #   @return [String] The PrusaLink server version, e.g. "2.1.2"
    auto_attr :server, type: String

    # @!attribute [r] nozzle_diameter
    #   @return [Float] The nozzle's diameter, in millimeters
    auto_attr :nozzle_diameter, type: Float

    # @!attribute [r] hostname
    #   @return [String] The printer's hostname on the network, e.g. "prusa-xl"
    auto_attr :hostname, type: String

    # @!attribute [r] extra
    #   @return [Hash] Any additional fields returned by the API
    auto_attr :extra, type: Hash

    auto_initialize!

    # Retrieve information regarding server and API version.
    #
    # @return [ServerVersion]
    # @raise [Prusalink::Exceptions::Error] if the request fails
    #: -> ServerVersion
    def self.get
      fetch_resource
    end

    # Whether the printer accepts uploads with PUT /api/v1/files (see {Files.upload})
    #
    # @return [Boolean]
    #: -> bool
    def upload_by_put?
      capabilities&.fetch(:upload_by_put, false) == true
    end
  end
end
