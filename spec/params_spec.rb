require 'rack'
require 'rack/params'
require 'byebug'

RSpec.describe Rack::Params do

  it "has a version number" do
    expect(Rack::Params::VERSION).not_to be nil
  end

  let (:target) do
    Class.new do
      include Rack::Params
      validator :demo do
        param :num, Integer
      end
    end
  end

  context ".validator" do
    it "can save a named validator, and run it later" do
      result = target.new.validate(:demo, { "num" => "39" })
      expect(result).to be_valid
      expect(result["num"]).to eq(39)
    end

    it "gets an error if validating an unknown named validator" do
      expect {
        target.new.validate(:not_extant, {})
      }.to raise_error ArgumentError
    end
  end

  context "#validate" do
    it "can run validation from the given block" do
      t = target.new
      r = t.validate({ "num" => "39" }) do
        param :num, Integer
        param :str, String, default: "some string"
      end

      expect(r).to be_valid
      expect(r.errors).to be_empty
      expect(r['num']).to eq(39)
      expect(r['str']).to eq("some string")
    end

    it "can fail validation if something's wrong" do
      t = target.new
      r = t.validate({ "num" => "39" }) do
        param :missing, String, required: true
      end

      expect(r).to be_invalid
    end
  end

  context "#validate!" do

    it "can do a basic successful validation" do
      params = { "str" => "is present" }
      harness.validate! params do
        param! :str, String, required: true
      end
      
      expect(params["str"]).to eq("is present")
      expect(params.count).to eq(1)
    end

    it "can freak out about missing params" do
      expect do
        harness.validate!({}) do
          param! "str", String, required: true
        end
      end.to raise_error { |ex|
        expect(ex).to be_a Rack::Params::InvalidParameterError
        expect(ex.name).to eq("str")
        expect(ex.type).to eq(String)
        expect(ex.options).to match({ required: true })
      }
    end

    it "can provide a default value" do
      params = {}
      harness.validate! params do
        param! "str", String, default: "default value"
      end

      expect(params).to match({ "str" => "default value" })
    end
  end

  context "number type coercion" do
    it "can convert to integers" do
      params = { "number" => "42" }
      harness.validate! params do
        param! "number", Integer
      end

      expect(params).to match({ "number" => 42 })
    end

    it "can convert to integers in other bases" do
      params = { "hex" => "0xff" }
      harness.validate! params do
        param! "hex", Integer, base: 16
      end

      expect(params).to match({ "hex" => 255 })
    end

    it "fails if given a bad coercion" do
      expect do
        harness.validate!({ "number" => "string" }) do
          param! "number", Integer
        end
      end.to raise_error Rack::Params::InvalidParameterError
    end

    it "can convert to floats" do
      params = { "number" => "10.3" }
      harness.validate! params do
        param! "number", Float
      end

      expect(params).to match({ "number" => 10.3 })
    end

    it "can convert something int-ish to a float" do
      params = { "number" => "10" }
      harness.validate! params do
        param! "number", Float
      end

      expect(params).to match({ "number" => 10.0 })
    end
  end

  context "nested hash validation" do
    it "can validate nested hashes" do
      params = {
        "hash" => {
          "string" => "blah",
          "number" => "10"
        }
      }

      harness.validate! params do
        param! "hash", Hash do
          param! "string", String, required: true
          param! "number", Integer, required: true
          param! "option", String, default: "default value"
        end
      end

      expect(params).to match({ "hash" => { "string" => "blah", "number" => 10, "option" => "default value" } })
    end

    it "can invalidate nested hashes" do
      params = {
        "hash" => {
          "string" => "blah",
          "number" => "str"
        }
      }

      expect do
        harness.validate! params do
          param! "hash", Hash do
            param! "string", String, required: true
            param! "number", Integer, required: true
            param! "option", String, default: "default value"
          end
        end
      end.to raise_error do |ex|
        expect(ex.name).to eq("number")
      end
    end
  end
end
