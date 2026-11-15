# typed: true
# frozen_string_literal: true

module Prusalink
  class Files
    # A file on one of the printer's storages: a print file (G-code), a firmware file or any other file.
    #
    # @example
    #   file = Prusalink::Files.get(storage: "usb", path: "benchy.gcode")
    #   file.print_file?               # => true
    #   file.display_name              # => "benchy_0.4n_0.2mm_PLA_MK4_1h2m.gcode"
    #   file.meta[:"filament used [g]"] # => 15.42
    class File
      extend T::Sig
      include AutoInitializable
      include Deserializable

      # @!attribute [r] name
      #   @return [String] Short file name (8.3 format on USB drives)
      auto_attr :name, type: String

      # @!attribute [r] display_name
      #   @return [String, nil] Long file name
      auto_attr :display_name, type: String

      # @!attribute [r] read_only
      #   @return [Boolean] Whether the file or its storage is read-only
      auto_attr :read_only, type: T::Boolean

      # @!attribute [r] size
      #   @return [Integer, nil] Size in bytes
      auto_attr :size, type: Integer

      # @!attribute [r] file_type
      #   @return [String] "PRINT_FILE", "FIRMWARE" or "FILE". Renamed from the API's `type`
      auto_attr :file_type, type: String

      # @!attribute [r] m_timestamp
      #   @return [Integer] Modification time, in seconds since the Unix epoch
      auto_attr :m_timestamp, type: Integer

      # @!attribute [r] refs
      #   @return [Files::Refs, nil] Links to download the file and to its thumbnails
      auto_attr :refs, type: Files::Refs

      # @!attribute [r] meta
      #   @return [Hash, nil] Metadata parsed from the file. The keys are kept as the printer sends them, some contain
      #     spaces (e.g. `:"filament used [g]"`, `:"estimated printing time (normal mode)"`)
      auto_attr :meta, type: Hash

      # @!attribute [r] extra
      #   @return [Hash] Any additional fields returned by the API
      auto_attr :extra, type: Hash

      auto_initialize!

      deserialize_config do
        nested :refs, Files::Refs
        # MK4, XL and MINI firmware send `ro` instead of the OpenAPI spec's `read_only`
        rename type: :file_type, ro: :read_only
      end

      # Whether the file can be printed (G-code, binary G-code or SL1)
      #
      # @return [Boolean]
      sig { returns(T::Boolean) }
      def print_file?
        file_type == "PRINT_FILE"
      end

      # Whether the file is a firmware file
      #
      # @return [Boolean]
      sig { returns(T::Boolean) }
      def firmware?
        file_type == "FIRMWARE"
      end

      # Always false, see {Files::Folder#folder?}
      #
      # @return [Boolean]
      sig { returns(T::Boolean) }
      def folder?
        false
      end
    end
  end
end
