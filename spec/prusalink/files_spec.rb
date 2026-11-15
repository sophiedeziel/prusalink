# typed: true
# frozen_string_literal: true

RSpec.describe Prusalink::Files do
  use_stubbed_printer

  # A public calibration print at the root of the USB drive the cassettes were recorded with
  def calibration_print = "SmartTemperatureTower_PLA_180-225_0.4n_0.2mm_PLA_XLIS_1h42m.bgcode"

  let(:base_url) { "http://printer.test/api/v1/files" }
  let(:gcode_path) { File.expand_path("../files/test.gcode", __dir__) }

  let(:print_file_payload) do
    {
      name: "BENCHY~1.GCO",
      display_name: "benchy_0.4n_0.2mm_PLA_MK4_1h2m.gcode",
      read_only: false,
      size: 424_242,
      type: "PRINT_FILE",
      m_timestamp: 1_648_042_843,
      refs: {
        download: "/api/files/local/examples/benchy.gcode/raw",
        icon: "/api/thumbnails/local/examples/benchy.gcode.small.png",
        thumbnail: "/api/thumbnails/local/examples/benchy.gcode.orig.png"
      },
      meta: {
        "filament used [g]" => 15.42,
        "estimated printing time (normal mode)" => "42m 42s",
        filament_type: "PLA",
        layer_height: 0.3
      }
    }
  end

  let(:folder_payload) do
    {
      name: "examples",
      read_only: false,
      type: "FOLDER",
      m_timestamp: 1_648_042_843,
      children: [
        print_file_payload.except(:meta),
        { name: "FIRMWA~1.BBF", display_name: "firmware.bbf", read_only: true, size: 1024, type: "FIRMWARE",
          m_timestamp: 1_648_042_843, refs: { download: "/api/files/local/firmware.bbf/raw" } },
        { name: "config.ini", read_only: false, size: 12, type: "FILE", m_timestamp: 1_648_042_843 },
        { name: "nested", read_only: false, type: "FOLDER", m_timestamp: 1_648_042_843 }
      ]
    }
  end

  def json(payload)
    { status: 200, body: payload.to_json, headers: { "Content-Type" => "application/json" } }
  end

  it "inherits from BaseResource" do
    expect(described_class).to be < Prusalink::BaseResource
  end

  describe ".file_path" do
    def file_path(storage, path)
      described_class.send(:file_path, storage, path)
    end

    it "accepts the storage with or without slashes" do
      expect(file_path("usb", "a.gcode")).to eq("/api/v1/files/usb/a.gcode")
      expect(file_path("/usb", "a.gcode")).to eq("/api/v1/files/usb/a.gcode")
      expect(file_path("/usb/", "a.gcode")).to eq("/api/v1/files/usb/a.gcode")
    end

    it "accepts the path with or without a leading slash" do
      expect(file_path("local", "/prints/a.gcode")).to eq("/api/v1/files/local/prints/a.gcode")
      expect(file_path("local", "prints/a.gcode")).to eq("/api/v1/files/local/prints/a.gcode")
    end

    it "points to the storage's root when the path is empty" do
      expect(file_path("usb", "")).to eq("/api/v1/files/usb")
      expect(file_path("usb", "/")).to eq("/api/v1/files/usb")
    end

    it "encodes spaces as %20 and parentheses, but keeps the slashes" do
      expect(file_path("/usb/", "/my prints/benchy (1).gcode"))
        .to eq("/api/v1/files/usb/my%20prints/benchy%20%281%29.gcode")
    end

    it "encodes characters that would break the URL" do
      expect(file_path("usb", "a+b#c?d%e&f.gcode")).to eq("/api/v1/files/usb/a%2Bb%23c%3Fd%25e%26f.gcode")
    end
  end

  describe ".get" do
    it "returns a Files::File for a print file" do
      stub_request(:get, "#{base_url}/usb/benchy.gcode")
        .to_return(json(print_file_payload))

      file = described_class.get(storage: "usb", path: "benchy.gcode")

      expect(file).to be_a(Prusalink::Files::File)
      expect(file.name).to eq("BENCHY~1.GCO")
      expect(file.display_name).to eq("benchy_0.4n_0.2mm_PLA_MK4_1h2m.gcode")
      expect(file.file_type).to eq("PRINT_FILE")
      expect(file).to be_print_file
      expect(file.refs).to be_a(Prusalink::Files::Refs)
      expect(file.refs.thumbnail).to eq("/api/thumbnails/local/examples/benchy.gcode.orig.png")
      expect(file.meta[:"filament used [g]"]).to eq(15.42)
      expect(file.meta[:"estimated printing time (normal mode)"]).to eq("42m 42s")
    end

    it "returns a Files::File for a firmware file" do
      stub_request(:get, "#{base_url}/usb/firmware.bbf")
        .to_return(json(folder_payload[:children][1]))

      file = described_class.get(storage: "usb", path: "firmware.bbf")

      expect(file).to be_a(Prusalink::Files::File)
      expect(file).to be_firmware
    end

    it "returns a Files::Folder with its children for a folder" do
      stub_request(:get, "#{base_url}/local/examples")
        .to_return(json(folder_payload))

      folder = described_class.get(storage: "local", path: "examples")

      expect(folder).to be_a(Prusalink::Files::Folder)
      expect(folder.name).to eq("examples")
      expect(folder.children.map(&:class)).to eq(
        [Prusalink::Files::File, Prusalink::Files::File, Prusalink::Files::File, Prusalink::Files::Folder]
      )
      expect(folder.children.map(&:file_type)).to eq(%w[PRINT_FILE FIRMWARE FILE FOLDER])
      expect(folder.children.last).to be_folder
    end

    it "gets the storage's root by default" do
      stub_request(:get, "#{base_url}/usb")
        .to_return(json(folder_payload.merge(name: "usb")))

      expect(described_class.get(storage: "usb").name).to eq("usb")
    end

    it "URL-encodes the path" do
      stub = stub_request(:get, "#{base_url}/usb/my%20prints/benchy%20%281%29.gcode")
             .to_return(json(print_file_payload))

      described_class.get(storage: "/usb/", path: "/my prints/benchy (1).gcode")

      expect(stub).to have_been_requested
    end

    it "raises NotFoundError when the file doesn't exist" do
      stub_request(:get, "#{base_url}/usb/missing.gcode").to_return(status: 404)

      expect { described_class.get(storage: "usb", path: "missing.gcode") }
        .to raise_error(Prusalink::Exceptions::NotFoundError)
    end

    context "with a real printer, on a file", vcr: { cassette_name: "files/get_file" } do
      subject(:file) { described_class.get(storage: "usb", path: calibration_print) }

      use_prusalink_server

      it "builds a print file with its long and 8.3 short names" do
        expect(file).to be_a(Prusalink::Files::File)
        expect(file).to have_attributes(
          name: "SMARTT~1.BGC",
          display_name: calibration_print,
          file_type: "PRINT_FILE",
          read_only: false,
          size: a_kind_of(Integer),
          m_timestamp: a_kind_of(Integer),
          extra: nil
        )
        expect(file).to be_print_file
      end

      it "links to the thumbnails and the download" do
        expect(file.refs).to have_attributes(
          icon: "/thumb/s/usb/SMARTT~1.BGC",
          thumbnail: "/thumb/l/usb/SMARTT~1.BGC",
          download: "/usb/SMARTT~1.BGC"
        )
      end
    end

    context "with a real printer, on a folder", vcr: { cassette_name: "files/get_folder" } do
      use_prusalink_server

      it "builds a folder named after its 8.3 short name" do
        folder = described_class.get(storage: "usb", path: "Single-Tool")

        expect(folder).to be_a(Prusalink::Files::Folder)
        expect(folder).to have_attributes(name: "SINGLE~7", read_only: false, children: [], extra: nil)
      end
    end

    context "with a real printer, on a missing file", vcr: { cassette_name: "files/get_missing" } do
      use_prusalink_server

      it "raises NotFoundError" do
        expect { described_class.get(storage: "usb", path: "missing.bgcode") }
          .to raise_error(Prusalink::Exceptions::NotFoundError)
      end
    end
  end

  describe ".upload" do
    let(:upload_url) { "#{base_url}/usb/my%20prints/test.gcode" }

    before { stub_request(:put, upload_url).to_return(status: 201) }

    it "streams a file from a path with the size and RFC 8941 booleans in the headers" do
      result = described_class.upload(gcode_path, storage: "usb", path: "my prints/test.gcode")

      expect(result).to be(true)
      expect(
        a_request(:put, upload_url).with(
          body: File.binread(gcode_path),
          headers: {
            "Content-Type" => "application/octet-stream",
            "Content-Length" => File.size(gcode_path).to_s,
            "Print-After-Upload" => "?0",
            "Overwrite" => "?0"
          }
        )
      ).to have_been_made
    end

    it "closes the file it opened" do
      opened = nil
      allow(File).to receive(:open).and_wrap_original do |original, *args, &block|
        original.call(*args) do |io|
          opened = io
          block.call(io)
        end
      end

      described_class.upload(gcode_path, storage: "usb", path: "my prints/test.gcode")

      expect(File).to have_received(:open).with(gcode_path, "rb")
      expect(opened).to be_closed
    end

    it "closes the file when the upload fails" do
      stub_request(:put, upload_url).to_return(status: 409)
      opened = nil
      allow(File).to receive(:open).and_wrap_original do |original, *args, &block|
        original.call(*args) do |io|
          opened = io
          block.call(io)
        end
      end

      expect { described_class.upload(gcode_path, storage: "usb", path: "my prints/test.gcode") }
        .to raise_error(Prusalink::Exceptions::ConflictError)
      expect(opened).to be_closed
    end

    it "streams an IO" do
      io = StringIO.new("G28\nG1 X10\n")

      described_class.upload(io, storage: "usb", path: "/my prints/test.gcode",
                                 print_after_upload: true, overwrite: true)

      expect(
        a_request(:put, upload_url).with(
          body: "G28\nG1 X10\n",
          headers: {
            "Content-Type" => "application/octet-stream",
            "Content-Length" => "11",
            "Print-After-Upload" => "?1",
            "Overwrite" => "?1"
          }
        )
      ).to have_been_made
    end

    it "raises ArgumentError for an IO without a known size" do
      reader, writer = IO.pipe

      expect { described_class.upload(reader, storage: "usb", path: "my prints/test.gcode") }
        .to raise_error(ArgumentError, /known size/)
    ensure
      reader&.close
      writer&.close
    end

    it "raises ConflictError when the file exists" do
      stub_request(:put, upload_url).to_return(status: 409)

      expect { described_class.upload(StringIO.new("G28"), storage: "usb", path: "my prints/test.gcode") }
        .to raise_error(Prusalink::Exceptions::ConflictError)
    end
  end

  describe ".print" do
    it "sends a POST to the file and returns true" do
      stub_request(:post, "#{base_url}/usb/benchy%20%281%29.gcode").to_return(status: 204)

      expect(described_class.print(storage: "usb", path: "benchy (1).gcode")).to be(true)
      expect(a_request(:post, "#{base_url}/usb/benchy%20%281%29.gcode")).to have_been_made
    end

    it "raises ConflictError when the printer is busy" do
      stub_request(:post, "#{base_url}/usb/benchy.gcode").to_return(status: 409)

      expect { described_class.print(storage: "usb", path: "benchy.gcode") }
        .to raise_error(Prusalink::Exceptions::ConflictError)
    end
  end

  describe ".delete" do
    let(:url) { "#{base_url}/usb/old%20prints" }

    it "sends a DELETE with Force: ?0 by default" do
      stub_request(:delete, url).to_return(status: 204)

      expect(described_class.delete(storage: "usb", path: "old prints")).to be(true)
      expect(a_request(:delete, url).with(headers: { "Force" => "?0" })).to have_been_made
    end

    it "sends Force: ?1 when forced" do
      stub_request(:delete, url).to_return(status: 204)

      described_class.delete(storage: "usb", path: "old prints", force: true)

      expect(a_request(:delete, url).with(headers: { "Force" => "?1" })).to have_been_made
    end

    it "raises ConflictError when the file is being printed" do
      stub_request(:delete, url).to_return(status: 409)

      expect { described_class.delete(storage: "usb", path: "old prints") }
        .to raise_error(Prusalink::Exceptions::ConflictError)
    end
  end

  describe ".exists?" do
    it "returns true when the file exists" do
      stub_request(:head, "#{base_url}/usb/benchy.gcode").to_return(status: 200)

      expect(described_class.exists?(storage: "usb", path: "benchy.gcode")).to be(true)
    end

    it "returns false when the file doesn't exist" do
      stub_request(:head, "#{base_url}/usb/missing.gcode").to_return(status: 404)

      expect(described_class.exists?(storage: "usb", path: "missing.gcode")).to be(false)
    end

    it "raises other errors" do
      stub_request(:head, "#{base_url}/usb/benchy.gcode").to_return(status: 409)

      expect { described_class.exists?(storage: "usb", path: "benchy.gcode") }
        .to raise_error(Prusalink::Exceptions::ConflictError)
    end

    context "with a real printer, on a file", vcr: { cassette_name: "files/exists" } do
      use_prusalink_server

      it "is true (HEAD answered 200)" do
        expect(described_class.exists?(storage: "usb", path: calibration_print)).to be(true)
      end
    end

    context "with a real printer, on a missing file", vcr: { cassette_name: "files/exists_missing" } do
      use_prusalink_server

      it "is false (HEAD answered 404)" do
        expect(described_class.exists?(storage: "usb", path: "missing.bgcode")).to be(false)
      end
    end
  end

  describe ".info" do
    it "parses true/false headers" do
      stub_request(:head, "#{base_url}/usb/benchy.gcode")
        .to_return(status: 200, headers: { "Read-Only" => "false", "Currently-Printed" => "True" })

      expect(described_class.info(storage: "usb", path: "benchy.gcode"))
        .to eq(read_only: false, currently_printed: true)
    end

    it "parses RFC 8941 headers" do
      stub_request(:head, "#{base_url}/usb/benchy.gcode")
        .to_return(status: 200, headers: { "Read-Only" => "?1", "Currently-Printed" => "?0" })

      expect(described_class.info(storage: "usb", path: "benchy.gcode"))
        .to eq(read_only: true, currently_printed: false)
    end

    it "reads the Currently-Printing header that MK4, XL and MINI firmware send" do
      stub_request(:head, "#{base_url}/usb/benchy.gcode")
        .to_return(status: 200, headers: { "Read-Only" => "false", "Currently-Printing" => "true" })

      expect(described_class.info(storage: "usb", path: "benchy.gcode"))
        .to eq(read_only: false, currently_printed: true)
    end

    it "returns false when the headers are missing" do
      stub_request(:head, "#{base_url}/usb/benchy.gcode").to_return(status: 200)

      expect(described_class.info(storage: "usb", path: "benchy.gcode"))
        .to eq(read_only: false, currently_printed: false)
    end

    it "raises NotFoundError when the file doesn't exist" do
      stub_request(:head, "#{base_url}/usb/missing.gcode").to_return(status: 404)

      expect { described_class.info(storage: "usb", path: "missing.gcode") }
        .to raise_error(Prusalink::Exceptions::NotFoundError)
    end

    context "with a real printer", vcr: { cassette_name: "files/info" } do
      use_prusalink_server

      it "reads the Read-Only and Currently-Printing headers" do
        expect(described_class.info(storage: "usb", path: calibration_print))
          .to eq(read_only: false, currently_printed: false)
      end
    end
  end
end
