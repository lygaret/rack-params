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
      # Array     :: parse value as an array. default options { sep: ' ' }
      # Hash      :: parse value as a Hash, default options { esep: ',', fsep: ':' }
      #
      # @param value the value to coerce, likely a string, hash or array
      # @param type the type to coerce into
      # @param options [Hash]
      # @return value the coerced value
      # @raise [ArgumentError] if coercion fails
      def _coerce(value, type, options)
        return nil   if value.nil?
        return value if value.is_a?(type) rescue false

        return value.to_sym if type == :symbol || type == Symbol

        return Integer(value, options[:base] || 0) if type == ::Integer
        return Float(value)                        if type == ::Float

        [::Date, ::Time, ::DateTime].each do |klass|
          return klass.parse(value) if type == klass
        end

        if type == ::Array
          sep    = options.fetch(:sep, ',')

          values = value.split(sep)
          return Array(values)
        end

        if type == ::Hash
          esep   = options.fetch(:esep, ',')
          fsep   = options.fetch(:fsep, ':')

          values = value.split(esep).map { |p| p.split(fsep) }
          return ::Hash[values]
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

      # recursively process parameters, so we can support validating nested
      # parameter hashes and arrays.
      #
      # @param path [String] the current path to the recursing object, used to provide error keys
      # @param type must be {Array} or {Hash}
      # @return [Result] with validation results and errors
      def _recurse(path, type, value, &block)
        path = [@path, path].reject(&:nil?).join(".")

        if type == Array
          ArrayContext.new(value, path: path).exec(&block)
        elsif type == Hash
          HashContext.new(value, path: path).exec(&block)
        else
          fail "can not recurse into #{type}"
        end
      end
    end

    # the DSL for validating a hash parameter (including the top-level params hash)
    class HashContext < Context
      Result = Hash

      # do type coercion and validation for a parameter with the given key.
      # adds the coerced value to the result hash, or push an error.
      #
      # @see #_coerce #_coerce defines valid types for coercion.
      # @param key the key in the hash of the parameter to validate
      # @param type the type to coerce the value into
      # @param options [Hash]
      # @yield
      #   if type is {Hash} or {Array}, passing a block will recursively
      #   validate the coerced value, assuming the block is a new validation
      #   context.
      # @return the coerced value
      def param(key, type, options = {}, &block)
        key = key.to_s

        # default and required
        value = params[key] || options[:default]
        raise ArgumentError, "is required" if options[:required] && value.nil?

        # type cast
        value = _coerce(value, type, options)

        # validate against rules
        # options.each { |v, vopts| _validate(key, value, v, vopts) }

        # recurse if we've got a block
        if block_given?
          value = _recurse(key, type, value, &block)
          result.errors.merge! value.errors
        end

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
            value = _coerce(value, type, options)
            # options.each { |v, vopts| _validate(i.to_s, value, v, vopts) }
            if block_given?
              value = _recurse(i.to_s, type, value, &block)
              result.errors.merge! value.errors
            end

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
