require 'rack'
require 'rack/params'

RSpec.describe Rack::Params::Context do
  # yield is overloaded on base to provide validator recursion
  describe "#_yield" do
  end
end

RSpec.describe Rack::Params::Context::HashContext do
  describe "#param" do
  end

  describe "#splat" do
  end
end

RSpec.describe Rack::Params::Context::ArrayContext do
  describe "#every" do
  end
end
