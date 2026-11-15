# typed: true
# frozen_string_literal: true

RSpec.describe Prusalink::Files::File do
  describe ".deserialize" do
    subject(:file) do
      described_class.deserialize(
        name: "SPICE~1.GCO",
        display_name: "Spice_Harvester_0.3mm_PLA_MK3S_12m.gcode",
        read_only: true,
        size: 424_242,
        type: "PRINT_FILE",
        m_timestamp: 1_648_042_843,
        refs: { download: "/api/files/local/spice.gcode/raw", icon: "/icon.png", thumbnail: "/thumb.png" },
        meta: { "filament used [g]": 15.42, bed_temperature: 60 },
        new_field: "from a newer firmware"
      )
    end

    its(:name) { is_expected.to eq("SPICE~1.GCO") }
    its(:display_name) { is_expected.to eq("Spice_Harvester_0.3mm_PLA_MK3S_12m.gcode") }
    its(:read_only) { is_expected.to be(true) }
    its(:size) { is_expected.to eq(424_242) }
    its(:file_type) { is_expected.to eq("PRINT_FILE") }
    its(:m_timestamp) { is_expected.to eq(1_648_042_843) }
    its(:meta) { is_expected.to eq("filament used [g]": 15.42, bed_temperature: 60) }
    its(:extra) { is_expected.to eq(new_field: "from a newer firmware") }

    it "builds the refs" do
      expect(file.refs).to be_a(Prusalink::Files::Refs)
      expect(file.refs.download).to eq("/api/files/local/spice.gcode/raw")
    end
  end

  describe ".deserialize with the `ro` key that MK4, XL and MINI firmware send" do
    it "maps it to read_only" do
      file = described_class.deserialize(name: "SMARTT~1.BGC", type: "PRINT_FILE", ro: true)

      expect(file).to have_attributes(read_only: true, extra: nil)
    end
  end

  describe "predicates" do
    it "recognizes a print file" do
      file = described_class.deserialize(name: "a.gcode", type: "PRINT_FILE")

      expect(file).to be_print_file
      expect(file).not_to be_firmware
      expect(file).not_to be_folder
    end

    it "recognizes a firmware file" do
      file = described_class.deserialize(name: "fw.bbf", type: "FIRMWARE")

      expect(file).to be_firmware
      expect(file).not_to be_print_file
      expect(file).not_to be_folder
    end

    it "recognizes another file" do
      file = described_class.deserialize(name: "config.ini", type: "FILE")

      expect(file).not_to be_print_file
      expect(file).not_to be_firmware
      expect(file).not_to be_folder
    end
  end
end
