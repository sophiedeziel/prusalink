# typed: true
# frozen_string_literal: true

require "faraday"
require "net/http/digest_auth"

module Prusalink
  # Faraday middleware for HTTP Digest authentication, the scheme PrusaLink uses.
  #
  # The first request goes out unsigned. When the printer answers 401 with a Digest challenge,
  # the middleware signs the request and sends it again. It keeps the challenge, so later
  # requests are signed up front and only retry when the printer rotates its nonce.
  #
  # @example
  #   Faraday.new("http://prusa-mk4.local") do |f|
  #     f.use Prusalink::DigestAuth, "maker", "password"
  #   end
  class DigestAuth < Faraday::Middleware
    extend T::Sig

    sig { params(app: T.untyped, username: String, password: String).void }
    def initialize(app, username, password)
      super(app)
      @username  = username
      @password  = password
      @digest    = Net::HTTP::DigestAuth.new
      @challenge = T.let(nil, T.nilable(String))
      @mutex     = Mutex.new
    end

    def call(env)
      request_body = env.body
      preflight(env) if request_body.respond_to?(:read) && @challenge.nil?
      sign(env)

      response = @app.call(env)
      return response unless challenged?(response)

      # The previous response replaced env.body, put the request body back before retrying
      env.body = request_body
      request_body.rewind if request_body.respond_to?(:rewind)
      @mutex.synchronize { @challenge = response.headers["www-authenticate"] }
      sign(env)

      @app.call(env)
    end

    private

    # Streams (file uploads) would be sent twice if the first attempt bounced off the challenge.
    # A bodyless HEAD to the same URL fetches the challenge first, so the upload is signed up front.
    def preflight(env)
      head = env.dup
      head.method = :head
      head.body = nil
      head.request_headers = Faraday::Utils::Headers.new(env.request_headers)
      head.request_headers.delete("Content-Length")
      head.request_headers.delete("Content-Type")

      response = @app.call(head)
      @mutex.synchronize { @challenge = response.headers["www-authenticate"] } if challenged?(response)
    end

    def challenged?(response)
      response.status == 401 && response.headers["www-authenticate"].to_s.start_with?("Digest")
    end

    def sign(env)
      @mutex.synchronize do
        next if @challenge.nil?

        uri          = URI(env.url.to_s)
        uri.user     = CGI.escape(@username)
        uri.password = CGI.escape(@password)

        env.request_headers["Authorization"] = @digest.auth_header(uri, @challenge, env.method.to_s.upcase)
      end
    end
  end
end
