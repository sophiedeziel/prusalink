# typed: true
# frozen_string_literal: true

RSpec.describe Prusalink::DigestAuth do
  let(:host)     { "http://printer.test" }
  let(:url)      { "#{host}/api/version" }
  let(:client)   { Prusalink::Client.new(host: host, password: "secret") }
  let(:realm)    { "Printer API" }

  def challenge(nonce, stale: false)
    { "WWW-Authenticate" => %(Digest realm="#{realm}", nonce="#{nonce}", stale=#{stale.to_s.upcase}) }
  end

  def expected_response(nonce, method, uri)
    ha1 = Digest::MD5.hexdigest("maker:#{realm}:secret")
    ha2 = Digest::MD5.hexdigest("#{method}:#{uri}")
    Digest::MD5.hexdigest("#{ha1}:#{nonce}:#{ha2}")
  end

  def unsigned
    ->(req) { !req.headers.key?("Authorization") }
  end

  def signed_with(nonce)
    ->(req) { req.headers["Authorization"].to_s.include?(%(nonce="#{nonce}")) }
  end

  it "answers the challenge with a valid Digest header" do
    stub_request(:get, url).with(&unsigned).to_return(status: 401, headers: challenge("abc"))
    stub_request(:get, url).with(&signed_with("abc")).to_return(status: 200, body: '{"api":"2.0.0"}')

    expect(client.request("/api/version")).to eq(api: "2.0.0")

    expect(a_request(:get, url).with do |req|
      header = req.headers["Authorization"].to_s
      header.start_with?('Digest username="maker"') &&
        header.include?(%(realm="#{realm}")) &&
        header.include?('uri="/api/version"') &&
        header.include?(%(response="#{expected_response("abc", "GET", "/api/version")}"))
    end).to have_been_made.once
  end

  it "signs later requests up front with the stored challenge" do
    stub_request(:get, url).with(&unsigned).to_return(status: 401, headers: challenge("abc"))
    stub_request(:get, url).with(&signed_with("abc")).to_return(status: 200, body: "{}")

    2.times { client.request("/api/version") }

    expect(a_request(:get, url).with(&unsigned)).to have_been_made.once
    expect(a_request(:get, url).with(&signed_with("abc"))).to have_been_made.twice
  end

  it "retries with the new challenge when the nonce goes stale" do
    stub_request(:get, url).with(&unsigned).to_return(status: 401, headers: challenge("old"))
    stale = { status: 401, headers: challenge("new", stale: true) }
    stub_request(:get, url).with(&signed_with("old")).to_return({ status: 200, body: "{}" }, stale)
    stub_request(:get, url).with(&signed_with("new")).to_return(status: 200, body: '{"ok":true}')

    client.request("/api/version")

    expect(client.request("/api/version")).to eq(ok: true)
  end

  describe "streamed uploads" do
    let(:upload) { "#{host}/api/v1/files/usb/a.gcode" }

    def upload_gcode
      client.request("/api/v1/files/usb/a.gcode", http_method: :put, body: StringIO.new("G28\n"),
                                                  headers: { "Content-Length" => "4" })
    end

    it "fetches the challenge with a HEAD first, so the file is only sent once" do
      stub_request(:head, upload).to_return(status: 401, headers: challenge("abc"))
      stub_request(:put, upload).with(&signed_with("abc")).to_return(status: 201)

      upload_gcode

      expect(a_request(:head, upload).with { |req| !req.headers.key?("Content-Length") }).to have_been_made.once
      expect(a_request(:put, upload).with(body: "G28\n")).to have_been_made.once
    end

    it "skips the HEAD when the challenge is already known" do
      stub_request(:get, url).with(&unsigned).to_return(status: 401, headers: challenge("abc"))
      stub_request(:get, url).with(&signed_with("abc")).to_return(status: 200, body: "{}")
      stub_request(:put, upload).with(&signed_with("abc")).to_return(status: 201)

      client.request("/api/version")
      upload_gcode

      expect(a_request(:head, upload)).not_to have_been_made
    end

    it "rewinds and sends the body again when the nonce went stale" do
      stub_request(:head, upload).to_return(status: 401, headers: challenge("old"))
      stub_request(:put, upload).with(&signed_with("old")).to_return(status: 401,
                                                                     headers: challenge(
                                                                       "new", stale: true
                                                                     ))
      stub_request(:put, upload).with(&signed_with("new")).to_return(status: 201)

      expect(upload_gcode).to be true
      expect(a_request(:put, upload).with(body: "G28\n")).to have_been_made.twice
    end

    it "uploads unsigned when the printer doesn't ask for authentication" do
      stub_request(:head, upload).to_return(status: 200)
      stub_request(:put, upload).with(&unsigned).to_return(status: 201)

      expect(upload_gcode).to be true
    end
  end

  it "retries only once when the credentials are wrong" do
    stub_request(:get, url).to_return(status: 401, headers: challenge("abc"), body: "Unauthorized")

    expect { client.request("/api/version") }.to raise_error(Prusalink::Exceptions::AuthenticationError)
    expect(a_request(:get, url)).to have_been_made.twice
  end

  it "doesn't retry a 401 without a Digest challenge" do
    stub_request(:get, url).to_return(status: 401, body: "Unauthorized")

    expect { client.request("/api/version") }.to raise_error(Prusalink::Exceptions::AuthenticationError)
    expect(a_request(:get, url)).to have_been_made.once
  end

  context "with a real printer and a wrong password", vcr: { cassette_name: "digest_auth/wrong_password" } do
    before { Prusalink.configure(host: prusalink_host, username: prusalink_username, password: "wrong-password") }

    it "answers the challenge once, then raises AuthenticationError" do
      expect { Prusalink::ServerVersion.get }.to raise_error(Prusalink::Exceptions::AuthenticationError)
    end
  end
end
