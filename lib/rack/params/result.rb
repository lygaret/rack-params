module Rack
  module Params

    # a mixin for validation results, to include errors
    module Result
      attr_accessor :errors
      
      # is the result valid, meaning it has no errors?
      def valid?
        errors.length == 0
      end

      # is the result invalid, meaning it has some errors?
      def invalid?
        not valid?
      end
    end
  end
end
