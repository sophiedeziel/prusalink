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

  # Tag an example with :wip to hit a real printer (and record its cassette)
  config.around(:example, :wip) do |example|
    WebMock.allow_net_connect!
    VCR.turned_off(ignore_cassettes: true) { example.run }
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
