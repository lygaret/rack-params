require 'rack/params/validator'

module Rack
  module Params
    class Context

      # the DSL for validating an array parameter
      class ArrayContext < Context
        Result = ::Array

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
        def every(type, **options, &block)
          options[:required] = true unless options.key?(:required)

          params.each_with_index do |value, i|
            begin
              value = _coerce(value, type, options)
              value = _yield(i.to_s, value, type, options, &block) unless block.nil?

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
end
