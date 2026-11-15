# typed: true
# frozen_string_literal: true

RSpec.describe Prusalink::Storage do
  use_stubbed_printer

  let(:storage_url) { "http://printer.test/api/v1/storage" }
  let(:json_headers) { { "Content-Type" => "application/json" } }
  let(:payload) do
    {
      storage_list: [
        {
          name: "PrusaLink gcodes",
          type: "LOCAL",
          path: "/local",
          print_files: 19_216_842,
          system_files: 4242,
          free_space: 1_921_681_142,
          total_space: 8_589_934_592,
          available: true,
          read_only: false
        },
        { name: "USB", type: "USB", path: "/usb", available: false, read_only: true, new_field: "surprise" }
      ]
    }
  end

  it "inherits from BaseResource" do
    expect(described_class).to be < Prusalink::BaseResource
  end

  describe ".list" do
    subject(:storages) { described_class.list }

    before do
      stub_request(:get, storage_url).to_return(status: 200, body: payload.to_json, headers: json_headers)
    end

    it "returns a Storage per entry" do
      expect(storages).to all(be_a(described_class))
      expect(storages.size).to eq(2)
    end

    it "deserializes the storages" do
      expect(storages.first).to have_attributes(
        name: "PrusaLink gcodes",
        storage_type: "LOCAL",
        path: "/local",
        print_files: 19_216_842,
        system_files: 4242,
        free_space: 1_921_681_142,
        total_space: 8_589_934_592,
        available: true,
        read_only: false
      )
      expect(storages.last).to have_attributes(storage_type: "USB", path: "/usb", free_space: nil)
    end

    it "collects unknown fields in extra" do
      expect(storages.last.extra).to eq(new_field: "surprise")
    end

    it "sends the API key" do
      storages
      expect(a_request(:get, storage_url).with(headers: { "X-Api-Key" => "test-key" })).to have_been_made
    end

    context "when the printer has no storage" do
      let(:payload) { { storage_list: [] } }

      it "returns an empty array" do
        expect(storages).to eq([])
      end
    end

    context "with a real printer", vcr: { cassette_name: "storage/list" } do
      use_prusalink_server

      it "lists the USB drive" do
        expect(storages).to contain_exactly(
          have_attributes(name: "usb", storage_type: "USB", path: "/usb/", available?: true, read_only?: false)
        )
      end
    end
  end

  describe "#available? and #read_only?" do
    it "reflects the attributes" do
      storage = described_class.new(available: true, read_only: false)
      expect(storage).to be_available
      expect(storage).not_to be_read_only
    end

    it "is false when the attributes are missing" do
      storage = described_class.new
      expect(storage).not_to be_available
      expect(storage).not_to be_read_only
    end

    it "is read only when the printer says so" do
      expect(described_class.new(available: false, read_only: true)).to be_read_only
    end
  end
end
