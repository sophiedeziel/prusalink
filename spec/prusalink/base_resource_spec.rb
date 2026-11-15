# typed: true
# frozen_string_literal: true

RSpec.describe Prusalink::BaseResource do
  let(:test_class) do
    Class.new(described_class) do
      resource_path "/api/test"
    end
  end

  let(:client) { Prusalink::Client.new(host: "http://printer.test", api_key: "test-key") }

  before { Prusalink.client = client }

  describe ".fetch_resource" do
    before { allow(client).to receive(:request).and_return({ name: "test" }) }

    it "GETs the resource path and deserializes the response" do
      allow(test_class).to receive(:deserialize).with({ name: "test" }).and_return("deserialized")

      expect(test_class.fetch_resource).to eq("deserialized")
      expect(client).to have_received(:request).with("/api/test", http_method: :get)
    end

    it "appends a path and a query string" do
      allow(test_class).to receive(:deserialize)

      test_class.fetch_resource("sub", options: { a: 1, b: "two" })

      expect(client).to have_received(:request).with("/api/test/sub?a=1&b=two", http_method: :get)
    end

    it "returns the raw response when deserialize is false" do
      expect(test_class.fetch_resource(deserialize: false)).to eq(name: "test")
    end

    it "returns nil on 204 No Content" do
      allow(client).to receive(:request).and_return(nil)

      expect(test_class.fetch_resource).to be_nil
    end
  end

  %i[post put patch].each do |http_method|
    describe ".#{http_method}" do
      it "sends a #{http_method.upcase} with params and headers" do
        allow(client).to receive(:request).and_return(true)

        test_class.public_send(http_method, params: { a: 1 }, headers: { "X" => "y" })

        expect(client).to have_received(:request)
          .with("/api/test", http_method: http_method, body: { a: 1 }, headers: { "X" => "y" })
      end
    end
  end

  describe ".delete" do
    it "sends a DELETE" do
      allow(client).to receive(:request).and_return(true)

      test_class.delete(path: "/api/test/1", headers: { "Force" => "?1" })

      expect(client).to have_received(:request)
        .with("/api/test/1", http_method: :delete, headers: { "Force" => "?1" })
    end
  end

  describe ".head" do
    it "returns the response headers" do
      allow(client).to receive(:head).with("/api/test").and_return({ "read-only" => "true" })

      expect(test_class.head).to eq("read-only" => "true")
    end
  end

  describe ".deserialize" do
    it "instantiates the class" do
      expect(test_class.deserialize({})).to be_a(test_class)
    end
  end

  describe "without a configured client" do
    it "raises NotConfiguredError" do
      Prusalink.client = nil

      expect { test_class.fetch_resource }.to raise_error(Prusalink::Exceptions::NotConfiguredError)
    end
  end
end
