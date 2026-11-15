# typed: true
# frozen_string_literal: true

RSpec.describe Prusalink::Client do
  subject(:client) { described_class.new(host: host, api_key: "test-key") }

  let(:host) { "http://printer.test" }
  let(:json_headers) { { "Content-Type" => "application/json" } }

  describe "#initialize" do
    it "requires a host" do
      expect { described_class.new(host: nil, password: "secret") }
        .to raise_error(Prusalink::Exceptions::MissingCredentialsError)
    end

    it "requires a password or an API key" do
      expect { described_class.new(host: host) }.to raise_error(Prusalink::Exceptions::MissingCredentialsError)
    end

    it "uses PrusaLink's defaults" do
      client = described_class.new(host: host, password: "secret")

      expect(client).to have_attributes(username: "maker", open_timeout: 3, timeout: 10)
    end
  end

  describe "#request" do
    it "parses JSON and symbolizes and underscores keys deeply" do
      stub_request(:get, "#{host}/api/version")
        .to_return(status: 200, headers: json_headers,
                   body: { api: "2.0.0", capabilities: { "upload-by-put": true }, list: [{ "fooBar" => 1 }] }.to_json)

      expect(client.request("/api/version")).to eq(api: "2.0.0", capabilities: { upload_by_put: true },
                                                   list: [{ foo_bar: 1 }])
    end

    it "sends the API key and asks for JSON" do
      stub_request(:get, "#{host}/api/v1/info").to_return(status: 200, body: "{}")

      client.request("/api/v1/info")

      expect(a_request(:get, "#{host}/api/v1/info")
        .with(headers: { "X-Api-Key" => "test-key", "Accept" => "application/json" })).to have_been_made
    end

    it "returns nil when a GET has no content" do
      stub_request(:get, "#{host}/api/v1/job").to_return(status: 204)

      expect(client.request("/api/v1/job")).to be_nil
    end

    it "returns true when another method has no content" do
      stub_request(:put, "#{host}/api/v1/job/1/pause").to_return(status: 204)

      expect(client.request("/api/v1/job/1/pause", http_method: :put)).to be true
    end

    it "returns true when the body is empty" do
      stub_request(:put, "#{host}/api/v1/files/usb/a.gcode").to_return(status: 201, body: "")

      expect(client.request("/api/v1/files/usb/a.gcode", http_method: :put, body: "G28")).to be true
    end

    it "sends a Hash body as JSON" do
      stub_request(:post, "#{host}/api/test").to_return(status: 204)

      client.request("/api/test", http_method: :post, body: { command: "go" })

      expect(a_request(:post, "#{host}/api/test")
        .with(body: '{"command":"go"}', headers: { "Content-Type" => "application/json" })).to have_been_made
    end

    it "sends a String body as-is with the given headers" do
      stub_request(:put, "#{host}/api/test").to_return(status: 201)

      client.request("/api/test", http_method: :put, body: "G28", headers: { "Overwrite" => "?1" })

      expect(a_request(:put, "#{host}/api/test").with(body: "G28", headers: { "Overwrite" => "?1" }))
        .to have_been_made
    end

    {
      400 => Prusalink::Exceptions::BadRequestError,
      401 => Prusalink::Exceptions::AuthenticationError,
      403 => Prusalink::Exceptions::AuthenticationError,
      404 => Prusalink::Exceptions::NotFoundError,
      409 => Prusalink::Exceptions::ConflictError,
      415 => Prusalink::Exceptions::UnsupportedMediaTypeError,
      500 => Prusalink::Exceptions::InternalServerError,
      501 => Prusalink::Exceptions::NotImplementedError,
      503 => Prusalink::Exceptions::ServiceUnavailableError,
      418 => Prusalink::Exceptions::UnknownError
    }.each do |status, error_class|
      it "raises #{error_class} on #{status}" do
        stub_request(:get, "#{host}/api/test").to_return(status: status, body: "nope")

        expect { client.request("/api/test") }.to raise_error(error_class, "[#{status}] nope")
      end
    end

    it "uses the title and text of a JSON error" do
      stub_request(:get, "#{host}/api/test")
        .to_return(status: 409, headers: json_headers, body: { title: "Conflict", text: "Printer is busy" }.to_json)

      expect { client.request("/api/test") }
        .to raise_error(Prusalink::Exceptions::ConflictError, "[409] Conflict: Printer is busy")
    end

    it "falls back to the raw body when a JSON error has no title or text" do
      stub_request(:get, "#{host}/api/test").to_return(status: 409, body: '{"code":"1"}')

      expect { client.request("/api/test") }
        .to raise_error(Prusalink::Exceptions::ConflictError, '[409] {"code":"1"}')
    end

    it "falls back to the raw body when a JSON error isn't an object" do
      stub_request(:get, "#{host}/api/test").to_return(status: 409, body: '"busy"')

      expect { client.request("/api/test") }.to raise_error(Prusalink::Exceptions::ConflictError, '[409] "busy"')
    end

    it "raises TimeoutError on read timeouts" do
      stub_request(:get, "#{host}/api/test").to_timeout

      expect { client.request("/api/test") }.to raise_error(Prusalink::Exceptions::TimeoutError)
    end

    it "raises TimeoutError when Faraday reports a timeout" do
      stub_request(:get, "#{host}/api/test").to_raise(Faraday::TimeoutError)

      expect { client.request("/api/test") }.to raise_error(Prusalink::Exceptions::TimeoutError)
    end

    it "raises TimeoutError on open timeouts" do
      stub_request(:get, "#{host}/api/test").to_raise(Net::OpenTimeout)

      expect { client.request("/api/test") }.to raise_error(Prusalink::Exceptions::TimeoutError)
    end

    it "raises ConnectionError when the printer can't be reached" do
      stub_request(:get, "#{host}/api/test").to_raise(Errno::ECONNREFUSED)

      expect { client.request("/api/test") }.to raise_error(Prusalink::Exceptions::ConnectionError)
    end

    it "raises InvalidResponseError with the body when the JSON is invalid" do
      # What XL firmware answers for a job whose file was deleted
      body = '{"id":225,"state":"PAUSED","file":{"name":"PRUSAL~1.GCO","path":"/usb",}}'
      stub_request(:get, "#{host}/api/v1/job").to_return(status: 200, headers: json_headers, body: body)

      expect { client.request("/api/v1/job") }
        .to raise_error(Prusalink::Exceptions::InvalidResponseError, %r{invalid JSON.*"path":"/usb",\}\}})
    end
  end

  describe "#head" do
    it "returns the headers with lowercase names" do
      stub_request(:head, "#{host}/api/v1/files/usb/a.gcode")
        .to_return(status: 200, headers: { "Read-Only" => "false", "Currently-Printed" => "true" })

      expect(client.head("/api/v1/files/usb/a.gcode")).to include("read-only" => "false", "currently-printed" => "true")
    end

    it "raises on errors" do
      stub_request(:head, "#{host}/api/v1/files/usb/a.gcode").to_return(status: 404)

      expect { client.head("/api/v1/files/usb/a.gcode") }.to raise_error(Prusalink::Exceptions::NotFoundError)
    end
  end

  describe "#use" do
    it "uses the client inside the block and restores the previous one" do
      previous = described_class.new(host: "http://other.test", api_key: "other")
      Prusalink.client = previous

      inside = client.use { Prusalink.client }

      expect(inside).to be(client)
      expect(Prusalink.client).to be(previous)
    end

    it "restores the previous client when the block raises" do
      expect { client.use { raise "boom" } }.to raise_error("boom")
      expect(Prusalink.client).to be_nil
    end
  end

  describe "Digest authentication" do
    subject(:client) { described_class.new(host: host, password: "secret") }

    it "doesn't send the API key header" do
      stub_request(:get, "#{host}/api/version").to_return(status: 200, body: "{}")

      client.request("/api/version")

      expect(a_request(:get, "#{host}/api/version").with { |req| !req.headers.key?("X-Api-Key") }).to have_been_made
    end
  end
end
