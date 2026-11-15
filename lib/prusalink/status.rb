# typed: true
# frozen_string_literal: true

module Prusalink
  # Telemetry about the printer, the current job, the current transfer, the storage and the camera.
  # Everything except {#printer} is optional and is nil when the printer doesn't report it.
  #
  # @example
  #   status = Prusalink::Status.get
  #   status.printer.state       # => "PRINTING"
  #   status.printer.printing?   # => true
  #   status.job&.progress       # => 42.0
  #   status.transfer            # => nil when nothing is being transferred
  class Status < BaseResource
    extend T::Sig
    include AutoInitializable
    include Deserializable

    resource_path("/api/v1/status")

    # @!attribute [r] printer
    #   @return [Status::Printer] Telemetry about the printer (always present)
    auto_attr :printer, type: Status::Printer

    # @!attribute [r] job
    #   @return [Status::Job, nil] Telemetry about the current job
    auto_attr :job, type: Status::Job

    # @!attribute [r] transfer
    #   @return [Status::Transfer, nil] Telemetry about the current file transfer
    auto_attr :transfer, type: Status::Transfer

    # @!attribute [r] storage
    #   @return [Status::Storage, nil] Telemetry about the current storage
    auto_attr :storage, type: Status::Storage

    # @!attribute [r] camera
    #   @return [Status::Camera, nil] The default working camera, if available
    auto_attr :camera, type: Status::Camera

    # @!attribute [r] extra
    #   @return [Hash] Any additional fields returned by the API
    auto_attr :extra, type: Hash

    auto_initialize!

    deserialize_config do
      nested :printer, Status::Printer
      nested :job, Status::Job
      nested :transfer, Status::Transfer
      nested :storage, Status::Storage
      nested :camera, Status::Camera
    end

    # Retrieve the printer, job, transfer, storage and camera telemetry.
    #
    # @return [Status, nil] nil when the printer answers 204 No Content
    # @raise [Prusalink::Exceptions::Error] if the request fails
    sig { returns(T.nilable(Status)) }
    def self.get
      fetch_resource
    end
  end
end
