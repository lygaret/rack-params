require 'rack/params/context'
require 'rack/params/errors'
require 'rack/params/result'
require 'rack/params/version'

module Rack
  module Params
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      Validator = Struct.new(:options, :code) do
        def exec(values)
          HashContext.new(values, options).exec(&code)
        end
      end

      def validators
        @_rp_validators ||= {}
      end

      def validator(name, options = {}, &code)
        validators[name] = Validator.new(options, code)
      end
    end

    # validate request.params
    def validate(name = nil, params = nil, options = {}, &block)
      if params.nil? && (name.class <= Hash)
        params = name
        name   = nil
      end

      fail ArgumentError, "no parameters provided!" if params.nil?
      if name.nil?
        fail ArgumentError, "no validation block was provided!" unless block_given?
        HashContext.new(params, options).exec(&block)
      else
        fail ArgumentError, "no validation is registered under #{name}" unless self.class.validators.key? name
        self.class.validators[name].execute(params)
      end
    end

    def validate!(name = nil, params = nil, options = {}, &block)
      validate(name, params, options, block).tap do |res|
        fail ParameterValidationError, res.errors if res.invalid?
      end
    end

    # secondary mixin for frameworks that put `request` in the scope

    module Connector
      def self.included(base)
        base.class_eval do
          attr_reader :params
        end
      end

      def validate(name = nil, params = nil, options = {}, &block)
        super(name, params || request.params, options, &block)
      end
    end
  end
end
