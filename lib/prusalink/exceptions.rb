# typed: strict
# frozen_string_literal: true

module Prusalink
  # Prusalink exceptions
  module Exceptions
    # Base error.
    class Error < StandardError; end
    # The credentials were refused (HTTP 401/403)
    class AuthenticationError < Error; end
    # The request can't be processed because of invalid inputs (HTTP 400)
    class BadRequestError < Error; end
    # Credentials are missing from the configuration. Set them using `Prusalink.configure()`
    class MissingCredentialsError < Error; end
    # No client is configured for the current thread. Use `Prusalink.configure()` or `Client#use`
    class NotConfiguredError < Error; end
    # The resource doesn't exist (HTTP 404)
    class NotFoundError < Error; end
    # The printer's state doesn't allow the request, e.g. pausing an idle printer (HTTP 409)
    class ConflictError < Error; end
    # The uploaded media type isn't supported (HTTP 415)
    class UnsupportedMediaTypeError < Error; end
    # The printer encountered an unexpected condition (HTTP 500)
    class InternalServerError < Error; end
    # The printer doesn't implement this endpoint (HTTP 501)
    class NotImplementedError < Error; end
    # The printer is busy or not ready (HTTP 503)
    class ServiceUnavailableError < Error; end
    # Any other unexpected HTTP status
    class UnknownError < Error; end
    # The printer answered with a body that isn't valid JSON
    class InvalidResponseError < Error; end
    # The printer could not be reached (connection refused, host unreachable, DNS failure, ...)
    class ConnectionError < Error; end
    # The printer did not open the connection or respond within the configured timeouts
    class TimeoutError < ConnectionError; end
  end
end
