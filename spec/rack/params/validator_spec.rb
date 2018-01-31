require 'rack'
require 'rack/params'

RSpec.describe Rack::Params::Validator do
  subject(:validator) { Object.new.extend(Rack::Params::Validator) }
  
  describe "#_blank" do
    ["", nil, false, [], {}].each do |v|
      it "returns true for #{v.inspect}" do
        expect(validator._blank?(v)).to be true
      end
    end

    ["something", 1, 0, [1,2], { foo: :bar }].each do |v|
      it "returns false for #{v.inspect}" do
        expect(validator._blank?(v)).to be false
      end
    end
  end

  describe "#_coerce" do
    it "doesn't change anything if value.is_a? type" do
      a = []
      expect(validator._coerce(a, Array)).to be(a)
    end

    it "returns nil if value is nil" do
      expect(validator._coerce(nil, :symbol)).to be_nil
    end

    it "raises a runtime error if type is nil or unsupported" do
      expect { validator._coerce("foo", nil) }.to raise_error RuntimeError, /unknown type/
      expect { validator._coerce("foo", "foo") }.to raise_error RuntimeError, /unknown type/
    end

    context "type == :symbol" do
      it "can coerce symbols" do
        expect(validator._coerce("foo", :symbol)).to eq(:foo)
      end
    end

    context "type == String" do
      it "calls #to_s if value is not a String" do
        o = double()
        expect(o).to receive(:to_s)
        validator._coerce(o, String)
      end
    end

    context "type == :boolean" do
      it "can coerce true" do
        %w(1 t true y yes).each do |value|
          expect(validator._coerce(value, :boolean)).to be true
        end
      end

      it "can coerce false" do
        %w(0 f false n no).each do |value|
          expect(validator._coerce(value, :boolean)).to be false
        end
      end

      it "raises ArgumentError when a different string is passed" do
        expect {
          validator._coerce("ladida", :boolean)
        }.to raise_error ArgumentError
      end
    end

    context "type == Int" do
      it "can convert a bunch of numbers" do
        values = %w(0 1 2 3 4 100).map { |v|
          validator._coerce(v, Integer)
        }

        expect(values).to eq([0, 1, 2, 3, 4, 100])
      end

      it "raises ArgumentError on a bad value" do
        expect {
          validator._coerce("foo", Integer)
        }.to raise_error ArgumentError
      end

      it "can convert in other bases" do
        expect(validator._coerce("0xFF", Integer, base: 16)).to eq(255)
        expect(validator._coerce("10", Integer, base: 8)).to eq(8)
      end
    end

    context "type == Float" do
      it "can convert a bunch of numbers" do
        values = %w(0.3 4 30.22093 1e8).map { |v|
          validator._coerce(v, Float)
        }

        expect(values).to eq([0.3, 4.0, 30.22093, 1e8])
      end
    end

    context "type.respond_to?(:parse)" do
      it "can convert a Time" do
        t = validator._coerce("1/1/2017 2:30pm UTC", Time)
        expect(t.year).to eq(2017)
        expect(t.hour).to eq(14)
        expect(t.zone).to eq("UTC")
      end

      it "calls #parse" do
        o = double()
        v = "some string"

        expect(o).to receive(:parse).with(v)
        validator._coerce(v, o)
      end
    end
  end

  describe "#_ensure" do
    it "returns a not-nil value untouched" do
      expect(validator._ensure("FOO")).to eq("FOO")
    end

    it "raises ArgumentError on nil value" do
      expect {
        validator._ensure(nil)
      }.to raise_error ArgumentError
    end

    it "allows nil explicitly with :allow_nil" do
      expect(validator._ensure(nil, allow_nil: true)).to be nil
      expect {
        validator._ensure([], allow_nil: true)
      }.to raise_error ArgumentError
    end

    it "raises ArgumentError on any blank value, by default" do
      expect {
        validator._ensure([])
      }.to raise_error ArgumentError
    end

    it "allows blanks (including nil) explicitly with :allow_blank" do
      expect(validator._ensure(nil, allow_blank: true)).to be_nil
      expect(validator._ensure([], allow_blank: true)).to eq([])
    end
  end

  describe "#_yield" do
    it "raises RuntimeError if no block is provided" do
      expect {
        validator._yield("value")
      }.to raise_error RuntimeError, /block/
    end
    
    it "yields a value to the block, and returns the result" do
      v = validator._yield("value") { |_| _.upcase }
      expect(v).to eq("VALUE")
    end

    context "required: true" do
      it "raises ArgumentError if the value from the block is nil" do
        expect {
          validator._yield("value", required: true) { |v| nil }
        }.to raise_error ArgumentError, /required/
      end
      
      it "allows nil as a result given the allow_nil option" do
        v = validator._yield("value", required: true, allow_nil: true) { |_| nil }
        expect(v).to be_nil
      end

      it "raises ArgumentError if the value returned from the block is blank" do
        expect { validator._yield("value", required: true) { |v| nil } }.to raise_error ArgumentError, /required/
        expect { validator._yield("value", required: true) { |v| false } }.to raise_error ArgumentError, /required/
        expect { validator._yield("value", required: true) { |v| "" } }.to raise_error ArgumentError, /required/
      end

      it "allows blank as a result given the allow_nil option" do
        u = validator._yield("value", required: true, allow_blank: true) { |_| nil }
        v = validator._yield("value", required: true, allow_blank: true) { |_| false }
        w = validator._yield("value", required: true, allow_blank: true) { |_| "" }

        expect(u).to be_nil
        expect(v).to be false
        expect(w).to eq ""
      end
    end
  end
end
