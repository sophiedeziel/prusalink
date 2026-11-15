# typed: true
# frozen_string_literal: true

RSpec.describe Prusalink::Files::Folder do
  describe ".deserialize" do
    subject(:folder) do
      described_class.deserialize(
        name: "examples",
        display_name: "examples",
        read_only: false,
        type: "FOLDER",
        m_timestamp: 1_648_042_843,
        children: [
          { name: "a.gcode", type: "PRINT_FILE", read_only: false, m_timestamp: 1, refs: { download: "/a" } },
          { name: "fw.bbf", type: "FIRMWARE", read_only: false, m_timestamp: 1 },
          { name: "sub", type: "FOLDER", read_only: false, m_timestamp: 1 }
        ],
        new_field: 1
      )
    end

    its(:name) { is_expected.to eq("examples") }
    its(:display_name) { is_expected.to eq("examples") }
    its(:read_only) { is_expected.to be(false) }
    its(:file_type) { is_expected.to eq("FOLDER") }
    its(:m_timestamp) { is_expected.to eq(1_648_042_843) }
    its(:size) { is_expected.to be_nil }
    its(:extra) { is_expected.to eq(new_field: 1) }

    it "dispatches each child according to its type" do
      expect(folder.children.map(&:class))
        .to eq([Prusalink::Files::File, Prusalink::Files::File, described_class])
      expect(folder.children[0]).to be_print_file
      expect(folder.children[0].refs.download).to eq("/a")
      expect(folder.children[1]).to be_firmware
      expect(folder.children[2]).to be_folder
      expect(folder.children[2].children).to be_nil
    end

    it "accepts a folder without children" do
      expect(described_class.deserialize(name: "empty", type: "FOLDER").children).to be_nil
    end
  end

  describe ".deserialize with the `ro` key that MK4, XL and MINI firmware send" do
    it "maps it to read_only, for the folder and its children" do
      folder = described_class.deserialize(
        name: "SINGLE~7", type: "FOLDER", ro: false,
        children: [{ name: "SMARTT~1.BGC", type: "PRINT_FILE", ro: true }]
      )

      expect(folder).to have_attributes(read_only: false, extra: nil)
      expect(folder.children.first).to have_attributes(read_only: true, extra: nil)
    end
  end

  describe "predicates" do
    subject(:folder) { described_class.deserialize(name: "sub", type: "FOLDER") }

    it { is_expected.to be_folder }
    it { is_expected.not_to be_print_file }
    it { is_expected.not_to be_firmware }
  end
end
