# typed: true
# frozen_string_literal: true

module Prusalink
  # General information about the printer: its name, location, serial number and hardware setup.
  #
  # @example
  #   info = Prusalink::Info.get
  #   info.name            # => "MuadDib"
  #   info.nozzle_diameter # => 0.4
  #   info.mmu             # => false
  class Info < BaseResource
    include AutoInitializable
    include Deserializable

    resource_path("/api/v1/info")

    # @!attribute [r] mmu
    #   @return [Boolean] Whether a Multi Material Unit is attached
    auto_attr :mmu, type: T::Boolean

    # @!attribute [r] name
    #   @return [String] The printer's name, as set by the user
    auto_attr :name, type: String

    # @!attribute [r] location
    #   @return [String] The printer's location, as set by the user
    auto_attr :location, type: String

    # @!attribute [r] farm_mode
    #   @return [Boolean] Whether the printer runs in farm mode
    auto_attr :farm_mode, type: T::Boolean

    # @!attribute [r] nozzle_diameter
    #   @return [Float] The nozzle diameter, in millimeters
    auto_attr :nozzle_diameter, type: Float

    # @!attribute [r] min_extrusion_temp
    #   @return [Integer] The minimum nozzle temperature allowing extrusion, in °C
    auto_attr :min_extrusion_temp, type: Integer

    # @!attribute [r] serial
    #   @return [String] The printer's serial number
    auto_attr :serial, type: String

    # @!attribute [r] sd_ready
    #   @return [Boolean] Whether an SD card is inserted and ready
    auto_attr :sd_ready, type: T::Boolean

    # @!attribute [r] active_camera
    #   @return [Boolean] Whether a camera is active
    auto_attr :active_camera, type: T::Boolean

    # @!attribute [r] hostname
    #   @return [String] The printer's network hostname
    auto_attr :hostname, type: String

    # @!attribute [r] port
    #   @return [String] The serial port the printer is connected to, e.g. "/dev/tty"
    auto_attr :port, type: String

    # @!attribute [r] network_error_chime
    #   @return [Boolean] Whether the printer chimes on network errors
    auto_attr :network_error_chime, type: T::Boolean

    # @!attribute [r] extra
    #   @return [Hash] Any additional fields returned by the API
    auto_attr :extra, type: Hash

    auto_initialize!

    # Retrieve general information about the printer.
    #
    # @return [Info, nil] nil when the printer answers 204 No Content
    # @raise [Prusalink::Exceptions::Error] if the request fails
    #: -> Info?
    def self.get
      fetch_resource
    end
  end
end
