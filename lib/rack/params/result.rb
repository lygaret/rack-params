module Rack
  module Params
    module Result
      attr_accessor :errors
      
      def valid?
        errors.length == 0
      end

      def invalid?
        not valid?
      end
    end
  end
end
