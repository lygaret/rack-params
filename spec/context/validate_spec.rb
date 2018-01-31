require 'rack'
require 'rack/params'
require 'byebug'

RSpec.describe Rack::Params::Context do

  def validate(params, **options, &block)
    Rack::Params::Context.exec(params, options, &block)
  end

  describe "sanity checks" do
    it "can do a basic successful validation" do
      params = { "str" => "is present", "extra" => "lost" }
      result = validate(params) do
        param :str, required: true
        param :missing
        param :defaulted, default: "hi"
      end

      expect(result).to be_valid
      expect(result["str"]).to eq("is present")
      expect(result["missing"]).to be_nil
      expect(result["defaulted"]).to eq("hi")
      expect(result.key? "extra").to be(false)
    end

    it "can freak out about missing params" do
      result = validate({}) do
        param "str", String, required: true
      end

      expect(result).to be_invalid
      expect(result.keys.length).to eq(0)
      expect(result.errors.keys).to contain_exactly("str")
    end

    it "can provide a default value" do
      results = validate({}) do
        param "str", default: "default value"
      end

      expect(results).to be_valid
      expect(results).to match({ "str" => "default value" })
    end
  end
end
