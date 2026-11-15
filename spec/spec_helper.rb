# typed: true
# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  skip "/spec/"
  skip "/vendor/"

  group "Libraries", "lib"
  group "Core", "lib/prusalink.rb"
  group "Resources", "lib/prusalink/*"

  minimum_coverage 100
end

require "prusalink"
require "vcr"
require "webmock/rspec"
require "rspec/its"
require "pry"
require "dotenv/load"
require "rspec/sorbet"

wip_count = 0
RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Each example starts without a configured client
  config.before { Prusalink.client = nil }

  # Tag an example with :wip to hit a real printer. If it also has a `vcr:` cassette, the cassette is
  # (re)recorded. Without one, requests pass through and nothing is recorded.
  config.around(:example, :wip) do |example|
    WebMock.allow_net_connect!
    if example.metadata[:vcr]
      defaults = VCR.configuration.default_cassette_options
      previous = defaults[:record]
      defaults[:record] = :all
      begin
        example.run
      ensure
        defaults[:record] = previous
      end
    else
      VCR.turned_off(ignore_cassettes: true) { example.run }
    end
  ensure
    WebMock.disable_net_connect!
    wip_count += 1
  end
  config.after(:suite) do
    warn "\n\nWarning: don't forget to remove the 'wip' tag before commiting your work" unless wip_count.zero?
  end
end

def prusalink_host
  ENV.fetch("PRUSALINK_HOST", "http://prusalink.local")
end

def prusalink_username
  ENV.fetch("PRUSALINK_USERNAME", "maker")
end

def prusalink_password
  ENV.fetch("PRUSALINK_PASSWORD", "fake_password")
end

RSpec.shared_context "with default Prusalink config" do
  let(:host)     { prusalink_host }
  let(:username) { prusalink_username }
  let(:password) { prusalink_password }
end

VCR.configure do |config|
  config.cassette_library_dir = "spec/cassettes"
  config.hook_into :webmock
  config.ignore_localhost = false
  config.configure_rspec_metadata!
  config.default_cassette_options = { record: :none, record_on_error: false }

  config.filter_sensitive_data("<HOST>")     { prusalink_host }
  config.filter_sensitive_data("<PASSWORD>") { prusalink_password }
  config.filter_sensitive_data("<USERNAME>") { prusalink_username }

  # The serial number identifies the printer, so it never reaches a cassette
  config.before_record do |interaction|
    interaction.response.body = interaction.response.body.gsub(/("serial"\s*:\s*)"[^"]*"/, '\1"<SERIAL>"')
  end

  # A Digest response hash, next to the nonce, realm and username it was computed from, is enough to brute-force
  # the password offline. Replays match on the method and URI only, so the hash isn't needed.
  config.before_record do |interaction|
    authorization = interaction.request.headers["Authorization"]
    next unless authorization

    interaction.request.headers["Authorization"] = authorization.map do |value|
      value.gsub(/response="[^"]*"/, 'response="<DIGEST>"')
    end
  end

  # Requests made inside `unrecorded { ... }` reach the printer but stay out of the cassette
  config.ignore_request { Thread.current[:prusalink_unrecorded] == true }
end

# VCR only honors `record_on_error: false` inside `VCR.use_cassette` blocks, not with `vcr:` metadata. Flag the
# cassette as failed so a failing example doesn't save a half-recorded cassette. This hook is declared after
# `configure_rspec_metadata!`, and RSpec runs `after` hooks in reverse order, so it runs before VCR ejects the cassette.
RSpec.configure do |config|
  config.after do |example|
    VCR.current_cassette&.run_failed! if example.exception
  end
end

# Whether the current example is recording its cassette (tagged :wip) rather than replaying it
def recording_cassette?
  VCR.current_cassette&.recording? == true
end

# Talks to the real printer with a client of its own, without recording anything. Used for the safety checks and
# the cleanup around examples that change the printer's state, so they also run when the example fails.
def unrecorded(&)
  client = Prusalink::Client.new(host: prusalink_host, username: prusalink_username, password: prusalink_password)
  Thread.current[:prusalink_unrecorded] = true
  client.use(&)
ensure
  Thread.current[:prusalink_unrecorded] = false
end

# Configures the gem with the test printer before each example of the group
def use_prusalink_server
  before do
    Prusalink.configure(host: prusalink_host, username: prusalink_username, password: prusalink_password)
  end
end

# Configures the gem with a client that sends an API key, so WebMock stubs don't need a Digest handshake
def use_stubbed_printer
  before do
    Prusalink.configure(host: "http://printer.test", api_key: "test-key")
  end
end
