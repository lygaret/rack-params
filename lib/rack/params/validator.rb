require 'date'

module Rack
  module Params

    # a bunch of helpers for coercion and validation of parameter values
    module Validator

      # An object is blank if it's false, empty, or a whitespace string.
      # For example, false, '', ' ', nil, [], and {} are all blank.
      # #hattip rails' Object#blank?
      # @param [Any] value to check
      # @return true if blank, false otherwise
      def _blank?(value)
        value.respond_to?(:empty?) ? !!value.empty? : !value
      end
      
      # return a correctly typed value, given a string and a type.
      #
      # == valid types
      # :boolean    :: parse the following strings: "0, 1, false, f, true, t, no, n, yes, y"
      # :symbol     :: parse as a symbol, (#to_sym)
      # String      :: parse as a String, (#to_s)
      # Int         :: parse an an int, with an optional base (from options)
      # Float       :: parse as the given type
      # #parse      :: parse with a parse method on type (Date, Time, etc.)
      # Array, Hash :: Rack::QueryParser already converts these, so return them directly
      #
      # @param value   to coerce, likely a string, hash or array
      # @param type    to coerce into
      # @param options to control coercion
      # @option options :base [Number] the base to parse into for Integer
      # @return value the coerced value
      # @raise [ArgumentError] if coercion fails
      # @raise [RuntimeError]  if unsupported type given
      def _coerce(value, type, options = {})
        return nil if value.nil?
        return value if value.is_a?(type) rescue false

        return value.to_s if type == ::String
        return value.to_sym if type == :symbol

        return Integer(value, options[:base] || 0) if type == ::Integer
        return Float(value)                        if type == ::Float

        if type.respond_to?(:parse)
          return type.parse(value)
        end

        if type == ::TrueClass || type == ::FalseClass || type == :boolean
          return false if /^(false|f|no|n|0)$/i === value
          return true  if /^(true|t|yes|y|1)$/i === value
          raise ArgumentError, "couldn't parse as boolean" # otherwise
        end

        # default failure
        fail "unknown type #{type}"
      end

      # todo: figure this out
      # def _validate(key, value, validation, options)
      #   options = {} if options == true
      # end

      # ensures value, checking for nils and blank values
      # @see #_blank?
      # @param value to check
      # @param [Hash] options
      # @option options :allow_nil [Boolean] if value is nil, return it?
      # @option options :allow_blank [Boolean] if value is blank, return it?
      # @raise [ArgumentError] when a value is required but not present
      # @return the value, conforming to the options given
      def _ensure(value, options = {})
        # allow nil has to precede allow blank, as nil is blank
        if options[:allow_nil] && value.nil?
          return value
        end

        if !options[:allow_blank] && _blank?(value)
          fail ArgumentError, "is required."
        end

        value
      end

      # yields the value to the block, with required semantics
      # @param value to yield to the block
      # @option options :required [Boolean] ensure value returned from block exists
      # @option options :allow_nil [Boolean] if :required, allow nils
      # @option options :allow_blank [Boolean] if :required, allow blank
      # @return value after transformation
      # @see _ensure
      def _yield(value, **options, &block)
        fail "no block provided" if block.nil?

        value = block.call(value)
        return options[:required] ? _ensure(value, options) : value
      end

    end

  end
end
