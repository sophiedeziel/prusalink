# typed: true
# frozen_string_literal: true

module Prusalink
  # The printer's current file transfer (upload or download).
  #
  # @example
  #   transfer = Prusalink::Transfer.get # => nil when nothing is transferring
  #   transfer.transfer_type # => "FROM_WEB"
  #   transfer.progress      # => 42.25
  #   transfer.stop
  class Transfer < BaseResource
    extend T::Sig
    include AutoInitializable
    include Deserializable

    resource_path("/api/v1/transfer")

    # @!attribute [r] id
    #   @return [Integer, nil] The transfer's id. Not documented in the API's Transfer schema, so it may be
    #     absent; {Status#transfer} always includes it.
    auto_attr :id, type: Integer

    # @!attribute [r] transfer_type
    #   @return [String] The transfer's source/destination: "NO_TRANSFER", "FROM_WEB", "FROM_CONNECT",
    #     "FROM_PRINTER", "FROM_SLICER", "FROM_CLIENT", "TO_CONNECT" or "TO_CLIENT".
    #     Renamed from the API's `type` field.
    auto_attr :transfer_type, type: String

    # @!attribute [r] display_name
    #   @return [String] Long filename of the transferred file
    auto_attr :display_name, type: String

    # @!attribute [r] path
    #   @return [String] Destination path, e.g. "/local"
    auto_attr :path, type: String

    # @!attribute [r] url
    #   @return [String, nil] Source URL, for downloads
    auto_attr :url, type: String

    # @!attribute [r] size
    #   @return [Integer, nil] Total size in bytes
    auto_attr :size, type: Integer

    # @!attribute [r] progress
    #   @return [Float] Completion, in percent
    auto_attr :progress, type: Float

    # @!attribute [r] transferred
    #   @return [Integer] Transferred data, in bytes
    auto_attr :transferred, type: Integer

    # @!attribute [r] time_remaining
    #   @return [Integer, nil] Estimated time left, in seconds
    auto_attr :time_remaining, type: Integer

    # @!attribute [r] time_transferring
    #   @return [Integer] Time spent transferring, in seconds
    auto_attr :time_transferring, type: Integer

    # @!attribute [r] to_print
    #   @return [Boolean] Whether the file will be printed once the transfer finishes
    auto_attr :to_print, type: T::Boolean

    # @!attribute [r] extra
    #   @return [Hash] Any additional fields returned by the API
    auto_attr :extra, type: Hash

    auto_initialize!

    deserialize_config do
      rename type: :transfer_type
    end

    # Retrieve the current transfer.
    #
    # @return [Transfer, nil] nil when nothing is transferring (the printer answers 204 No Content)
    # @raise [Prusalink::Exceptions::Error] if the request fails
    sig { returns(T.nilable(Transfer)) }
    def self.get
      fetch_resource
    end

    # Stop the transfer with the given id.
    #
    # @param id [Integer] The transfer's id
    # @return [Boolean] true on success
    # @raise [Prusalink::Exceptions::NotFoundError] if no transfer has this id
    # @raise [Prusalink::Exceptions::ConflictError] if the transfer can't be stopped
    sig { params(id: Integer).returns(T::Boolean) }
    def self.stop(id)
      delete(path: "/api/v1/transfer/#{id}")
    end

    # Stop this transfer. See {Transfer.stop}.
    #
    # @return [Boolean] true on success
    # @raise [ArgumentError] if the printer didn't report the transfer's id
    sig { returns(T::Boolean) }
    def stop
      transfer_id = id
      raise ArgumentError, "This transfer has no id. Use Transfer.stop with Status#transfer's id" if transfer_id.nil?

      self.class.stop(transfer_id)
    end
  end
end
