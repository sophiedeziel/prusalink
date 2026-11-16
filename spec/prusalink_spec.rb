# typed: true
# frozen_string_literal: true

RSpec.describe Prusalink do
  it "has a version number" do
    expect(Prusalink::VERSION).not_to be_nil
  end

  describe ".configure" do
    it "sets a Digest auth client for the current thread" do
      described_class.configure(host: "http://printer.test", password: "secret")

      expect(described_class.client).to be_a(Prusalink::Client)
      expect(described_class.client.host).to eq("http://printer.test")
      expect(described_class.client.username).to eq("maker")
      expect(described_class.client.password).to eq("secret")
    end

    it "accepts an API key, a username and timeouts" do
      described_class.configure(host: "http://printer.test", api_key: "key", username: "admin",
                                open_timeout: 1, timeout: 2)

      expect(described_class.client).to have_attributes(api_key: "key", username: "admin",
                                                        open_timeout: 1, timeout: 2)
    end

    it "returns nil" do
      expect(described_class.configure(host: "http://printer.test", password: "secret")).to be_nil
    end
  end

  describe ".client" do
    it "is scoped to the current thread" do
      described_class.configure(host: "http://printer.test", password: "secret")

      expect(Thread.new { described_class.client }.value).to be_nil
    end
  end
end
