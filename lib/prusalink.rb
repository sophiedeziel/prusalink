# typed: true
# frozen_string_literal: true

require "active_support/all"
require "zeitwerk"
require "sorbet-runtime"

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/tapioca")
loader.setup

# Load Tapioca compiler if available
require_relative "tapioca/dsl/compilers/auto_initializable" if defined?(Tapioca)

# Ruby client for PrusaLink, the local REST API of Prusa 3D printers.
#
# @example Configure the gem once, then call resources
#   Prusalink.configure(host: "http://prusa-mk4.local", password: "from-the-printer-screen")
#   Prusalink::Status.get.printer.state # => "PRINTING"
#
# @attr [Prusalink::Client] client      The configured API client
module Prusalink
  class << self
    extend T::Sig

    # Configure the API client with the printer's address and credentials.
    #
    # PrusaLink uses HTTP Digest authentication. The username is "maker" by default and the
    # password is shown on the printer (Settings > Network > PrusaLink). Older firmware uses an
    # API key instead: pass `api_key:` and leave the password out.
    #
    # @example Digest authentication (current firmware)
    #   Prusalink.configure(host: "http://192.168.1.42", password: "s3cr3t")
    #
    # @example API key (older firmware)
    #   Prusalink.configure(host: "http://192.168.1.42", api_key: "abcdef")
    #
    # @param [String] host                  Printer's address
    # @param [String, nil] password         PrusaLink password (Digest auth)
    # @param [String] username              PrusaLink username (Digest auth)
    # @param [String, nil] api_key          PrusaLink API key (older firmware)
    # @param [Numeric, nil] open_timeout    Seconds to wait for the connection to open
    # @param [Numeric, nil] timeout         Seconds to wait for a read or a write
    # @return [nil]
    sig do
      params(
        host: String,
        password: T.nilable(String),
        username: String,
        api_key: T.nilable(String),
        open_timeout: T.nilable(Numeric),
        timeout: T.nilable(Numeric)
      ).void
    end
    def configure(host:, password: nil, username: Client::DEFAULT_USERNAME, api_key: nil,
                  open_timeout: Client::DEFAULT_OPEN_TIMEOUT, timeout: Client::DEFAULT_TIMEOUT)
      self.client = Client.new(host: host, password: password, username: username, api_key: api_key,
                               open_timeout: open_timeout, timeout: timeout)

      nil
    end

    # The API client used for the requests in the current thread
    # @return [Client, nil]
    sig { returns(T.nilable(Client)) }
    def client
      Thread.current[:prusalink_client]
    end

    # Sets the API client used for the requests in the current thread
    # @param [Client, nil] client
    sig { params(client: T.nilable(Client)).void }
    def client=(client)
      Thread.current[:prusalink_client] = client
    end
  end
end
