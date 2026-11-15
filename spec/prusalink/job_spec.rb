# typed: true
# frozen_string_literal: true

RSpec.describe Prusalink::Job do
  use_stubbed_printer

  let(:job_url) { "http://printer.test/api/v1/job" }
  let(:json_headers) { { "Content-Type" => "application/json" } }
  let(:payload) do
    {
      id: 420,
      state: "PRINTING",
      progress: 42.0,
      time_remaining: 520,
      time_printing: 526,
      inaccurate_estimates: false,
      serial_print: false,
      file: {
        name: "SPICE~1.gco",
        display_name: "Spice_Harvester_0.3mm_PLA_MK3S_12m.gcode",
        path: "/usb",
        display_path: "/USB",
        size: 2_393_142,
        m_timestamp: 1_648_042_843,
        meta: { "filament used [g]": 15.42, filament_type: "PLA", estimated_print_time: 25_421 },
        refs: { download: "/api/files/usb/SPICE~1.gco/raw", icon: "/api/thumbnails/usb/SPICE~1.gco.small.png" }
      },
      new_field: "surprise"
    }
  end

  it "inherits from BaseResource" do
    expect(described_class).to be < Prusalink::BaseResource
  end

  describe ".get" do
    context "when a job is running" do
      subject(:job) { described_class.get }

      before do
        stub_request(:get, job_url).to_return(status: 200, body: payload.to_json, headers: json_headers)
      end

      it "returns a Job" do
        expect(job).to be_a(described_class)
      end

      it "deserializes the job's attributes" do
        expect(job).to have_attributes(
          id: 420,
          state: "PRINTING",
          progress: 42.0,
          time_remaining: 520,
          time_printing: 526,
          inaccurate_estimates: false,
          serial_print: false
        )
      end

      it "deserializes the file" do
        expect(job.file).to be_a(Prusalink::Job::File)
        expect(job.file).to have_attributes(
          name: "SPICE~1.gco",
          display_name: "Spice_Harvester_0.3mm_PLA_MK3S_12m.gcode",
          path: "/usb",
          display_path: "/USB",
          size: 2_393_142,
          m_timestamp: 1_648_042_843
        )
        expect(job.file.full_path).to eq("/usb/SPICE~1.gco")
      end

      it "keeps the file's meta and refs as hashes" do
        expect(job.file.meta).to include("filament used [g]": 15.42, filament_type: "PLA")
        expect(job.file.refs).to eq(
          download: "/api/files/usb/SPICE~1.gco/raw", icon: "/api/thumbnails/usb/SPICE~1.gco.small.png"
        )
      end

      it "collects unknown fields in extra" do
        expect(job.extra).to eq(new_field: "surprise")
      end

      it "sends the API key" do
        job
        expect(a_request(:get, job_url).with(headers: { "X-Api-Key" => "test-key" })).to have_been_made
      end
    end

    context "when printing from the serial line" do
      before do
        body = { id: 7, state: "PRINTING", progress: 3.5, time_printing: 12, serial_print: true }
        stub_request(:get, job_url).to_return(status: 200, body: body.to_json, headers: json_headers)
      end

      it "has no file" do
        job = described_class.get
        expect(job.serial_print).to be(true)
        expect(job.file).to be_nil
      end
    end

    context "when there is no job" do
      before { stub_request(:get, job_url).to_return(status: 204) }

      it "returns nil" do
        expect(described_class.get).to be_nil
      end
    end

    context "with a real printer", vcr: { cassette_name: "job/get_idle" } do
      use_prusalink_server

      it "returns nil while idle (204 No Content)" do
        expect(described_class.get).to be_nil
      end
    end
  end

  describe "class commands" do
    [
      [:stop, :delete, "/api/v1/job/420"],
      [:pause, :put, "/api/v1/job/420/pause"],
      [:resume, :put, "/api/v1/job/420/resume"],
      [:continue, :put, "/api/v1/job/420/continue"]
    ].each do |command, http_method, path|
      describe ".#{command}" do
        let(:url) { "http://printer.test#{path}" }

        it "sends #{http_method.upcase} #{path} and returns true" do
          stub_request(http_method, url).to_return(status: 204)

          expect(described_class.public_send(command, 420)).to be(true)
          expect(a_request(http_method, url).with(headers: { "X-Api-Key" => "test-key" })).to have_been_made.once
        end

        it "raises NotFoundError on 404" do
          stub_request(http_method, url).to_return(status: 404)

          expect { described_class.public_send(command, 420) }.to raise_error(Prusalink::Exceptions::NotFoundError)
        end

        it "raises ConflictError on 409" do
          stub_request(http_method, url).to_return(status: 409)

          expect { described_class.public_send(command, 420) }.to raise_error(Prusalink::Exceptions::ConflictError)
        end
      end
    end
  end

  describe "instance commands" do
    subject(:job) { described_class.deserialize(payload) }

    %i[stop pause resume continue].each do |command|
      it "##{command} calls .#{command} with the job's id" do
        allow(described_class).to receive(command).and_return(true)

        expect(job.public_send(command)).to be(true)
        expect(described_class).to have_received(command).with(420)
      end
    end
  end

  describe "state predicates" do
    {
      "PRINTING" => :printing?,
      "PAUSED" => :paused?,
      "FINISHED" => :finished?,
      "STOPPED" => :stopped?,
      "ERROR" => :error?
    }.each do |state, predicate|
      context "when the state is #{state}" do
        subject(:job) { described_class.new(id: 1, state: state) }

        it "is #{predicate}" do
          expect(job.public_send(predicate)).to be(true)
        end

        it "is not any other state" do
          others = %i[printing? paused? finished? stopped? error?] - [predicate]
          expect(others.map { |other| job.public_send(other) }).to all(be(false))
        end
      end
    end
  end
end
