# typed: true
# frozen_string_literal: true

module Prusalink
  # The printer's current job.
  #
  # @example Inspect and control the current job
  #   job = Prusalink::Job.get # => nil when the printer is idle
  #   job.state           # => "PRINTING"
  #   job.progress        # => 42.0
  #   job.file.full_path  # => "/usb/SPICE~1.gco"
  #   job.pause
  #
  # @example Control a job by id
  #   Prusalink::Job.stop(420)
  class Job < BaseResource
    include AutoInitializable
    include Deserializable

    resource_path("/api/v1/job")

    # @!attribute [r] id
    #   @return [Integer] The job's id
    auto_attr :id, type: Integer

    # @!attribute [r] state
    #   @return [String] One of "PRINTING", "PAUSED", "FINISHED", "STOPPED" or "ERROR"
    auto_attr :state, type: String

    # @!attribute [r] progress
    #   @return [Float] Completion, in percent
    auto_attr :progress, type: Float

    # @!attribute [r] time_remaining
    #   @return [Integer, nil] Estimated time left, in seconds
    auto_attr :time_remaining, type: Integer

    # @!attribute [r] time_printing
    #   @return [Integer] Time spent printing, in seconds
    auto_attr :time_printing, type: Integer

    # @!attribute [r] inaccurate_estimates
    #   @return [Boolean, nil] Whether the time estimates are inaccurate
    auto_attr :inaccurate_estimates, type: T::Boolean

    # @!attribute [r] serial_print
    #   @return [Boolean, nil] Whether the printer is printing from the serial line (no file is then available)
    auto_attr :serial_print, type: T::Boolean

    # @!attribute [r] file
    #   @return [Job::File, nil] The file being printed, absent for serial prints
    auto_attr :file, type: File

    # @!attribute [r] extra
    #   @return [Hash] Any additional fields returned by the API
    auto_attr :extra, type: Hash

    auto_initialize!

    deserialize_config do
      nested :file, File
    end

    class << self
      # Retrieve the current job.
      #
      # @return [Job, nil] nil when there is no job (the printer answers 204 No Content)
      # @raise [Prusalink::Exceptions::Error] if the request fails
      #: -> Job?
      def get
        fetch_resource
      end

      # Stop the job with the given id.
      #
      # @param id [Integer] The job's id
      # @return [Boolean] true on success
      # @raise [Prusalink::Exceptions::NotFoundError] if no job has this id
      # @raise [Prusalink::Exceptions::ConflictError] if the job can't be stopped in its current state
      #: (Integer id) -> bool
      def stop(id)
        delete(path: job_path(id))
      end

      # Pause the job with the given id.
      #
      # @param id [Integer] The job's id
      # @return [Boolean] true on success
      # @raise [Prusalink::Exceptions::NotFoundError] if no job has this id
      # @raise [Prusalink::Exceptions::ConflictError] if the job can't be paused in its current state
      #: (Integer id) -> bool
      def pause(id)
        put(path: job_path(id, "pause"))
      end

      # Resume the paused job with the given id.
      #
      # @param id [Integer] The job's id
      # @return [Boolean] true on success
      # @raise [Prusalink::Exceptions::NotFoundError] if no job has this id
      # @raise [Prusalink::Exceptions::ConflictError] if the job isn't paused
      #: (Integer id) -> bool
      def resume(id)
        put(path: job_path(id, "resume"))
      end

      # Continue the job with the given id after a timelapse capture.
      #
      # @param id [Integer] The job's id
      # @return [Boolean] true on success
      # @raise [Prusalink::Exceptions::NotFoundError] if no job has this id
      # @raise [Prusalink::Exceptions::ConflictError] if the job isn't waiting to continue
      #: (Integer id) -> bool
      def continue(id)
        put(path: job_path(id, "continue"))
      end

      private

      #: (Integer id, ?String? action) -> String
      def job_path(id, action = nil)
        ["/api/v1/job", id, action].compact.join("/")
      end
    end

    # Stop this job. See {Job.stop}.
    #
    # @return [Boolean] true on success
    #: -> bool
    def stop
      self.class.stop(T.must(id))
    end

    # Pause this job. See {Job.pause}.
    #
    # @return [Boolean] true on success
    #: -> bool
    def pause
      self.class.pause(T.must(id))
    end

    # Resume this job. See {Job.resume}.
    #
    # @return [Boolean] true on success
    #: -> bool
    def resume
      self.class.resume(T.must(id))
    end

    # Continue this job after a timelapse capture. See {Job.continue}.
    #
    # @return [Boolean] true on success
    #: -> bool
    def continue
      self.class.continue(T.must(id))
    end

    # @return [Boolean] whether the job is printing
    #: -> bool
    def printing?
      state == "PRINTING"
    end

    # @return [Boolean] whether the job is paused
    #: -> bool
    def paused?
      state == "PAUSED"
    end

    # @return [Boolean] whether the job has finished
    #: -> bool
    def finished?
      state == "FINISHED"
    end

    # @return [Boolean] whether the job was stopped
    #: -> bool
    def stopped?
      state == "STOPPED"
    end

    # @return [Boolean] whether the job ended in error
    #: -> bool
    def error?
      state == "ERROR"
    end
  end
end
