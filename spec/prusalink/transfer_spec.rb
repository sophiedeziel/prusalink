# typed: true
# frozen_string_literal: true

RSpec.describe Prusalink::Transfer do
  use_stubbed_printer

  let(:transfer_url) { "http://printer.test/api/v1/transfer" }
  let(:json_headers) { { "Content-Type" => "application/json" } }
  let(:payload) do
    {
      id: 72_855_542,
      type: "FROM_WEB",
      display_name: "Spice_Harvester_0.3mm_PLA_MK3S_12m.gcode",
      path: "/local",
      url: "https://files.printables.com/media/prints/42/gcodes/spice_harvester_0.3mm_pla_mk3s_12m.gcode",
      size: 239_314,
      progress: 42.25,
      transferred: 3_276_800,
      time_remaining: 61,
      time_transferring: 42,
      to_print: false,
      new_field: "surprise"
    }
  end

  it "inherits from BaseResource" do
    expect(described_class).to be < Prusalink::BaseResource
  end

  describe ".get" do
    context "when a transfer is running" do
      subject(:transfer) { described_class.get }

      before do
        stub_request(:get, transfer_url).to_return(status: 200, body: payload.to_json, headers: json_headers)
      end

      it "deserializes the transfer" do
        expect(transfer).to be_a(described_class)
        expect(transfer).to have_attributes(
          id: 72_855_542,
          transfer_type: "FROM_WEB",
          display_name: "Spice_Harvester_0.3mm_PLA_MK3S_12m.gcode",
          path: "/local",
          url: payload[:url],
          size: 239_314,
          progress: 42.25,
          transferred: 3_276_800,
          time_remaining: 61,
          time_transferring: 42,
          to_print: false
        )
      end

      it "collects unknown fields in extra" do
        expect(transfer.extra).to eq(new_field: "surprise")
      end

      it "sends the API key" do
        transfer
        expect(a_request(:get, transfer_url).with(headers: { "X-Api-Key" => "test-key" })).to have_been_made
      end
    end

    context "when nothing is transferring" do
      before { stub_request(:get, transfer_url).to_return(status: 204) }

      it "returns nil" do
        expect(described_class.get).to be_nil
      end
    end

    context "with a real printer", vcr: { cassette_name: "transfer/get_idle" } do
      use_prusalink_server

      it "returns nil when nothing is transferring (204 No Content)" do
        expect(described_class.get).to be_nil
      end
    end
  end

  describe ".stop" do
    let(:url) { "http://printer.test/api/v1/transfer/42" }

    it "sends DELETE /api/v1/transfer/{id} and returns true" do
      stub_request(:delete, url).to_return(status: 204)

      expect(described_class.stop(42)).to be(true)
      expect(a_request(:delete, url).with(headers: { "X-Api-Key" => "test-key" })).to have_been_made.once
    end

    it "raises NotFoundError on 404" do
      stub_request(:delete, url).to_return(status: 404)

      expect { described_class.stop(42) }.to raise_error(Prusalink::Exceptions::NotFoundError)
    end

    it "raises ConflictError on 409" do
      stub_request(:delete, url).to_return(status: 409)

      expect { described_class.stop(42) }.to raise_error(Prusalink::Exceptions::ConflictError)
    end
  end

  describe "#stop" do
    it "calls .stop with the transfer's id" do
      allow(described_class).to receive(:stop).and_return(true)

      expect(described_class.deserialize(payload).stop).to be(true)
      expect(described_class).to have_received(:stop).with(72_855_542)
    end

    it "raises ArgumentError when the printer didn't report an id" do
      transfer = described_class.deserialize(payload.except(:id))

      expect { transfer.stop }.to raise_error(ArgumentError, /no id/)
    end
  end
end
