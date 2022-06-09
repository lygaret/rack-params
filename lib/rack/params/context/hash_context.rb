require 'rack/params/context'

module Rack
  module Params
    class Context

      # the DSL for validating a hash parameter (including the top-level params hash)
      class HashContext < Context
        Result = ::Hash

        # return the value from the params hash, validating it's presence from options
        # @param key the name of the param to fetch
        # @param [Hash] options
        # @option options [Any]     :default     the value to return if the param is missing
        # @option options [Boolean] :required    will fail if key is missing from params
        # @option options [Boolean] :allow_nil
        #   is nil considered present? for :required?,
        #   defaults to false, considered missing.
        # @option options [Boolean] :allow_blank
        #   is blank considered present? for :required?,
        #   defaults to false, considered missing.
        # @see #_blank?
        def _fetch(key, options = {})
          value = params.key?(key) ? params[key] : options[:default]
          options[:required] ? _ensure(value, options) : value
        end

        # do type coercion and validation for a parameter with the given key.
        # adds the coerced value to the result hash, or push an error.
        #
        # @param [String] key the key in the parameter hash
        # @param [Hash] options
        # @option options [Boolean] :required    will fail if key is missing from params
        # @option options [Any]     :default     the value to return if the param is missing
        # @option options [Boolean] :allow_nil   is nil considered present?, defaults to false, considered missing.
        # @option options [Boolean] :allow_blank is blank (0-length string, or nil) considered present?, defaults to false, considered missing.
        # @return the coerced value
        #
        # @overload param(key, type = String, options = {}, &block)
        #   coerces the value through the block given, marking invalid on raised errors.
        #   if yielding to the block, the :allow_nil and :allow_blank options apply equally to the result of the block
        #   (use the `allow_nil` and `allow_falsey` options to change the validity behavoir)
        #   @option options [Boolean] :allow_falsey is falsey considered present?, defaults to false, considered missing.
        #   @yield to the transformation function, failure on nil, blank or ArgumentError (unless `:allow_nil` or `:allow_blank`)
        #   @yieldparam [String|nil] value from the param hash to validate/coerce
        #   @yieldreturn the value that's been validated/coerced
        #   @see #_coerce #_coerce defines valid types for coercion.
        #
        # @overload param(key, type = Hash | Array, options = {}, &block)
        #   recursively validates the value through the block given, which
        #   is run in the context of a suitable validation context.
        #   @yield
        #     if type is {Hash} or {Array}, passing a block will recursively
        #     validate the coerced value, assuming the block is a new validation
        #     context. if type is not {Hash} or {Array}, raises `ArgumentError`
        def param(key, type = String, **options, &block)
          key   = key.to_s
          value = _fetch(key, options)
          value = _coerce(value, type, options)
          value = _yield(key, value, type, options, &block) unless block.nil?

          # validate against rules
          # options.each { |v, vopts| _validate(key, value, v, vopts) }

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
        def splat(key, **options)
          key = key.to_s

          # every key in params that's not already in results
          value = params.reject { |k, _| result.keys.include? k }
          result[key] = value
        end
      end

    end
  end
end
