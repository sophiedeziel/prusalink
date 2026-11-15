# typed: true
# frozen_string_literal: true

# Requests and responses aren't filtered while recording, only what VCR saves is.
# So check the saved cassettes for anything the filters in spec_helper.rb should have replaced.
RSpec.describe "VCR cassettes", type: :integration do
  let(:cassettes) { Dir[File.expand_path("../cassettes/**/*.yml", __dir__)] }

  def leaking(pattern)
    cassettes.select { |path| File.read(path).match?(pattern) }
  end

  it "exist" do
    expect(cassettes).not_to be_empty
  end

  it "never contain a serial number" do
    expect(leaking(/"serial"\s*:\s*"(?!<SERIAL>")/)).to be_empty
  end

  it "never contain a Digest response hash" do
    expect(leaking(/response="(?!<DIGEST>")/)).to be_empty
  end
end
