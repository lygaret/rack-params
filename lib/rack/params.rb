require 'rack/params/context'
require 'rack/params/errors'
require 'rack/params/result'
require 'rack/params/version'

module Rack

  # Rack::Params provides a lightweight DSL for type coercion and validation of request parameters.
  # @!parse extend Rack::Params::ClassMethods
  module Params

    # @private
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      # holds options and a block when registering a validator.
      # @private
      Validator = Struct.new(:options, :code) do
        def exec(values)
          HashContext.new(values, options).exec(&code)
        end
      end

      # get the set of validators, keyed by name
      # @private
      def validators
        @_rp_validators ||= {}
      end

      # register a Validator with the given options and block.
      # the validator can be used in #validate method by providing the name.
      def validator(name, options = {}, &code)
        validators[name] = Validator.new(options, code)
      end
    end

    # validate the given parameters
    # @overload validate(name, params, options = {})
    #   validates the given parameters against the named validator
    #   @param [Symbol] name the name of a registered validator.
    #   @param [Hash] params the parameter hash to validate
    #   @param [Hash] options
    #   @return [Result] a result hash containing the extracted keys, and errors.
    # @overload validate(params, options = {}, &block)
    #   validates the given parameters against the given block
    #   @see Rack::Params::HashContext
    #   @param [Hash] params the parameter hash to validate
    #   @param [Hash] options
    #   @yield a code block that will run in the context of a {Rack::Params::HashContext} to validate the params
    #   @return [Result] a result hash containing the extracted keys, and errors.
    def validate(name = nil, params = nil, options = {}, &block)
      if params.nil? && (name.class <= Hash)
        params = name
        name   = nil
      end

      fail "no parameters provided!" if params.nil?
      if name.nil?
        fail "no validation block was provided!" unless block_given?
        HashContext.new(params, options).exec(&block)
      else
        fail "no validation is registered under #{name}" unless self.class.validators.key? name
        self.class.validators[name].exec(params)
      end
    end

    # {include:#validate}
    # @overload validate!(name, params, options = {})
    #   @param [Symbol] name the name of a registered validator.
    #   @param [Hash] params the parameter hash to validate
    #   @param [Hash] options
    #   @return [Result] a valid result hash containing the extracted keys, and no errors.
    #   @raise [ParameterValidationError] if the parameters are invalid after validation and coercion 
    # @overload validate!(params, options = {}, &block)
    #   validates the given parameters against the given block
    #   @param [Hash] params the parameter hash to validate
    #   @param [Hash] options
    #   @yield a code block that will run in the context of a {Rack::Params::HashContext} to validate the params
    #   @return [Result] a valid result hash containing the extracted keys, and no errors.
    #   @raise [ParameterValidationError] if the parameters are invalid after validation and coercion 
    def validate!(name = nil, params = nil, options = {}, &block)
      validate(name, params, options, &block).tap do |res|
        fail ParameterValidationError, res.errors if res.invalid?
      end
    end

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
      def validate(name = nil, params = nil, options = {}, &block)
        super(name, params || request.params, options, &block)
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
      def validate!(name = nil, params = nil, options = {}, &block)
        super(name, params || request.params, options, &block)
      end
    end
  end
end
