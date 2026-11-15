# typed: true
# frozen_string_literal: true

RSpec.describe Prusalink::Job::File do
  describe ".deserialize" do
    subject(:file) do
      described_class.deserialize(
        name: "SPICE~1.gco", path: "/local", m_timestamp: 1_648_042_843, read_only: false
      )
    end

    it "builds the file" do
      expect(file).to have_attributes(name: "SPICE~1.gco", path: "/local", m_timestamp: 1_648_042_843)
    end

    it "collects unknown fields in extra" do
      expect(file.extra).to eq(read_only: false)
    end
  end

  describe "#full_path" do
    it "joins the path and the name" do
      expect(described_class.new(path: "/usb", name: "SPICE~1.gco").full_path).to eq("/usb/SPICE~1.gco")
    end

    it "doesn't double a trailing slash in the path" do
      expect(described_class.new(path: "/usb/", name: "SPICE~1.gco").full_path).to eq("/usb/SPICE~1.gco")
    end

    it "handles nested folders" do
      expect(described_class.new(path: "/local/examples", name: "a.gcode").full_path).to eq("/local/examples/a.gcode")
    end
  end
end
