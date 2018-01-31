require 'rack/params/validator'

module Rack
  module Params

    # the validator to run.
    # it contains the {#params} and {#result}, and provides methods to use in coercion.
    # @abstract To subclass, provide a {Result} constant, and methods to do coercion/validation.
    class Context 
      include Rack::Params::Validator

      attr_reader :options
      attr_reader :params
      attr_reader :result

      # the structure of the result - eg. {} or [].
      # the actual {#result} will be this type extended by {Rack::Params::Result}
      Result = nil

      def self.exec(params, **options, &block)
        HashContext.new(params, options).exec(&block)
      end

      # create a validator with a parameter hash and options.
      def initialize(params, options = {})
        @options = options
        @path    = options[:path]

        @params  = params

        @result = self.class::Result.new
        @result.extend ::Rack::Params::Result
        @result.errors = ::Hash.new { |h, k| h[k] = [] }
      end

      # execute the given block, in this validator
      # @yield in the block, {self}'s methods are available.
      # @return [Result] the result of validation
      def exec(&block)
        instance_exec(&block)
        @result
      end

      # yields the value to the block, according to the type.
      # @param [String] key current params path segment
      # @param value to yield to the block
      # @param type of value, special handling for recursible types (Hash | Array)
      #
      # @overload _yield(key, value, type, options = {}, &block)
      #   returns the result of yielding the value to the block
      #   @param [Hash] options, same as {#_fetch}
      #   @return [Array] tuple of result of yielding the value to the block, and errors
      #
      # @overload _yield(key, value, type = Hash | Array, options = {}, &block)
      #   recursively validates the value through the block given, which is run
      #   inside a suitable validation context; also merges result errors.
      #   @param [Hash] options, same as {#initialize}
      #   @return [Array] tuple of validated results
      def _yield(key, value, type, **options, &block)
        # simple types
        unless type == ::Array || type == ::Hash
          return super(value, **options, &block) 
        end

        # recursive types
        fail "no block provided" if block.nil?
        path   = [@path, key].reject(&:nil?).join(".")
        values =
          if type == ::Array
            Rack::Params::Context::ArrayContext.new(value, path: path).exec(&block)
          elsif type == ::Hash
            Rack::Params::Context::HashContext.new(value, path: path).exec(&block)
          else
            fail "cannot recurse into #{type}"
          end

        # this is special, we merge errors
        result.errors.merge! values.errors
        return values
      end
    end

  end
end
