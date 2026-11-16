# typed: true
# frozen_string_literal: true

module Prusalink
  class Files
    # A folder, or the root of a storage, with its content.
    #
    # @example
    #   folder = Prusalink::Files.get(storage: "usb")
    #   folder.children.select(&:print_file?).map(&:display_name) # => ["benchy.gcode"]
    #   folder.children.select(&:folder?).map(&:name)             # => ["prints"]
    class Folder
      include AutoInitializable
      include Deserializable

      # @!attribute [r] name
      #   @return [String] Short folder name
      auto_attr :name, type: String

      # @!attribute [r] display_name
      #   @return [String, nil] Long folder name
      auto_attr :display_name, type: String

      # @!attribute [r] read_only
      #   @return [Boolean] Whether the folder or its storage is read-only
      auto_attr :read_only, type: T::Boolean

      # @!attribute [r] size
      #   @return [Integer, nil] Size in bytes. Usually absent for folders
      auto_attr :size, type: Integer

      # @!attribute [r] file_type
      #   @return [String] Always "FOLDER". Renamed from the API's `type`
      auto_attr :file_type, type: String

      # @!attribute [r] m_timestamp
      #   @return [Integer] Modification time, in seconds since the Unix epoch
      auto_attr :m_timestamp, type: Integer

      # @!attribute [r] children
      #   @return [Array<Files::File, Files::Folder>, nil] The folder's content. Nested folders don't include their
      #     own children
      auto_attr :children, type: T.any(Files::File, Files::Folder), array: true

      # @!attribute [r] extra
      #   @return [Hash] Any additional fields returned by the API
      auto_attr :extra, type: Hash

      auto_initialize!

      deserialize_config do
        # MK4, XL and MINI firmware send `ro` instead of the OpenAPI spec's `read_only`
        rename type: :file_type, ro: :read_only
        transform do |data|
          data[:children] = data[:children].map { |child| Files.build_entry(child) } if data[:children].is_a?(Array)
        end
      end

      # Always false
      #
      # @return [Boolean]
      #: -> bool
      def print_file?
        false
      end

      # Always false
      #
      # @return [Boolean]
      #: -> bool
      def firmware?
        false
      end

      # Always true
      #
      # @return [Boolean]
      #: -> bool
      def folder?
        true
      end
    end
  end
end
