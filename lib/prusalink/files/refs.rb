# typed: true
# frozen_string_literal: true

module Prusalink
  class Files
    # Links to a file's download, icon and thumbnail. The paths are relative to the printer's host.
    #
    # @example
    #   file = Prusalink::Files.get(storage: "usb", path: "benchy.gcode")
    #   file.refs.download  # => "/usb/benchy.gcode"
    #   file.refs.thumbnail # => "/thumb/l/usb/benchy.gcode"
    class Refs
      include AutoInitializable
      include Deserializable

      # @!attribute [r] download
      #   @return [String, nil] Path to download the file
      auto_attr :download, type: String

      # @!attribute [r] icon
      #   @return [String, nil] Path to the file's small thumbnail. Print files only
      auto_attr :icon, type: String

      # @!attribute [r] thumbnail
      #   @return [String, nil] Path to the file's full size thumbnail. Print files only
      auto_attr :thumbnail, type: String

      # @!attribute [r] extra
      #   @return [Hash] Any additional fields returned by the API
      auto_attr :extra, type: Hash

      auto_initialize!
    end
  end
end
