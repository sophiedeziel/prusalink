# typed: true
# frozen_string_literal: true

module Prusalink
  class Status
    # Telemetry about the current job. All values are optional.
    # See {Prusalink::Job} for the full job details.
    #
    # @example
    #   job = Prusalink::Status.get.job
    #   job.progress       # => 42.0
    #   job.time_remaining # => 520
    class Job
      extend T::Sig
      include AutoInitializable
      include Deserializable

      # @!attribute [r] id
      #   @return [Integer] The job's id
      auto_attr :id, type: Integer

      # @!attribute [r] progress
      #   @return [Float] Job progress, in percent
      auto_attr :progress, type: Float

      # @!attribute [r] time_remaining
      #   @return [Integer] Estimated time remaining, in seconds
      auto_attr :time_remaining, type: Integer

      # @!attribute [r] time_printing
      #   @return [Integer] Time spent printing, in seconds
      auto_attr :time_printing, type: Integer

      # @!attribute [r] extra
      #   @return [Hash] Any additional fields returned by the API
      auto_attr :extra, type: Hash

      auto_initialize!
    end
  end
end
