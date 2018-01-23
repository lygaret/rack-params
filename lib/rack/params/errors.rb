module Rack
  module Params

    class ParameterValidationError < StandardError
      attr_accessor :errors

      def initialize(errors)
        super("parameter validation failed, [#{errors.keys.join(', ')}] invalid.")
        @errors = errors
      end
    end

    class InvalidParameterError < StandardError
      attr_accessor :name, :type, :options
    end

  end
end
