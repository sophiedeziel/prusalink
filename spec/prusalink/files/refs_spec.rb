# typed: true
# frozen_string_literal: true

RSpec.describe Prusalink::Files::Refs do
  subject(:refs) do
    described_class.deserialize(
      download: "/api/files/local/examples/spice.gcode/raw",
      icon: "/api/thumbnails/local/examples/spice.gcode.small.png",
      thumbnail: "/api/thumbnails/local/examples/spice.gcode.orig.png",
      preview: "/new.png"
    )
  end

  its(:download) { is_expected.to eq("/api/files/local/examples/spice.gcode/raw") }
  its(:icon) { is_expected.to eq("/api/thumbnails/local/examples/spice.gcode.small.png") }
  its(:thumbnail) { is_expected.to eq("/api/thumbnails/local/examples/spice.gcode.orig.png") }
  its(:extra) { is_expected.to eq(preview: "/new.png") }
end
