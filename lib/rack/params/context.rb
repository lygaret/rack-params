require 'date'

module Rack
  module Params

    # the context in which to run validation.
    # it contains the {#params} and {#result}, and provides methods to use in coercion.
    # @abstract To subclass, provide a {Result} constant, and methods to do coercion/validation.
    class Context
      attr_reader :options
      attr_reader :params
      attr_reader :result

      # the structure of the result - eg. {} or [].
      # the actual {#result} will be this type extended by {Rack::Params::Result}
      Result = nil

      # create a context with a parameter hash and options.
      def initialize(params, options = {})
        @options = options
        @path    = options[:path]

        @params  = params

        @result = self.class::Result.new
        @result.extend ::Rack::Params::Result
        @result.errors = Hash.new { |h, k| h[k] = [] }
      end

      # execute the given block, in this context
      # @yield in the block, {self}'s methods are available.
      # @return [Result] the result of this context's validation.
      def exec(&block)
        instance_exec(&block)
        @result
      end

      protected

      # return a correctly typed value, given a string and a type.
      #
      # == valid types
      # :symbol   :: convert value as a symbol
      # :boolean  :: parse the following strings: "0, 1, false, f, true, t, no, n, yes, y"
      # Symbol    ::
      # Int       ::
      # Float     ::
      # Date      ::
      # Time      ::
      # DateTime  :: parse as the given type.
      # Array     :: parse value as an Array, will recurse into the value and validate with {ArrayContext}
      # Hash      :: parse value as a Hash, will recurse into the value and validate with {HashContext}
      #
      # @param key the name of the param
      # @param value the value to coerce, likely a string, hash or array
      # @param type the type to coerce into
      # @param options [Hash]
      # @return value the coerced value
      # @raise [ArgumentError] if coercion fails
      def _coerce(key, value, type, options, &block)
        return nil   if value.nil?

        # Rack::QueryParser already takes these from strings to structured types
        # so if we're not transforming them, just pass them along.
        if type == ::Array || type == ::Hash
          return value if block.nil?

          path   = [@path, key].reject(&:nil?).join(".")
          values = if type == ::Array
                     ArrayContext.new(value, path: path, errors: result.errors).exec(&block)
                   elsif type == ::Hash
                     HashContext.new(value, path: path, errors: result.errors).exec(&block)
                   end

          # these are special, include the error messages
          # ps, pretty sure this would be better structured as an explicit writer monad, but whatever
          result.errors.merge! values.errors
          return values
        end

        return value if value.is_a?(type) rescue false
        return value.to_sym if type == :symbol || type == Symbol

        return Integer(value, options[:base] || 0) if type == ::Integer
        return Float(value)                        if type == ::Float

        [::Date, ::Time, ::DateTime].each do |klass|
          return klass.parse(value) if type == klass
        end

        if type == ::TrueClass || type == ::FalseClass || type == :boolean
          return false if /^(false|f|no|n|0)$/i === value
          return true  if /^(true|t|yes|y|1)$/i === value
          raise ArgumentError # otherwise
        end

        # default failure
        raise ArgumentError, "unknown type #{type}"
      end

      # todo: figure this out
      # def _validate(key, value, validation, options)
      #   options = {} if options == true
      # end
    end

    # the DSL for validating a hash parameter (including the top-level params hash)
    class HashContext < Context
      Result = Hash

      # do type coercion and validation for a parameter with the given key.
      # adds the coerced value to the result hash, or push an error.
      #
      # @param [String] key the key in the parameter hash
      # @param [Hash] options
      # @option options [Boolean] :required boolean will fail if key is missing from params
      # @option options [Any]     :default the value to return if the param is missing
      # @option options [Boolean] :allow_nil   is nil considered present?, defaults to false, considered missing.
      # @option options [Boolean] :allow_blank is blank (0-length string, or nil) considered present?, defaults to false, considered missing.
      # @return the coerced value
      #
      # @overload param(key, options = {}, &block)
      #   coerces the value through the block given, marking invalid on falsey and raised errors.
      #   (use the `allow_nil` and `allow_falsey` options to change the validity behavoir)
      #   @option options [Boolean] :allow_falsey is falsey considered present?, defaults to false, considered missing.
      #   @yield to the transformation function, failure on nil or ArgumentError (unless `:allow_nil`)
      #   @yieldparam [String|nil] value from the param hash to validate/coerce
      #   @yieldreturn the value that's been validated/coerced
      #
      # @overload param(key, type = Hash | Array, options = {}, &block)
      #   recursively validates the value through the block given, which
      #   is run in the context of a suitable validation context.
      #   @yield
      #     if type is {Hash} or {Array}, passing a block will recursively
      #     validate the coerced value, assuming the block is a new validation
      #     context. if type is not {Hash} or {Array}, raises `ArgumentError`
      #
      # @overload param(key, type, options = {})
      #   coerces the value as defined by the given type.
      #   @see #_coerce #_coerce defines valid types for coercion.
      def param(key, type = nil, options = nil, &block)
        key = key.to_s

        # swap type/options if no type parameter
        if (type.is_a?(Hash) && options.nil?)
          options = type
          type    = nil
        end

        # options has to default to nil (to support optional type)
        # but we want to access it without caring
        options ||= {}

        # check that the block makes sense
        unless block.nil? || [Hash, Array, nil].include?(type)
          fail "cannot recurse into #{type}"
        end
        if type == nil && block.nil?
          fail "block must be passed with no type"
        end

        # default and required
        value = params[key] || options[:default]
        raise ArgumentError, "is required" if options[:required] && value.nil?

        # type cast
        if type == nil
          value = value.nil? ? nil : block.call(value, key, options)
        else
          value = _coerce(key, value, type, options, &block)
        end

        # validate against rules
        # options.each { |v, vopts| _validate(key, value, v, vopts) }

        # return - we're good
        result[key] = value
      rescue ArgumentError => ex
        path = [@path, key].reject(&:nil?).join(".")
        result.errors[path] << ex.message
        nil
      end

      # collect uncoerced keys from the parameter hash into the results hash.
      # collects keys not _yet_ coerced, so it should be last in the validation block.
      #
      # @param key the result key under which to place the collected parameters
      # @param options [Hash]
      # @return the collected keys as a hash
      def splat(key, options = {})
        key = key.to_s

        # every key in params that's not already in results
        value = params.reject { |k, _| result.keys.include? k }
        result[key] = value
      end
    end

    # the DSL for validating an array parameter
    class ArrayContext < Context
      Result = Array

      # validate and coerce every element in the array, using the same values.
      # equivalent to {HashContext#param} over every element.
      #
      # @see HashContext#param
      # @see #_coerce #_coerce defines valid types for coercion.
      # @param type the type to use for coercion
      # @param options [Hash]
      # @yield
      #   if type is Hash or Array, passing a block will recursively
      #   validate the coerced value, assuming the block is a new validation
      #   context.
      # @return the coerced value
      def every(type, options = {}, &block)
        params.each_with_index do |value, i|
          begin
            value = _coerce(i.to_s, value, type, options, &block)
            # options.each { |v, vopts| _validate(i.to_s, value, v, vopts) }
            result[i] = value
          rescue ArgumentError => ex
            path = [@path, i].reject(&:nil?).join(".")
            result.errors[path] << ex.message
            nil
          end
        end
      end

    end
  end
end
