# typed: true
# frozen_string_literal: true

RSpec.describe Prusalink::Status::Transfer do
  subject(:transfer) do
    described_class.deserialize(id: 72_855_542, time_transferring: 30, progress: 65.82, data_transferred: 123_084_800)
  end

  it do
    expect(transfer).to have_attributes(id: 72_855_542, time_transferring: 30, progress: 65.82,
                                        data_transferred: 123_084_800, extra: nil)
  end
end
