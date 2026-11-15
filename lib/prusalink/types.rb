# typed: true
# frozen_string_literal: true

module Prusalink
  # Common type aliases for use with auto_attr and Sorbet signatures.
  module Types
    # A hash with symbol keys and untyped values (common for API responses)
    Hash = T::Hash[Symbol, T.untyped]

    # A boolean type (true or false)
    Boolean = T.any(TrueClass, FalseClass)

    # A nullable boolean (true, false or nil)
    NilableBoolean = T.nilable(T.any(TrueClass, FalseClass))

    # A number that PrusaLink may send as an integer or a float
    Number = T.any(Integer, Float)

    # Printer states reported by /api/v1/status
    # IDLE, BUSY, PRINTING, PAUSED, FINISHED, STOPPED, ERROR, ATTENTION, READY
    PrinterState = String

    # Job states reported by /api/v1/job
    # PRINTING, PAUSED, FINISHED, STOPPED, ERROR
    JobState = String
  end
end
