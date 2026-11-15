# typed: true
# frozen_string_literal: true

RSpec.describe Prusalink::Status::Camera do
  subject(:camera) { described_class.deserialize(id: "Ba1kmCbifTa8X") }

  it { is_expected.to have_attributes(id: "Ba1kmCbifTa8X", extra: nil) }
end
