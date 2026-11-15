# typed: true
# frozen_string_literal: true

module Prusalink
  class Status
    # Telemetry about the current file transfer. All values except {#id} and {#time_transferring} are optional.
    #
    # @example
    #   transfer = Prusalink::Status.get.transfer
    #   transfer.progress         # => 65.82
    #   transfer.data_transferred # => 123084800
    class Transfer
      extend T::Sig
      include AutoInitializable
      include Deserializable

      # @!attribute [r] id
      #   @return [Integer] The transfer's id
      auto_attr :id, type: Integer

      # @!attribute [r] time_transferring
      #   @return [Integer] Time spent transferring, in seconds
      auto_attr :time_transferring, type: Integer

      # @!attribute [r] progress
      #   @return [Float] Transfer progress, in percent
      auto_attr :progress, type: Float

      # @!attribute [r] data_transferred
      #   @return [Integer] Amount of data transferred, in bytes
      auto_attr :data_transferred, type: Integer

      # @!attribute [r] extra
      #   @return [Hash] Any additional fields returned by the API
      auto_attr :extra, type: Hash

      auto_initialize!
    end
  end
end
