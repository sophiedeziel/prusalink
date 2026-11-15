# typed: true
# frozen_string_literal: true

RSpec.describe Prusalink::Status::Storage do
  subject(:storage) do
    described_class.deserialize(name: "LOCAL", path: "/local", read_only: false, free_space: 4_202_335)
  end

  it { is_expected.to have_attributes(name: "LOCAL", path: "/local", read_only: false, free_space: 4_202_335) }

  it "collects unknown fields in extra" do
    expect(described_class.deserialize(name: "USB", path: "/usb", read_only: true, type: "USB").extra)
      .to eq(type: "USB")
  end
end
