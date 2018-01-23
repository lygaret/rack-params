require 'date'

module Rack
  module Params

    class Context
      attr_reader :options
      attr_reader :params
      attr_reader :result

      def initialize(params, options = {})
        @options = options
        @path    = options[:path]

        @params  = params

        @result = self.class::Result.new
        @result.extend ::Rack::Params::Result
        @result.errors = Hash.new { |h, k| h[k] = [] }
      end

      def exec(&block)
        instance_exec(&block)
        @result
      end

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
      rescue ArgumentError => ex
        fail InvalidParameterError, ex.message
      end

      def _validate(name, value, validation, options)
        options = {} if options == true
        # what to do...
      end

      def _recurse(name, type, value, &block)
        path = [@path, name].reject(&:nil?).join(".")

        if type == Array
          ArrayContext.new(value, path: path).exec(&block)
        elsif type == Hash
          HashContext.new(value, path: path).exec(&block)
        else
          fail "can not recurse into #{type}"
        end
      end
    end

    # the DSL when validating a hash parameter (including the top-level params hash)

    class HashContext < Context
      Result = Hash

      def param(name, type, options = {}, &block)
        name = name.to_s

        # default and required
        value = params[name] || options[:default]
        raise InvalidParameterError, "is required" if options[:required] && value.nil?

        # type cast
        value = _coerce(value, type, options)

        # validate against rules
        options.each { |v, vopts| _validate(name, value, v, vopts) }

        # recurse if we've got a block
        if block_given?
          value = _recurse(name, type, value, &block)
          result.errors.merge! value.errors
        end

        # return - we're good
        result[name] = value
      rescue InvalidParameterError => ex
        path = [@path, name].reject(&:nil?).join(".")
        result.errors[path] << ex.message
      end

      def splat(name, options = {}, &block)
        name = name.to_s

        # every key in params that's not already in results
        value = params.reject { |k, _| result.keys.include? k }
        result[name] = value
      end
    end

    # the DSL when validating an array parameter
    class ArrayContext < Context
      Result = Array

      # validate and coerce every element in the array to the type/options/block given
      def every(type, options = {}, &block)
        params.each_with_index do |value, i|
          begin
            value = _coerce(value, type, options)
            options.each { |v, vopts| _validate(i.to_s, value, v, vopts) }
            if block_given?
              value = _recurse(i.to_s, type, value, &block)
              result.errors.merge! value.errors
            end

            result[i] = value
          rescue InvalidParameterError => ex
            path = [@path, i].reject(&:nil?).join(".")
            result.errors[path] << ex.message
          end
        end
      end

    end
  end
end
