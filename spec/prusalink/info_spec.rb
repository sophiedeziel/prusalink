# typed: true
# frozen_string_literal: true

RSpec.describe Prusalink::Info do
  use_stubbed_printer

  let(:url) { "http://printer.test/api/v1/info" }
  let(:payload) do
    {
      mmu: false,
      name: "MuadDib",
      location: "Arrakis",
      farm_mode: false,
      nozzle_diameter: 0.4,
      min_extrusion_temp: 170,
      serial: "CZPX4720X004XC34242",
      sd_ready: true,
      active_camera: true,
      hostname: "prusa-mk3.lan",
      port: "/dev/tty",
      network_error_chime: true
    }
  end

  def stub_info(status: 200, body: payload.to_json)
    stub_request(:get, url).to_return(status: status, body: body, headers: { "Content-Type" => "application/json" })
  end

  describe ".get" do
    context "when the printer answers with its information" do
      subject(:info) { described_class.get }

      before { stub_info }

      it { is_expected.to be_a(described_class) }

      it "sends a GET request with the API key" do
        info
        expect(a_request(:get, url).with(headers: { "X-Api-Key" => "test-key" })).to have_been_made.once
      end

      it "deserializes every field" do
        expect(info).to have_attributes(
          mmu: false,
          name: "MuadDib",
          location: "Arrakis",
          farm_mode: false,
          nozzle_diameter: 0.4,
          min_extrusion_temp: 170,
          serial: "CZPX4720X004XC34242",
          sd_ready: true,
          active_camera: true,
          hostname: "prusa-mk3.lan",
          port: "/dev/tty",
          network_error_chime: true,
          extra: nil
        )
      end
    end

    context "when the response has unknown fields" do
      before { stub_info(body: payload.merge(newField: 1).to_json) }

      it "collects them in extra" do
        expect(described_class.get.extra).to eq(new_field: 1)
      end
    end

    context "when the response only has some fields" do
      before { stub_info(body: { name: "MK4" }.to_json) }

      it "leaves the missing fields nil" do
        expect(described_class.get).to have_attributes(name: "MK4", serial: nil, mmu: nil)
      end
    end

    context "when the printer answers 204 No Content" do
      before { stub_info(status: 204, body: "") }

      it { expect(described_class.get).to be_nil }
    end

    context "when the printer answers 404" do
      before { stub_info(status: 404, body: "") }

      it { expect { described_class.get }.to raise_error(Prusalink::Exceptions::NotFoundError) }
    end

    context "with a real printer", vcr: { cassette_name: "info/get" } do
      use_prusalink_server

      it "reads the printer's information" do
        expect(described_class.get).to have_attributes(
          hostname: a_kind_of(String),
          nozzle_diameter: a_kind_of(Float),
          min_extrusion_temp: a_kind_of(Integer),
          serial: a_kind_of(String),
          mmu: false
        )
      end
    end
  end
end
