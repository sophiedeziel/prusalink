# typed: true
# frozen_string_literal: true

module Prusalink
  class Job
    # The file being printed by the current job.
    #
    # @example
    #   file = Prusalink::Job.get.file
    #   file.display_name # => "Spice_Harvester_0.3mm_PLA_MK3S_12m.gcode"
    #   file.full_path    # => "/usb/SPICE~1.gco"
    class File
      extend T::Sig
      include AutoInitializable
      include Deserializable

      # @!attribute [r] name
      #   @return [String] Short filename, e.g. "SPICE~1.gco"
      auto_attr :name, type: String

      # @!attribute [r] display_name
      #   @return [String, nil] Long filename, e.g. "Spice_Harvester_0.3mm_PLA_MK3S_12m.gcode"
      auto_attr :display_name, type: String

      # @!attribute [r] path
      #   @return [String] Path of the folder containing the file, e.g. "/local"
      auto_attr :path, type: String

      # @!attribute [r] display_path
      #   @return [String, nil] Human readable path of the folder, e.g. "/PrusaLink gcodes"
      auto_attr :display_path, type: String

      # @!attribute [r] size
      #   @return [Integer, nil] File size in bytes
      auto_attr :size, type: Integer

      # @!attribute [r] m_timestamp
      #   @return [Integer] Modification time, in seconds since the epoch
      auto_attr :m_timestamp, type: Integer

      # @!attribute [r] meta
      #   @return [Hash, nil] Metadata parsed from the G-code. Keys are symbols and may contain spaces,
      #     e.g. :"filament used [g]"
      auto_attr :meta, type: Hash

      # @!attribute [r] refs
      #   @return [Hash, nil] Links to the file's download, icon and thumbnail, e.g. { download: "/api/files/..." }
      auto_attr :refs, type: Hash

      # @!attribute [r] extra
      #   @return [Hash] Any additional fields returned by the API
      auto_attr :extra, type: Hash

      auto_initialize!

      # The complete path of the file on the printer, joining {#path} and {#name}.
      #
      # @example
      #   file.path      # => "/usb"
      #   file.name      # => "SPICE~1.gco"
      #   file.full_path # => "/usb/SPICE~1.gco"
      #
      # @return [String]
      sig { returns(String) }
      def full_path
        [path.to_s.chomp("/"), name].join("/")
      end
    end
  end
end
