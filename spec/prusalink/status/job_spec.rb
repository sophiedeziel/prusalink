# typed: true
# frozen_string_literal: true

RSpec.describe Prusalink::Status::Job do
  subject(:job) { described_class.deserialize(id: 420, progress: 42.0, time_remaining: 520, time_printing: 526) }

  it { is_expected.to have_attributes(id: 420, progress: 42.0, time_remaining: 520, time_printing: 526, extra: nil) }

  it "is distinct from the top-level job resource" do
    expect(described_class.name).to eq("Prusalink::Status::Job")
    expect(described_class.superclass).to eq(Object)
  end
end
