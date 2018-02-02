require 'rack'
require 'rack/params'

# more or less an integration test suite
# basic/advanced/interesting call patterns, etc.

class Target
  include Rack::Params

  validator :demo do
    param :num, Integer
  end

  def target_capitalize(v)
    v[0].upcase + v[1..-1]
  end
end

RSpec.describe Rack::Params do

  subject(:target) { Target.new }

  context ".validator" do
    it "can save a named validator, and run it later" do
      result = target.validate(:demo, { "num" => "39" })
      expect(result).to be_valid
      expect(result["num"]).to eq(39)
    end

    it "gets an error if validating an unknown named validator" do
      expect {
        target.validate(:not_extant, {})
      }.to raise_error RuntimeError, /no validation is registered/
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

    it "doesn't include the missing param in the output at all" do
      result = target.validate({}) do
        param "str", String, required: true
      end

      expect(result).to be_invalid
      expect(result.keys.length).to eq(0)
      expect(result.errors.keys).to contain_exactly("str")
    end

    it "can provide a default value" do
      results = target.validate!({}) do
        param "str", String, default: "default value"
      end

      expect(results).to match({ "str" => "default value" })
    end

    it "defaults to a string extraction" do
      results = target.validate({ "foo" => "bar" }) do
        param "foo", required: true
      end

      expect(results).to be_valid
      expect(results["foo"]).to eq("bar")
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

  context "boolean" do
    it "can coerce true from a bunch of different strings" do
      results = target.validate!({
        "trues" => %w(1 t true y yes),
        "falses" => %w(0 f false n no)
      }) do
        param("trues", Array) { every :boolean }
        param("falses", Array) { every :boolean }
      end

      expect(results).to be_valid
      expect(results["trues"]).to contain_exactly(true, true, true, true, true)
      expect(results["falses"]).to contain_exactly(false, false, false, false, false)
    end

    it "fails rather than returns false" do
      results = target.validate({ "bool" => "uh-uh" }) do
        param "bool", :boolean
      end

      expect(results).to be_invalid
    end
  end

  context "options" do
    it "can allow nils with :allow_nil" do
      results = target.validate({ "foo" => nil, "bar" => nil, "baz" => nil }) do
        param "foo", String, allow_nil: true,  required: true
        param "bar", String, allow_nil: false, required: true
        param "baz", String, required: true # default is allow_nil = false
      end

      # foo isn't invalid
      expect(results).to be_invalid
      expect(results.errors.keys).to contain_exactly("bar", "baz")
      expect(results.keys).to contain_exactly("foo")
      expect(results["foo"]).to be_nil
    end

    it "can allow blank with :allow_blank" do
      results = target.validate({ "foo" => "", "bar" => "", "baz" => "" }) do
        param "foo", String, allow_blank: true,  required: true
        param "bar", String, allow_blank: false, required: true
        param "baz", String, required: true # default is allow_blank = false
      end

      expect(results).to be_invalid
      expect(results.errors.keys).to contain_exactly("bar", "baz")
      expect(results.keys).to contain_exactly("foo")
      expect(results["foo"]).to eq("")
    end
  end

  context "param overloads" do
    it "can do simple type coercion (with and without) options" do
      results = target.validate({ "pi-ish" => "3.1415" }) do
        param "pi-ish",  Float
        param "missing", String, default: "defaulted"
      end

      expect(results).to be_valid
      expect(results["pi-ish"]).to eq(3.1415)
      expect(results["missing"]).to eq("defaulted")
    end

    it "can do block type coercion (with and without) options" do
      results = target.validate({ "key" => "helloworld" }) do
        param("key")                     { |v| v.to_s.upcase }
        param("missing", required: true) { |v| v.to_s.upcase }
      end

      expect(results).to be_invalid
      expect(results["key"]).to eq("HELLOWORLD")
      expect(results.errors.keys).to include("missing")
    end

    # since the way this works is a whitelist, we can add special
    # cases however we want going forward, it won't break anything

    it "can do hash and array coercion (short circuits out of 'simple type coercion')" do
      results = target.validate({ "string" => "hello", "hash" => { "key" => "value" }, "array" => %w(1 2 3) }) do
        param("hash",  Hash)  { param "key", String }
        param("array", Array) { every Integer }
        param "string" do |v|
          "#{v[0].upcase}#{v[1..-1]}, #{v}!"
        end
      end

      expect(results).to be_valid
      expect(results).to match({ "hash" => { "key" => "value" }, "array" => [1, 2, 3], "string" => "Hello, hello!"})
    end
  end

  context "array and hash coercion" do
    it "can invalidate arrays" do
      results = target.validate({ "ar1" => %w(0 2 4 f 8) }) do
        param("ar1", Array) { every Integer }
      end

      expect(results).to be_invalid
      expect(results.errors.keys).to contain_exactly("ar1.3")
    end

    it "can validate nested arrays" do
      results = target.validate({ "ar1" => [%w(0 1 2), %w(3 4 5), %w(6 t 8)] }) do
        param("ar1", Array) {
          every Array do
            every Integer
          end
        }
      end

      expect(results).to be_invalid
      expect(results.errors.keys).to contain_exactly("ar1.2.1")
      expect(results["ar1"]).to contain_exactly([0, 1, 2], [3, 4, 5], [6, nil, 8])
    end

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

  context "transform blocks" do
    it "handles optional params by not calling the block with nil" do
      missing_flag = false
      default_flag = false

      results = target.validate({ "opt_here" => "optional" }) do
        param("opt_here")                     { |v| v.upcase }
        param("opt_missing")                  { |v| missing_flag = true; v.inspect }
        param("opt_default", default: "blah") { |v| default_flag = true; v.upcase }
      end

      expect(results).to be_valid
      expect(results).to match({ "opt_here" => "OPTIONAL", "opt_missing" => "nil", "opt_default" => "BLAH" })
      expect(missing_flag).to be(true)
      expect(default_flag).to be(true)
    end

    it "can be a required field" do
      missing_flag = false

      results = target.validate({ "req_here" => "required" }) do
        param("req_here",    required: true) { |v| v.upcase }
        param("req_missing", required: true) { |v| missing_flag = true; v.upcase }
      end

      expect(results).to be_invalid
      expect(results).to match({ "req_here" => "REQUIRED" })
      expect(results.errors.keys).to include("req_missing")
      expect(missing_flag).to be(false)
    end

    it "has access to other parameters" do
      data = { "user" => "jon", "pass" => "password" }
      results = target.validate(data) do
        param "user", required: true
        param "pass", required: true do |pass|
          params["user"] == "jon" && pass == "password"
        end
      end

      expect(results).to be_valid
      expect(results["pass"]).to be true
    end
  end

  context "method transform" do
    it "can take a type of :method, which calls the _sender_" do
      pending "this might be useful"
      results = target.validate({ "key" => "hello" }) do
        param "key", method: :target_capitalize
      end

      expect(results["key"]).to eq("Hello")
    end
  end

end
