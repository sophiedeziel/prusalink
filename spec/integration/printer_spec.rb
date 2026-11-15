# typed: true
# frozen_string_literal: true

# Real HTTP exchanges with a printer, replayed from VCR cassettes (see "Recording VCR cassettes" in CLAUDE.md).
# They were recorded against a Prusa XL while it was idle. Its USB drive has an empty "Single-Tool" folder and the
# SmartTemperatureTower calibration print at its root.
# Only read-only endpoints are covered, so recording again never changes the printer's state.
RSpec.describe "PrusaLink API", type: :integration do
  use_prusalink_server

  describe "ServerVersion.get", vcr: { cassette_name: "server_version/get" } do
    subject(:version) { Prusalink::ServerVersion.get }

    it "signs the request with Digest auth and reads the API version" do
      expect(version).to have_attributes(text: "PrusaLink", api: a_string_starting_with("2."))
    end

    it "reads the fields the firmware adds to the spec" do
      expect(version).to have_attributes(
        server: a_kind_of(String),
        nozzle_diameter: a_kind_of(Float),
        hostname: a_kind_of(String),
        extra: nil
      )
    end

    it "reports that uploads use PUT" do
      expect(version).to be_upload_by_put
    end
  end

  describe "Info.get", vcr: { cassette_name: "info/get" } do
    subject(:info) { Prusalink::Info.get }

    it "reads the printer's information" do
      expect(info).to have_attributes(
        hostname: a_kind_of(String),
        nozzle_diameter: a_kind_of(Float),
        min_extrusion_temp: a_kind_of(Integer),
        serial: a_kind_of(String),
        mmu: false
      )
    end
  end

  # Live requests and responses aren't filtered while recording, so check what was saved instead
  describe "the recorded cassettes" do
    let(:cassettes) { Dir[File.expand_path("../cassettes/**/*.yml", __dir__)] }

    def leaking(pattern)
      cassettes.select { |path| File.read(path).match?(pattern) }
    end

    it "exist" do
      expect(cassettes).not_to be_empty
    end

    it "never contain a serial number" do
      expect(leaking(/"serial"\s*:\s*"(?!<SERIAL>")/)).to be_empty
    end

    it "never contain a Digest response hash" do
      expect(leaking(/response="(?!<DIGEST>")/)).to be_empty
    end
  end

  describe "Status.get", vcr: { cassette_name: "status/get" } do
    subject(:status) { Prusalink::Status.get }

    it "reads the printer's state and temperatures" do
      expect(status.printer).to have_attributes(
        state: "IDLE",
        temp_nozzle: a_kind_of(Float),
        temp_bed: a_kind_of(Float),
        speed: a_kind_of(Integer)
      )
    end

    it "reads the current storage" do
      expect(status.storage).to have_attributes(name: "usb", path: "/usb/", read_only: false)
    end

    it "has no job nor transfer while idle" do
      expect(status).to have_attributes(job: nil, transfer: nil)
    end
  end

  describe "Storage.list", vcr: { cassette_name: "storage/list" } do
    subject(:storages) { Prusalink::Storage.list }

    it "lists the USB drive" do
      expect(storages).to contain_exactly(
        have_attributes(name: "usb", storage_type: "USB", path: "/usb/", available?: true, read_only?: false)
      )
    end
  end

  describe "Job.get", vcr: { cassette_name: "job/get_idle" } do
    it "returns nil while idle (204 No Content)" do
      expect(Prusalink::Job.get).to be_nil
    end
  end

  describe "Transfer.get", vcr: { cassette_name: "transfer/get_idle" } do
    it "returns nil when nothing is transferring (204 No Content)" do
      expect(Prusalink::Transfer.get).to be_nil
    end
  end

  describe "Files" do
    # A public calibration print that sits at the root of the USB drive
    let(:tower) { "SmartTemperatureTower_PLA_180-225_0.4n_0.2mm_PLA_XLIS_1h42m.bgcode" }

    describe ".get on a file", vcr: { cassette_name: "files/get_file" } do
      subject(:file) { Prusalink::Files.get(storage: "usb", path: tower) }

      it "builds a print file with its long and 8.3 short names" do
        expect(file).to be_a(Prusalink::Files::File)
        expect(file).to have_attributes(
          name: "SMARTT~1.BGC",
          display_name: tower,
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

    describe ".exists? on a file", vcr: { cassette_name: "files/exists" } do
      it "is true (HEAD answered 200)" do
        expect(Prusalink::Files.exists?(storage: "usb", path: tower)).to be(true)
      end
    end

    describe ".info", vcr: { cassette_name: "files/info" } do
      it "reads the Read-Only and Currently-Printing headers" do
        expect(Prusalink::Files.info(storage: "usb", path: tower)).to eq(read_only: false, currently_printed: false)
      end
    end

    describe ".get on a folder", vcr: { cassette_name: "files/get_folder" } do
      subject(:folder) { Prusalink::Files.get(storage: "usb", path: "Single-Tool") }

      it "builds a folder named after its 8.3 short name" do
        expect(folder).to be_a(Prusalink::Files::Folder)
        expect(folder).to have_attributes(name: "SINGLE~7", read_only: false, children: [], extra: nil)
      end
    end

    describe ".get on a missing file", vcr: { cassette_name: "files/get_missing" } do
      it "raises NotFoundError" do
        expect { Prusalink::Files.get(storage: "usb", path: "missing.bgcode") }
          .to raise_error(Prusalink::Exceptions::NotFoundError)
      end
    end

    describe ".exists? on a missing file", vcr: { cassette_name: "files/exists_missing" } do
      it "is false (HEAD answered 404)" do
        expect(Prusalink::Files.exists?(storage: "usb", path: "missing.bgcode")).to be(false)
      end
    end
  end

  describe "a wrong password", vcr: { cassette_name: "client/wrong_password" } do
    before { Prusalink.configure(host: prusalink_host, username: prusalink_username, password: "wrong-password") }

    it "raises AuthenticationError after answering the Digest challenge" do
      expect { Prusalink::ServerVersion.get }.to raise_error(Prusalink::Exceptions::AuthenticationError)
    end
  end
end
