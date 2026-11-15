# typed: true
# frozen_string_literal: true

RSpec.describe Prusalink::Status::Printer do
  let(:predicates) do
    {
      "IDLE" => :idle?,
      "BUSY" => :busy?,
      "PRINTING" => :printing?,
      "PAUSED" => :paused?,
      "FINISHED" => :finished?,
      "STOPPED" => :stopped?,
      "ERROR" => :error?,
      "ATTENTION" => :attention?,
      "READY" => :ready?
    }
  end

  describe ".deserialize" do
    subject(:printer) do
      described_class.deserialize(
        state: "PAUSED", temp_nozzle: 214.9, target_nozzle: 215.0, temp_bed: 59.5, target_bed: 60.0,
        axis_x: 23.2, axis_y: 24.3, axis_z: 0.5, flow: 95, speed: 100, fan_hotend: 420, fan_print: 420,
        status_printer: { ok: true, message: "OK" }, status_connect: { ok: false, message: "Offline" }
      )
    end

    it "sets every attribute" do
      expect(printer).to have_attributes(
        state: "PAUSED", temp_nozzle: 214.9, target_nozzle: 215.0, temp_bed: 59.5, target_bed: 60.0,
        axis_x: 23.2, axis_y: 24.3, axis_z: 0.5, flow: 95, speed: 100, fan_hotend: 420, fan_print: 420, extra: nil
      )
    end

    it "keeps status_printer and status_connect as Hashes" do
      expect(printer.status_printer).to eq(ok: true, message: "OK")
      expect(printer.status_connect).to eq(ok: false, message: "Offline")
    end
  end

  %w[IDLE BUSY PRINTING PAUSED FINISHED STOPPED ERROR ATTENTION READY].each do |state|
    context "when the state is #{state}" do
      subject(:printer) { described_class.new(state: state) }

      let(:predicate) { predicates.fetch(state) }

      it "answers true to its predicate" do
        expect(printer.public_send(predicate)).to be(true)
      end

      it "is not any other state" do
        (predicates.values - [predicate]).each do |other|
          expect(printer.public_send(other)).to be(false), "expected #{other} to be false for #{state}"
        end
      end
    end
  end

  context "when the state is missing" do
    subject(:printer) { described_class.new }

    it "answers false to every predicate" do
      predicates.each_value { |predicate| expect(printer.public_send(predicate)).to be(false) }
    end
  end
end
