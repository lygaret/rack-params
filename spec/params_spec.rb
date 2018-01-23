require 'rack'
require 'rack/params'
require 'byebug'

RSpec.describe Rack::Params do

  it "has a version number" do
    expect(Rack::Params::VERSION).not_to be nil
  end

  class Target
    include Rack::Params

    validator :demo do
      param :num, Integer
    end
  end

  let (:target) do
    Target.new
  end

  context ".validator" do
    it "can save a named validator, and run it later" do
      result = target.validate(:demo, { "num" => "39" })
      expect(result).to be_valid
      expect(result["num"]).to eq(39)
    end

    it "gets an error if validating an unknown named validator" do
      expect {
        target.validate(:not_extant, {})
      }.to raise_error ArgumentError
    end
  end

  context "#validate" do
    it "can run validation from the given block" do
      r = target.validate({ "num" => "39" }) do
        param :num, Integer
        param :str, String, default: "some string"
      end

      expect(r).to be_valid
      expect(r.errors).to be_empty
      expect(r['num']).to eq(39)
      expect(r['str']).to eq("some string")
    end

    it "can fail validation if something's wrong" do
      r = target.validate({ "num" => "39" }) do
        param :missing, String, required: true
      end

      expect(r).to be_invalid
    end
  end

  context "#validate!" do

    it "can do a basic successful validation" do
      params  = { "str" => "is present", "extra" => "lost" }
      results = target.validate! params do
        param :str, String, required: true
        param :missing, String
        param :defaulted, String, default: "hi"
      end
      
      expect(results["str"]).to eq("is present")
      expect(results["missing"]).to be_nil
      expect(results["defaulted"]).to eq("hi")
      expect(results.key? "extra").to be(false)
    end

    it "can freak out about missing params" do
      expect do
        target.validate!({}) do
          param "str", String, required: true
        end
      end.to raise_error do |ex|
        expect(ex).to be_a Rack::Params::ParameterValidationError
      end
    end

    it "can provide a default value" do
      results = target.validate!({}) do
        param "str", String, default: "default value"
      end

      expect(results).to match({ "str" => "default value" })
    end
  end

  context "number type coercion" do
    it "can convert to integers" do
      results = target.validate!({ "number" => "42" }) do
        param "number", Integer
      end

      expect(results).to match({ "number" => 42 })
    end

    it "can convert to integers in other bases" do
      results = target.validate!({ "hex" => "0xff" }) do
        param "hex", Integer, base: 16
      end

      expect(results).to match({ "hex" => 255 })
    end

    it "fails if given a bad coercion" do
      expect do
        target.validate!({ "number" => "string" }) do
          param "number", Integer
        end
      end.to raise_error Rack::Params::ParameterValidationError
    end

    it "can convert to floats" do
      results = target.validate!({ "number" => "10.3" }) do
        param "number", Float
      end

      expect(results).to match({ "number" => 10.3 })
    end

    it "can convert something int-ish to a float" do
      results = target.validate!({ "number" => "10" }) do
        param "number", Float
      end

      expect(results).to match({ "number" => 10.0 })
    end
  end

  context "nested hash validation" do
    it "can validate nested hashes" do
      params = {
        "hash" => {
          "string" => "blah",
          "number" => "10",
          "extra" => "ignored"
        }
      }

      results = target.validate!(params) do
        param "hash", Hash do
          param "string", String, required: true
          param "number", Integer, required: true
          param "option", String, default: "default value"
        end
      end

      expect(results).to match({ "hash" => { "string" => "blah", "number" => 10, "option" => "default value" } })
      expect(results.key? "extra").to be(false)
    end

    it "can invalidate nested hashes" do
      params = {
        "hash" => {
          "string" => "blah",
          "number" => "str"
        }
      }

      expect do
        target.validate!(params) do
          param "hash", Hash do
            param "string", String, required: true
            param "number", Integer, required: true
            param "option", String, default: "default value"
          end
        end
      end.to raise_error do |ex|
        expect(ex.errors.keys).to include("hash.number")
      end
    end
  end
end
