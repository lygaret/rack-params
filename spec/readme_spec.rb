# ensure that the stupid examples in the README work

RSpec.describe "readme examples" do
  let (:target) do
    Object.new.extend(Rack::Params).tap do |target|
      Rack::Params.included(target)
    end
  end

  it "can validate :document" do
    data = {
      "id"      => "3",
      "title"   => "some title",
      "created" => DateTime.now.to_s,
      "tags"    => "x y z",
      "extra"   => "some val that we'll lose",
      "content" => {
        "body"   => "some body",
        "other"  => "we'll lose tis too"
      }
    }

    result = target.validate(data) do
      param :id,      Integer,  required: true
      param :title,   String,   required: true
      param :created, DateTime
    
      param :tags, Array, sep: " " do
        every Symbol
      end
    
      param :content, Hash, required: true do
        param :header, String
        param :body,   String, required: true
      end
    end

    expect(result).to be_valid
    expect(result["id"]).to eq(3)
    expect(result["title"]).to eq("some title")
    expect(result["created"]).to be_a(DateTime)
    expect(result["tags"]).to contain_exactly(:x, :y, :z)
    expect(result["content"].key? "header").to be true
    expect(result["content"].key? "other").to be false
    expect(result["content"]["header"]).to be_nil
    expect(result["content"]["body"]).to eq("some body")

    expect(result.key? "extra").to be(false)
  end

  it "can validate the ad-hoc example" do
    data   = { "flag" => "f", "some" => "other key", "and" => "one more" }
    result = target.validate(data) do
      param :flag, :boolean, required: true
      splat :other
    end

    expect(result).to be_valid
    expect(result["flag"]).to be(false)
    expect(result["other"].keys).to contain_exactly("some", "and")
  end
end
