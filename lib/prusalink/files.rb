# typed: true
# frozen_string_literal: true

require "erb"
require "stringio"
require "tempfile"

module Prusalink
  # Files and folders on the printer's storages (USB drive, local storage, SD card).
  #
  # `storage` is the storage's name, with or without slashes ("usb", "/usb" or "local").
  # `path` is relative to the storage, with or without a leading slash. Spaces and other special
  # characters are URL-encoded for you.
  #
  # @example
  #   folder = Prusalink::Files.get(storage: "usb")
  #   folder.children.map(&:display_name) # => ["benchy.gcode", "prints"]
  #
  #   Prusalink::Files.upload("benchy.gcode", storage: "usb", path: "prints/benchy.gcode", print_after_upload: true)
  #   Prusalink::Files.exists?(storage: "usb", path: "prints/benchy.gcode") # => true
  #   Prusalink::Files.delete(storage: "usb", path: "prints/benchy.gcode")
  class Files < BaseResource
    extend T::Sig

    resource_path("/api/v1/files")

    # Gets the metadata of a file, or a folder with its content.
    #
    # @param storage [String]   the storage's name, e.g. "usb"
    # @param path [String]      path to the file or folder. Defaults to the storage's root
    # @return [Files::File, Files::Folder]
    # @raise [Prusalink::Exceptions::NotFoundError] if the file doesn't exist
    sig { params(storage: String, path: String).returns(T.any(Files::File, Files::Folder)) }
    def self.get(storage:, path: "")
      build_entry(client.request(file_path(storage, path), http_method: :get))
    end

    # Uploads a file. The file is streamed, it isn't loaded in memory.
    #
    # @example From a path on disk
    #   Prusalink::Files.upload("benchy.gcode", storage: "usb", path: "benchy.gcode")
    #
    # @example From an IO
    #   Prusalink::Files.upload(StringIO.new(gcode), storage: "usb", path: "generated.gcode", overwrite: true)
    #
    # @param file [String, IO, StringIO, Tempfile]  a path to a file on disk, or an IO with a known size
    # @param storage [String]                       the storage's name, e.g. "usb"
    # @param path [String]                          the destination path, including the file name
    # @param print_after_upload [Boolean]           whether to start printing the file once it is uploaded
    # @param overwrite [Boolean]                    whether to replace an existing file
    # @return [true]
    # @raise [Prusalink::Exceptions::ConflictError] if the file already exists and overwrite is false
    # @raise [ArgumentError] if the IO doesn't know its size (e.g. a pipe)
    sig do
      params(
        file: T.any(String, IO, StringIO, Tempfile),
        storage: String,
        path: String,
        print_after_upload: T::Boolean,
        overwrite: T::Boolean
      ).returns(T::Boolean)
    end
    def self.upload(file, storage:, path:, print_after_upload: false, overwrite: false)
      destination = file_path(storage, path)
      headers = {
        "Content-Type" => "application/octet-stream",
        "Print-After-Upload" => structured_boolean(print_after_upload),
        "Overwrite" => structured_boolean(overwrite)
      }

      if file.is_a?(String)
        ::File.open(file, "rb") { |io| upload_io(io, destination, headers) }
      else
        upload_io(file, destination, headers)
      end
    end

    # Starts printing an existing file, if no print job is running.
    #
    # @param storage [String]   the storage's name, e.g. "usb"
    # @param path [String]      path to the file
    # @return [true]
    # @raise [Prusalink::Exceptions::ConflictError] if the printer is busy
    sig { params(storage: String, path: String).returns(T::Boolean) }
    def self.print(storage:, path:)
      post(path: file_path(storage, path))
    end

    # Deletes a file or a folder.
    #
    # Replaces {BaseResource.delete} with a signature that fits files, then calls it with the built path and
    # headers. The signatures differ on purpose, hence `allow_incompatible`.
    #
    # @param storage [String]   the storage's name, e.g. "usb"
    # @param path [String]      path to the file or folder
    # @param force [Boolean]    whether to delete a folder that isn't empty
    # @return [true]
    # @raise [Prusalink::Exceptions::ConflictError] if the file is being printed, or the folder isn't empty
    sig do
      override(allow_incompatible: true)
        .params(storage: String, path: String, force: T::Boolean)
        .returns(T::Boolean)
    end
    def self.delete(storage:, path:, force: false)
      super(path: file_path(storage, path), headers: { "Force" => structured_boolean(force) })
    end

    # Whether a file or folder exists.
    #
    # @param storage [String]   the storage's name, e.g. "usb"
    # @param path [String]      path to the file or folder
    # @return [Boolean]
    sig { params(storage: String, path: String).returns(T::Boolean) }
    def self.exists?(storage:, path:)
      head(path: file_path(storage, path))
      true
    rescue Exceptions::NotFoundError
      false
    end

    # Whether a file is read-only, and whether it is being printed.
    #
    # @example
    #   Prusalink::Files.info(storage: "usb", path: "benchy.gcode")
    #   # => { read_only: false, currently_printed: true }
    #
    # @param storage [String]   the storage's name, e.g. "usb"
    # @param path [String]      path to the file or folder
    # @return [Hash{Symbol => Boolean}]
    # @raise [Prusalink::Exceptions::NotFoundError] if the file doesn't exist
    sig { params(storage: String, path: String).returns(T::Hash[Symbol, T::Boolean]) }
    def self.info(storage:, path:)
      headers = head(path: file_path(storage, path))

      {
        read_only: header_true?(headers["read-only"]),
        currently_printed: header_true?(headers["currently-printed"])
      }
    end

    # Builds a {Files::Folder} or a {Files::File} according to the entry's `type`.
    #
    # @param data [Hash] a file or folder, as returned by the API
    # @return [Files::File, Files::Folder]
    # @api private
    sig { params(data: T::Hash[Symbol, T.untyped]).returns(T.any(Files::File, Files::Folder)) }
    def self.build_entry(data)
      data[:type] == "FOLDER" ? Files::Folder.deserialize(data) : Files::File.deserialize(data)
    end

    # Builds the request path, e.g. ("/usb/", "/my prints/benchy (1).gcode")
    # gives "/api/v1/files/usb/my%20prints/benchy%20%281%29.gcode".
    # Every segment is URL-encoded (spaces as %20, parentheses as %28 and %29), slashes are kept.
    sig { params(storage: String, path: String).returns(String) }
    private_class_method def self.file_path(storage, path)
      segments = [storage, path].flat_map { |part| part.split("/") }.reject(&:empty?)

      [@path, *segments.map { |segment| ERB::Util.url_encode(segment) }].join("/")
    end

    sig { params(io: T.any(IO, StringIO, Tempfile), path: String, headers: T::Hash[String, String]).returns(T::Boolean) }
    private_class_method def self.upload_io(io, path, headers)
      # PrusaLink requires a Content-Length, so the IO must know its size (File, StringIO, Tempfile).
      # A pipe or a socket doesn't.
      unless io.respond_to?(:size)
        raise ArgumentError, "Can't upload a #{io.class} without a known size. Pass a path, a File or a StringIO"
      end

      put(path: path, params: io, headers: headers.merge("Content-Length" => T.unsafe(io).size.to_s))
    end

    # RFC 8941 boolean, the format PrusaLink expects in its headers
    sig { params(value: T::Boolean).returns(String) }
    private_class_method def self.structured_boolean(value)
      value ? "?1" : "?0"
    end

    # PrusaLink sends booleans in headers as "true"/"false" or as RFC 8941 booleans ("?1"/"?0")
    sig { params(value: T.nilable(String)).returns(T::Boolean) }
    private_class_method def self.header_true?(value)
      %w[true ?1 1].include?(value.to_s.strip.downcase)
    end
  end
end
