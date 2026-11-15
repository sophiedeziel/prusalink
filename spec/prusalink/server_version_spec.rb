# typed: true
# frozen_string_literal: true

RSpec.describe Prusalink::ServerVersion do
  use_stubbed_printer

  let(:payload) do
    {
      api: "2.0.0",
      version: "2.1.2",
      printer: "1.0.0",
      text: "PrusaLink",
      firmware: "6.1.3+8098",
      sdk: "0.7.0",
      capabilities: { "upload-by-put": true },
      server: "2.1.2",
      nozzle_diameter: 0.4,
      hostname: "prusa-mk4",
      new_field: 1
    }
  end

  before do
    stub_request(:get, "http://printer.test/api/version")
      .to_return(status: 200, body: payload.to_json, headers: { "Content-Type" => "application/json" })
  end

  describe ".get" do
    subject(:version) { described_class.get }

    it { is_expected.to be_a(described_class) }

    it "exposes the version fields" do
      expect(version).to have_attributes(api: "2.0.0", version: "2.1.2", printer: "1.0.0", text: "PrusaLink",
                                         firmware: "6.1.3+8098", sdk: "0.7.0")
    end

    it "exposes the fields MK4, XL and MINI firmware add" do
      expect(version).to have_attributes(server: "2.1.2", nozzle_diameter: 0.4, hostname: "prusa-mk4")
    end

    it "collects unknown fields into extra" do
      expect(version.extra).to eq(new_field: 1)
    end

    it { is_expected.to be_upload_by_put }

    context "with a real printer", vcr: { cassette_name: "server_version/get" } do
      use_prusalink_server

      it "reads the API version" do
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

      it { is_expected.to be_upload_by_put }
    end
  end

  describe "#upload_by_put?" do
    it "is false without capabilities" do
      expect(described_class.new(api: "1.0.0")).not_to be_upload_by_put
    end
  end
end
