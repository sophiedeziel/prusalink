# typed: true
# frozen_string_literal: true

module Prusalink
  # A file storage of the printer, such as the local storage, an SD card or a USB drive.
  #
  # @example
  #   storages = Prusalink::Storage.list
  #   usb = storages.find { |storage| storage.storage_type == "USB" }
  #   usb.available? # => true
  #   usb.free_space # => 1921681142
  class Storage < BaseResource
    include AutoInitializable
    include Deserializable

    resource_path("/api/v1/storage")

    # @!attribute [r] name
    #   @return [String, nil] Name of the storage, in the printer's language, e.g. "PrusaLink gcodes"
    auto_attr :name, type: String

    # @!attribute [r] storage_type
    #   @return [String] The storage's source: "LOCAL", "SDCARD" or "USB". Renamed from the API's `type` field.
    auto_attr :storage_type, type: String

    # @!attribute [r] path
    #   @return [String] Path of the storage (not the display path), e.g. "/local"
    auto_attr :path, type: String

    # @!attribute [r] print_files
    #   @return [Integer, nil] Size of all print files, in bytes
    auto_attr :print_files, type: Integer

    # @!attribute [r] system_files
    #   @return [Integer, nil] Size of all system files, in bytes
    auto_attr :system_files, type: Integer

    # @!attribute [r] free_space
    #   @return [Integer, nil] Free space, in bytes
    auto_attr :free_space, type: Integer

    # @!attribute [r] total_space
    #   @return [Integer, nil] Total space, in bytes
    auto_attr :total_space, type: Integer

    # @!attribute [r] available
    #   @return [Boolean] Whether the storage is available. See {#available?}
    auto_attr :available, type: T::Boolean

    # @!attribute [r] read_only
    #   @return [Boolean, nil] Whether the storage is read only. See {#read_only?}
    auto_attr :read_only, type: T::Boolean

    # @!attribute [r] extra
    #   @return [Hash] Any additional fields returned by the API
    auto_attr :extra, type: Hash

    auto_initialize!

    deserialize_config do
      rename type: :storage_type
    end

    # Retrieve every file storage of the printer.
    #
    # @return [Array<Storage>]
    # @raise [Prusalink::Exceptions::Error] if the request fails
    #: -> Array[Storage]
    def self.list
      response = fetch_resource(deserialize: false)
      Array(response&.fetch(:storage_list, nil)).map { |storage| deserialize(storage) }
    end

    # @return [Boolean] whether the storage is available
    #: -> bool
    def available?
      available == true
    end

    # @return [Boolean] whether the storage is read only
    #: -> bool
    def read_only?
      read_only == true
    end
  end
end
