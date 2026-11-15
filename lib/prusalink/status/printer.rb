# typed: true
# frozen_string_literal: true

module Prusalink
  class Status
    # Telemetry about the printer. All values except {#state} are optional.
    #
    # @example
    #   printer = Prusalink::Status.get.printer
    #   printer.state      # => "PRINTING"
    #   printer.printing?  # => true
    #   printer.temp_bed   # => 59.5
    class Printer
      extend T::Sig
      include AutoInitializable
      include Deserializable

      # @!attribute [r] state
      #   @return [String] The printer's state: "IDLE", "BUSY", "PRINTING", "PAUSED", "FINISHED", "STOPPED",
      #     "ERROR", "ATTENTION" or "READY"
      auto_attr :state, type: String

      # @!attribute [r] temp_nozzle
      #   @return [Float] Current nozzle temperature, in °C
      auto_attr :temp_nozzle, type: Float

      # @!attribute [r] target_nozzle
      #   @return [Float] Target nozzle temperature, in °C
      auto_attr :target_nozzle, type: Float

      # @!attribute [r] temp_bed
      #   @return [Float] Current bed temperature, in °C
      auto_attr :temp_bed, type: Float

      # @!attribute [r] target_bed
      #   @return [Float] Target bed temperature, in °C
      auto_attr :target_bed, type: Float

      # @!attribute [r] axis_x
      #   @return [Float, nil] X axis position, in mm. Only available when the printer is not moving
      auto_attr :axis_x, type: Float

      # @!attribute [r] axis_y
      #   @return [Float, nil] Y axis position, in mm. Only available when the printer is not moving
      auto_attr :axis_y, type: Float

      # @!attribute [r] axis_z
      #   @return [Float] Z axis position, in mm
      auto_attr :axis_z, type: Float

      # @!attribute [r] flow
      #   @return [Integer] Flow rate factor, in percent
      auto_attr :flow, type: Integer

      # @!attribute [r] speed
      #   @return [Integer] Print speed factor, in percent
      auto_attr :speed, type: Integer

      # @!attribute [r] fan_hotend
      #   @return [Integer] Hotend fan speed, in RPM
      auto_attr :fan_hotend, type: Integer

      # @!attribute [r] fan_print
      #   @return [Integer] Print fan speed, in RPM
      auto_attr :fan_print, type: Integer

      # @!attribute [r] status_printer
      #   @return [Hash] Printer health, e.g. { ok: true, message: "OK" }
      auto_attr :status_printer, type: Hash

      # @!attribute [r] status_connect
      #   @return [Hash] Prusa Connect health, e.g. { ok: true, message: "OK" }
      auto_attr :status_connect, type: Hash

      # @!attribute [r] extra
      #   @return [Hash] Any additional fields returned by the API
      auto_attr :extra, type: Hash

      auto_initialize!

      # @return [Boolean] true when the state is "IDLE"
      sig { returns(T::Boolean) }
      def idle?
        state == "IDLE"
      end

      # @return [Boolean] true when the state is "BUSY"
      sig { returns(T::Boolean) }
      def busy?
        state == "BUSY"
      end

      # @return [Boolean] true when the state is "PRINTING"
      sig { returns(T::Boolean) }
      def printing?
        state == "PRINTING"
      end

      # @return [Boolean] true when the state is "PAUSED"
      sig { returns(T::Boolean) }
      def paused?
        state == "PAUSED"
      end

      # @return [Boolean] true when the state is "FINISHED"
      sig { returns(T::Boolean) }
      def finished?
        state == "FINISHED"
      end

      # @return [Boolean] true when the state is "STOPPED"
      sig { returns(T::Boolean) }
      def stopped?
        state == "STOPPED"
      end

      # @return [Boolean] true when the state is "ERROR"
      sig { returns(T::Boolean) }
      def error?
        state == "ERROR"
      end

      # @return [Boolean] true when the state is "ATTENTION" (the printer waits for user input)
      sig { returns(T::Boolean) }
      def attention?
        state == "ATTENTION"
      end

      # @return [Boolean] true when the state is "READY"
      sig { returns(T::Boolean) }
      def ready?
        state == "READY"
      end
    end
  end
end
