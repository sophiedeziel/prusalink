# typed: true
# frozen_string_literal: true

module Prusalink
  class Status
    # Telemetry about the current storage.
    #
    # @example
    #   storage = Prusalink::Status.get.storage
    #   storage.name       # => "LOCAL"
    #   storage.free_space # => 4202335
    class Storage
      include AutoInitializable
      include Deserializable

      # @!attribute [r] name
      #   @return [String] The storage's name, e.g. "LOCAL"
      auto_attr :name, type: String

      # @!attribute [r] path
      #   @return [String] The storage's path, e.g. "/local"
      auto_attr :path, type: String

      # @!attribute [r] read_only
      #   @return [Boolean] Whether the storage is read-only
      auto_attr :read_only, type: T::Boolean

      # @!attribute [r] free_space
      #   @return [Integer] Free space, in bytes
      auto_attr :free_space, type: Integer

      # @!attribute [r] extra
      #   @return [Hash] Any additional fields returned by the API
      auto_attr :extra, type: Hash

      auto_initialize!
    end
  end
end
