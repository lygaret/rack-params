module Rack
  module Params

    # mixin for frameworks that have a {#request} method in scope
    # make sure you `include Rack::Params` before including
    # @!attribute [r] params
    #   @return [Result] the validated params, including errors
    module Connector
      def self.included(base)
        base.class_eval do
          attr_reader :params
        end
      end

      # validates {Rack::Request#params} against a validator.
      # @overload validate(name, options = {})
      #   @param [Symbol] name the name of a registered validator.
      #   @param [Hash] options
      #   @return [Result] a result hash containing the extracted keys, and any errors.
      #   @raise [ParameterValidationError] if the parameters are invalid after validation and coercion 
      # @overload validate(options = {}, &block)
      #   validates the given parameters against the given block
      #   @param [Hash] options
      #   @yield a code block that will run in the context of a {Rack::Params::HashContext} to validate the params
      #   @return [Result] a result hash containing the extracted keys, and any errors.
      #   @raise [ParameterValidationError] if the parameters are invalid after validation and coercion 
      def validate(name = nil, params = nil, **options, &block)
        super(name, params || request.params, **options, &block)
      end

      # validates {Rack::Request#params} against a validator, raising on errors.
      # @overload validate!(name, options = {})
      #   @param [Symbol] name the name of a registered validator.
      #   @param [Hash] options
      #   @return [Result] a valid result hash containing the extracted keys, and no errors.
      #   @raise [ParameterValidationError] if the parameters are invalid after validation and coercion 
      # @overload validate!(options = {}, &block)
      #   validates the given parameters against the given block
      #   @param [Hash] options
      #   @yield a code block that will run in the context of a {Rack::Params::HashContext} to validate the params
      #   @return [Result] a valid result hash containing the extracted keys, and no errors.
      #   @raise [ParameterValidationError] if the parameters are invalid after validation and coercion 
      def validate!(name = nil, params = nil, **options, &block)
        super(name, params || request.params, **options, &block)
      end
    end
    
  end
end
