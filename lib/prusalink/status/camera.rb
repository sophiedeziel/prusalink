# typed: true
# frozen_string_literal: true

module Prusalink
  class Status
    # The default working camera, if available.
    #
    # @example
    #   Prusalink::Status.get.camera&.id # => "Ba1kmCbifTa8X"
    class Camera
      include AutoInitializable
      include Deserializable

      # @!attribute [r] id
      #   @return [String] The camera's id
      auto_attr :id, type: String

      # @!attribute [r] extra
      #   @return [Hash] Any additional fields returned by the API
      auto_attr :extra, type: Hash

      auto_initialize!
    end
  end
end
