module Rack
  module Params

    # raised on {Rack::Params#validate!} failure
    class ParameterValidationError < StandardError

      # @!attribute [r] errors
      #   a hash of errors discovered during parameter coercion and validation.
      #   keys are dotted paths from the parameter hash.
      #   @return [Hash] a hash of errors
      attr_accessor :errors

      def initialize(errors)
        super("parameter validation failed, [#{errors.keys.join(', ')}] invalid.")
        @errors = errors
      end
    end

  end
end
