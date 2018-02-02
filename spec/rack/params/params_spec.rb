require 'rack'
require 'rack/params'

RSpec.describe Rack::Params do

  it "has a version number" do
    expect(Rack::Params::VERSION).not_to be nil
  end

end
