# typed: true
# frozen_string_literal: true

RSpec.describe Prusalink::Status do
  use_stubbed_printer

  let(:url) { "http://printer.test/api/v1/status" }
  let(:payload) do
    {
      job: { id: 420, progress: 42.0, time_remaining: 520, time_printing: 526 },
      printer: {
        state: "PRINTING",
        temp_nozzle: 214.9,
        target_nozzle: 215.0,
        temp_bed: 59.5,
        target_bed: 60.0,
        axis_z: 0.5,
        flow: 95,
        speed: 100,
        fan_hotend: 420,
        fan_print: 420,
        status_printer: { ok: true, message: "OK" },
        status_connect: { ok: true, message: "OK" }
      },
      transfer: { id: 72_855_542, time_transferring: 30, progress: 65.82, data_transferred: 123_084_800 },
      storage: { name: "LOCAL", path: "/local", read_only: false, free_space: 4_202_335 },
      camera: { id: "Ba1kmCbifTa8X" }
    }
  end

  def stub_status(status: 200, body: payload.to_json)
    stub_request(:get, url).to_return(status: status, body: body, headers: { "Content-Type" => "application/json" })
  end

  describe ".get" do
    context "when every section is reported" do
      subject(:status) { described_class.get }

      before { stub_status }

      it { is_expected.to be_a(described_class) }

      it "sends a GET request with the API key" do
        status
        expect(a_request(:get, url).with(headers: { "X-Api-Key" => "test-key" })).to have_been_made.once
      end

      it "deserializes the printer" do
        expect(status.printer).to be_a(Prusalink::Status::Printer)
        expect(status.printer).to have_attributes(state: "PRINTING", temp_nozzle: 214.9, target_bed: 60.0, flow: 95)
        expect(status.printer.status_connect).to eq(ok: true, message: "OK")
        expect(status.printer).to be_printing
      end

      it "deserializes the job as a Status::Job, not a top-level Job" do
        expect(status.job).to be_an_instance_of(Prusalink::Status::Job)
        expect(status.job).to have_attributes(id: 420, progress: 42.0, time_remaining: 520, time_printing: 526)
      end

      it "deserializes the transfer as a Status::Transfer" do
        expect(status.transfer).to be_an_instance_of(Prusalink::Status::Transfer)
        expect(status.transfer).to have_attributes(id: 72_855_542, time_transferring: 30, progress: 65.82,
                                                   data_transferred: 123_084_800)
      end

      it "deserializes the storage as a Status::Storage" do
        expect(status.storage).to be_an_instance_of(Prusalink::Status::Storage)
        expect(status.storage).to have_attributes(name: "LOCAL", path: "/local", read_only: false,
                                                  free_space: 4_202_335)
      end

      it "deserializes the camera" do
        expect(status.camera).to be_an_instance_of(Prusalink::Status::Camera)
        expect(status.camera.id).to eq("Ba1kmCbifTa8X")
      end

      it "has no extra fields" do
        expect(status.extra).to be_nil
      end
    end

    context "when only the printer is reported" do
      subject(:status) { described_class.get }

      before { stub_status(body: { printer: { state: "IDLE", temp_bed: 21.3 } }.to_json) }

      it "leaves the optional sections nil" do
        expect(status).to have_attributes(job: nil, transfer: nil, storage: nil, camera: nil)
        expect(status.printer).to be_idle
        expect(status.printer.axis_x).to be_nil
      end
    end

    context "when the response has unknown fields" do
      subject(:status) { described_class.get }

      before do
        body = payload.merge(newSection: { a: 1 })
        body[:printer] = body[:printer].merge(fanExtra: 12)
        body[:job] = body[:job].merge(fileName: "x.gcode")
        stub_status(body: body.to_json)
      end

      it "collects them in extra at every level" do
        expect(status.extra).to eq(new_section: { a: 1 })
        expect(status.printer.extra).to eq(fan_extra: 12)
        expect(status.job.extra).to eq(file_name: "x.gcode")
      end
    end

    context "when the printer answers 204 No Content" do
      before { stub_status(status: 204, body: "") }

      it { expect(described_class.get).to be_nil }
    end

    context "when the printer answers 404" do
      before { stub_status(status: 404, body: "") }

      it { expect { described_class.get }.to raise_error(Prusalink::Exceptions::NotFoundError) }
    end

    context "when the printer answers 409" do
      before { stub_status(status: 409, body: "") }

      it { expect { described_class.get }.to raise_error(Prusalink::Exceptions::ConflictError) }
    end

    context "with a real printer", vcr: { cassette_name: "status/get" } do
      subject(:status) { described_class.get }

      use_prusalink_server

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
  end
end
