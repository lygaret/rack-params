# Rack::Params
[![Gem Version](https://badge.fury.io/rb/rack-params.svg)](https://badge.fury.io/rb/rack-params) [![Build Status](https://travis-ci.org/lygaret/rack-params.svg?branch=master)](https://travis-ci.org/lygaret/rack-params) [![Coverage Status](https://coveralls.io/repos/github/lygaret/rack-params/badge.svg?branch=master)](https://coveralls.io/github/lygaret/rack-params?branch=master)

`Rack::Request.params` validation and type coercion, on Rack.

## Usage

**[Documentation](https://lygaret.github.io/rack-params/)**

1. Include `Rack::Params` to get the `.validator`, `#validate` and `#validate!` methods.
2. Call `.validator(name, options = {}, &code)` to register a named validator for use later.
3. Call `#validate(name = nil, params = request.params, options = {}, &code)` to build a new result, with the results of validation and coercion.
4. The blocks passed to the validation methods run in the context of `HashContext` and `ArrayContext`, which is where the coercion methods are defined.

## Example

```ruby
# NOTE (to self) - if this changes, update `readme_spec.rb`

class SomeExampleApp
  include Rack::Params

  # create named validators that can be run at any time
  
  validator :document do
    param :id,      Integer,  required: true
    param :title,   String,   required: true
    param :created, DateTime
    
    param :tags, Array do
      every Symbol
    end
    
    param :content, Hash, required: true do
      param :header, String
      param :body,   String, required: true
    end
  end
  
  # run pre-defined or ad-hoc transforms on some hash
  # only keys in the validator blocks are copied, see #splat

  def call(env)
    request = Rack::Request.new(env)
    
    params = request.params
    params = validate(request.params, :document)
    if params.valid?
      assert params["id"].is_a? Integer
      assert (not params["content"]["body"].nil?)
    else
      assert params.errors.length > 0
      assert params.invalid?
    end

    # or
    params = { "flag" => "f", "some" => "other key", "and" => "one more" }
    params = validate(params) do
      param :flag,  :boolean, required: true
      splat :rest
    end
    
    if params.valid?
      assert [true, false].include?(params["flag"])
      assert (["some", "and"] - params["rest"]).empty?
    end

  end
end

# if you're using a framework which provides `request` as a getter method
# include the connector, which provides a `#params` override, and allows
# defaulting to request.params in validate calls

class FancyApp < Nancy::Base
  include Rack::Params::Connect

  validator :check do
    :id, Integer
  end
  
  get "/" do
    validate :check

    if params.valid?
      assert params["id"].is_a? Integer
    else
      assert params.errors.length > 0
      assert params.invalid?
    end
    
    "magic 8-ball, how's my params? << uncertan. >>"
  end

  get "/blow-up-on-failure" do
    validate! :check
    assert params.valid?

    "if I'm going down, I'm taking you all with me."
  end
end
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rack-params'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rack-params

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/lygaret/rack-params.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Authors

* Jon Raphaelson - https://accidental.cc
* Based heavily on [`mattt/sinatra-param`](https://github.com/mattt/sinatra-param), though diverging significantly in ways.
